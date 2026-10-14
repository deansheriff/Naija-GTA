import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import type {Intent} from '../src/rules.js';
import {solveRadio} from './radio-helper.js';

export async function errandContract(app: FastifyInstance, advance: (ms: number) => void) {
  const ids: string[] = [];
  for (const spot of ['board', 'bench']) {
    const guest = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
    ids.push(guest.character.id);
    let token = guest.token, revision = 0, serial = 0;
    const raw = (body: object, key = `lantern-${spot}-command-${++serial}`, rev = revision) => app.inject({method: 'POST', url: '/api/v1/intents', headers: {authorization: `Bearer ${token}`, 'idempotency-key': key}, payload: {revision: rev, ...body}});
    const send = async (body: Omit<Intent, 'revision'>) => {
      const result = await raw(body); assert.equal(result.statusCode, 200, result.body); revision++;
      return result.json().character.state;
    };
    const choice = (choice: string) => ({kind: 'errand' as const, choice});
    for (const invalid of ['accept', 'collect', 'install_board', 'finish', 'give_coins']) assert.equal((await raw(choice(invalid))).statusCode, 422);
    assert.equal((await raw({kind: 'begin', action: 'lantern'})).statusCode, 422);
    assert.equal((await raw({...choice('finish'), errand: {stage: 'installed', spot}})).statusCode, 400);
    await send({kind: 'greet'});
    await send({kind: 'begin', action: 'learn'}); advance(8000); await send({kind: 'sync'});
    await solveRadio(await send({kind: 'begin', action: 'gig'}), send); advance(10000); await send({kind: 'sync'});
    await send({kind: 'neighbor', choice: 'park_space'});
    let state = await send(choice('accept'));
    assert.deepEqual(state.errand, {stage: 'collect', spot: ''});
    assert.equal((await raw(choice('accept'))).statusCode, 422);
    state = await send(choice('collect')); assert.equal(state.errand.stage, 'repair');
    const resumed = (await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: guest.recoveryCode}})).json();
    token = resumed.token;
    assert.equal(resumed.character.state.errand.stage, 'repair', 'carried lantern survives device recovery');
    assert.equal((await raw(choice('install_bench'))).statusCode, 422);
    await send({kind: 'begin', action: 'lantern'});
    assert.equal((await raw({kind: 'begin', action: 'lantern'})).statusCode, 422);
    advance(9999); state = await send({kind: 'sync'}); assert.equal(state.errand.stage, 'repair');
    advance(1); state = await send({kind: 'sync'}); assert.equal(state.errand.stage, 'ready');
    assert.equal(state.coins, 330); assert.equal(state.career.completed, 0, 'errand repair does not count as paid career work');
    assert.equal((await raw({kind: 'begin', action: 'lantern'})).statusCode, 422);
    state = await send(choice(`install_${spot}`)); assert.deepEqual(state.errand, {stage: 'installed', spot});
    assert.equal((await raw(choice(`install_${spot === 'board' ? 'bench' : 'board'}`))).statusCode, 422, 'installation choice cannot be swapped or repeated');
    const paidRevision = revision, receipt = `lantern-${spot}-final-payment`;
    const paid = await Promise.all([raw(choice('finish'), receipt), raw(choice('finish'), receipt)]);
    assert.deepEqual(paid.map(r => r.statusCode), [200, 200]); assert.deepEqual(paid[0].json(), paid[1].json()); revision++;
    state = paid[0].json().character.state;
    assert.equal(state.coins, 370); assert.equal(state.social, 2);
    assert.equal(state.errand.stage, 'complete'); assert.equal(state.neighbors.park, 3);
    assert.equal(state.neighbors.park_choice, 'space', 'helping does not remove a saved request for space');
    assert.equal(state.favor, 'available', 'lunch favour remains independent');
    assert.equal((await raw(choice('finish'))).statusCode, 422);
    assert.equal((await raw(choice('accept'))).statusCode, 422);
    assert.equal((await raw(choice('finish'), 'lantern-stale-device-' + spot, paidRevision)).statusCode, 409);
    assert.equal((await raw(choice('collect'), receipt, paidRevision)).statusCode, 409);
    assert.deepEqual((await raw(choice('finish'), receipt, paidRevision)).json(), paid[0].json());
    const final = (await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: guest.recoveryCode}})).json();
    assert.deepEqual(final.character.state.errand, {stage: 'complete', spot});
  }
  return ids;
}
