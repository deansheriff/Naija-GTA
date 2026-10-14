import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';

// The exact HTTP contract runs against SQLite, embedded PostgreSQL and CI PostgreSQL 17.
export async function neighborContract(app: FastifyInstance) {
  const guest = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
  const auth = {authorization: `Bearer ${guest.token}`};
  let revision = 0, serial = 0;
  const send = (choice: string, key = `neighbor-contract-${++serial}`, rev = revision) => app.inject({method: 'POST', url: '/api/v1/intents', headers: {...auth, 'idempotency-key': key}, payload: {revision: rev, kind: 'neighbor', choice}});
  assert.equal((await send('favor_finish')).statusCode, 422);
  assert.equal((await send('favor_deliver')).statusCode, 422);
  assert.equal((await send('favor_accept')).statusCode, 422);
  assert.equal((await send('give_me_999_coins')).statusCode, 422);
  assert.equal((await app.inject({method: 'POST', url: '/api/v1/intents', headers: {...auth, 'idempotency-key': 'neighbor-forged-state'}, payload: {revision, kind: 'neighbor', choice: 'favor_finish', favor: 'delivered'}})).statusCode, 400);
  let reply = await app.inject({method: 'POST', url: '/api/v1/intents', headers: {...auth, 'idempotency-key': 'neighbor-first-greet'}, payload: {revision, kind: 'greet'}});
  assert.equal(reply.statusCode, 200); revision++;
  for (const choice of ['park_space', 'park_welcome', 'park_welcome', 'yemi_hello', 'yemi_hello', 'favor_accept', 'favor_deliver']) {
    reply = await send(choice); assert.equal(reply.statusCode, 200); revision++;
  }
  assert.equal(reply.json().character.state.social, 3, 'repeated introductions do not farm social');
  assert.equal(reply.json().character.state.coins, 240);
  const paidRevision = revision;
  const paid = await Promise.all([send('favor_finish', 'neighbor-final-receipt', paidRevision), send('favor_finish', 'neighbor-final-receipt', paidRevision)]);
  assert.deepEqual(paid.map(r => r.statusCode), [200, 200]);
  assert.deepEqual(paid[0].json(), paid[1].json()); revision++;
  assert.equal(paid[0].json().character.state.coins, 270);
  assert.equal(paid[0].json().character.state.favor, 'complete');
  assert.equal(paid[0].json().character.state.neighbors.amaka, 3);
  assert.equal((await send('favor_accept')).statusCode, 422);
  assert.equal((await send('favor_finish')).statusCode, 422);
  assert.equal((await send('favor_finish', 'neighbor-stale-device', paidRevision)).statusCode, 409);
  assert.equal((await send('park_space', 'neighbor-final-receipt', paidRevision)).statusCode, 409);
  const restored = (await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: guest.recoveryCode}})).json();
  assert.equal(restored.character.state.favor, 'complete');
  assert.deepEqual(restored.character.state.neighbors, {amaka: 3, yemi: 3, park: 1, park_choice: 'welcome'});
  assert.equal(restored.character.state.coins, 270);
  return guest.character.id as string;
}
