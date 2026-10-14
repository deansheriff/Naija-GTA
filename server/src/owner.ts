import {createHmac, randomBytes, timingSafeEqual} from 'node:crypto';
import type {FastifyInstance, FastifyRequest} from 'fastify';
import type {GameStore} from './contract.js';
import {checkPassword, digest, validateSettings, type OwnerConfig, type WorldSettings} from './operations.js';
import {RuleError} from './rules.js';

const uuid = {type: 'string', pattern: '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'};
const reason = {type: 'string', minLength: 5, maxLength: 160, pattern: '\\S.{3,}\\S'};
const tokenFrom = (request: FastifyRequest) => request.headers.cookie?.split(';').map(value => value.trim()).find(value => value.startsWith('nsl_owner='))?.slice(10) ?? '';
export async function ownerRoutes(app: FastifyInstance, store: GameStore, config: OwnerConfig | undefined, metrics: () => unknown) {
  const fingerprint = config ? digest(config.username + ':' + config.passwordHash) : '';
  const csrf = (token: string) => createHmac('sha256', config!.passwordHash).update(token).digest('base64url');
  const cookie = (token: string, seconds: number) => `nsl_owner=${token}; Path=/api/owner; HttpOnly; SameSite=Strict; Max-Age=${seconds}${config!.secure ? '; Secure' : ''}`;
  app.addHook('onRequest', async (request, reply) => {
    reply.header('Cache-Control', 'no-store');
    if (!config) throw new RuleError('not_found', 'Owner access is not enabled.', 404);
    if (!['GET','HEAD'].includes(request.method) && request.headers.origin !== config.origin) throw new RuleError('origin_rejected', 'Open the panel on its configured game origin.', 403);
    if (request.url.split('?')[0] === '/api/owner/login') return;
    const token = tokenFrom(request);
    if (!/^[A-Za-z0-9_-]{43}$/.test(token) || await store.ops.ownerSession(digest(token), fingerprint) <= store.now()) throw new RuleError('owner_unauthorized', 'Sign in as the owner.', 401);
    if (!['GET','HEAD'].includes(request.method)) {
      const submitted = String(request.headers['x-csrf-token'] ?? ''); const expected = csrf(token);
      if (!/^[A-Za-z0-9_-]{43}$/.test(submitted) || !timingSafeEqual(Buffer.from(submitted), Buffer.from(expected))) throw new RuleError('csrf_rejected', 'Reload the owner panel before trying again.', 403);
    }
  });
  app.post<{Body: {username: string; password: string}}>('/login', {schema: {body: {type: 'object', additionalProperties: false, required: ['username','password'], properties: {username: {type: 'string', maxLength: 40}, password: {type: 'string', maxLength: 256}}}}}, async (request, reply) => {
    const valid = checkPassword(request.body.password, config!.passwordHash);
    if (!valid || request.body.username !== config!.username) {
      await store.ops.audit('anonymous', 'owner.login_failed', '', 'Invalid owner credentials');
      throw new RuleError('owner_unauthorized', 'Sign-in details were not accepted.', 401);
    }
    const token = randomBytes(32).toString('base64url'); const expiresAt = store.now() + 8 * 3600000;
    await store.ops.openOwnerSession(digest(token), fingerprint, expiresAt, config!.username);
    reply.header('Set-Cookie', cookie(token, 8 * 3600)); return {username: config!.username, csrfToken: csrf(token), expiresAt};
  });
  app.get('/session', async request => ({username: config!.username, csrfToken: csrf(tokenFrom(request)), expiresAt: await store.ops.ownerSession(digest(tokenFrom(request)), fingerprint)}));
  app.post('/logout', async (request, reply) => {await store.ops.closeOwnerSession(digest(tokenFrom(request)), config!.username); reply.header('Set-Cookie', cookie('', 0)); return {ok: true};});
  app.get('/overview', async () => ({counts: await store.ops.overview(), runtime: metrics(), settings: await store.ops.settings(), serverTime: store.now(), retention: {receiptsDays: 90, ledger: 'Permanent', audit: 'Permanent'}}));
  app.get<{Querystring: {after?: string}}>('/players', {schema: {querystring: {type: 'object', additionalProperties: false, properties: {after: uuid}}}}, async request => {
    const rows = await store.ops.players(request.query.after ?? '') as Array<{id: string}>;
    return {players: rows.slice(0, 30), next: rows.length > 30 ? rows[29].id : null};
  });
  app.get<{Params: {id: string}}>('/players/:id', {schema: {params: {type: 'object', required: ['id'], properties: {id: uuid}}}}, async request => {
    const result = await store.ops.inspect(request.params.id);
    await store.ops.audit(config!.username, 'player.inspect', request.params.id, 'Owner viewed save and recent ledger'); return result;
  });
  app.post<{Params: {id: string}; Body: {action: string; reason: string}}>('/players/:id/access', {schema: {params: {type: 'object', required: ['id'], properties: {id: uuid}}, body: {type: 'object', additionalProperties: false, required: ['action','reason'], properties: {action: {enum: ['suspend','resume','revoke_sessions']}, reason}}}}, async request => {
    await store.ops.moderate(request.params.id, request.body.action, config!.username, request.body.reason.trim()); return {ok: true};
  });
  const settingsProperties = {revision: {type: 'integer', minimum: 0, maximum: 2147483646}, announcement: {type: 'string', maxLength: 160}, maintenance: {type: 'boolean'}, favorEnabled: {type: 'boolean'}, newCharacterSeed: {type: 'integer', minimum: 1, maximum: 2147483646}, amakaLine: {type: 'string', maxLength: 200}, yemiLine: {type: 'string', maxLength: 200}};
  app.put<{Body: {settings: WorldSettings; reason: string}}>('/settings', {schema: {body: {type: 'object', additionalProperties: false, required: ['settings','reason'], properties: {settings: {type: 'object', additionalProperties: false, required: Object.keys(settingsProperties), properties: settingsProperties}, reason}}}}, async request => ({settings: await store.ops.updateSettings(request.body.settings.revision, validateSettings(request.body.settings), config!.username, request.body.reason.trim())}));
  app.get<{Querystring: {before?: string}}>('/audit', {schema: {querystring: {type: 'object', additionalProperties: false, properties: {before: {type: 'string', pattern: '^[1-9][0-9]{0,14}$'}}}}}, async request => {
    const rows = await store.ops.audits(Number(request.query.before ?? Number.MAX_SAFE_INTEGER)) as Array<{id: number}>;
    return {events: rows.slice(0, 30), next: rows.length > 30 ? rows[29].id : null};
  });
}
