import Fastify from 'fastify';
import rateLimit from '@fastify/rate-limit';
import staticFiles from '@fastify/static';
import type {GameStore} from './contract.js';
import {RuleError, type Intent} from './rules.js';
export function createApp(store: GameStore, options: {staticRoot?: string; mode?: string} = {}) {
  const app = Fastify({logger: false, bodyLimit: 8192, ajv: {customOptions: {removeAdditional: false, coerceTypes: false}}});
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof RuleError) return reply.code(error.status).send({error: error.code, message: error.message});
    const typed = error as {validation?: unknown; statusCode?: number};
    if (typed.validation) return reply.code(400).send({error: 'invalid_request', message: 'The request does not match the command schema.'});
    if (typed.statusCode && typed.statusCode >= 400 && typed.statusCode < 500) return reply.code(typed.statusCode).send({error: 'request_rejected'});
    return reply.code(500).send({error: 'internal_error'});
  });
  app.register(async api => {
    await api.register(rateLimit, {max: 180, timeWindow: '1 minute'});
    api.addHook('onSend', async (_request, reply) => {reply.header('Cache-Control', 'no-store');});
    const owner = (authorization: string | undefined) => store.authorize(authorization?.startsWith('Bearer ') ? authorization.slice(7) : undefined);
    api.get('/health', async (_request, reply) => {
      if (!(await store.health())) return reply.code(503).send({ok: false});
      return {ok: true, application: 'naija-street-life', mode: options.mode ?? 'local-development', schema: 1};
    });
    api.post('/v1/guests', {config: {rateLimit: {max: 10, timeWindow: '1 minute'}}, schema: {body: {type: 'object', additionalProperties: false, properties: {}}}}, async (_request, reply) => reply.code(201).send(await store.createGuest()));
    api.post<{Body: {recoveryCode: string}}>('/v1/sessions', {
      config: {rateLimit: {max: 5, timeWindow: '1 minute'}},
      schema: {body: {type: 'object', additionalProperties: false, required: ['recoveryCode'], properties: {recoveryCode: {type: 'string', minLength: 40, maxLength: 80, pattern: '^[A-Za-z0-9_-]+$'}}}}
    }, async request => store.restore(request.body.recoveryCode));
    api.get('/v1/me', async request => ({character: await store.read(await owner(request.headers.authorization)), serverTime: store.now()}));
    api.post<{Body: Intent}>('/v1/intents', {
      schema: {
        headers: {type: 'object', required: ['idempotency-key'], properties: {'idempotency-key': {type: 'string', minLength: 16, maxLength: 80, pattern: '^[A-Za-z0-9_-]+$'}}},
        body: {type: 'object', additionalProperties: false, required: ['revision', 'kind'], properties: {
          revision: {type: 'integer', minimum: 0, maximum: 2147483647}, kind: {enum: ['sync', 'greet', 'begin', 'decorate', 'profile', 'post', 'cancel', 'poll', 'neighbor']},
          action: {enum: ['learn', 'gig', 'eat', 'rest', 'wash', 'study']}, wall: {enum: ['sage', 'clay', 'ocean']},
          name: {type: 'string', minLength: 1, maxLength: 30}, bio: {type: 'string', maxLength: 160},
          title: {type: 'string', minLength: 5, maxLength: 60}, budget: {type: 'integer', minimum: 10, maximum: 10000},
          jobId: {type: 'string', maxLength: 10}, choice: {type: 'string', maxLength: 80}
        }}
      }
    }, async request => store.execute(await owner(request.headers.authorization), request.headers['idempotency-key'] as string, request.body));
    api.delete('/v1/session', async request => {
      await owner(request.headers.authorization); await store.revoke(request.headers.authorization!.slice(7)); return {ok: true};
    });
  }, {prefix: '/api'});
  if (options.staticRoot) {
    app.register(staticFiles, {root: options.staticRoot, prefix: '/', cacheControl: true, maxAge: 0, index: ['index.html']});
    app.addHook('onSend', async (_request, reply) => {
      reply.header('X-Content-Type-Options', 'nosniff'); reply.header('Referrer-Policy', 'same-origin');
      reply.header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'");
    });
  }
  app.addHook('onClose', async () => store.close());
  return app;
}
