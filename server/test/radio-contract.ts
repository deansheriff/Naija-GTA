import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import type {Intent, State} from '../src/rules.js';
import {solveRadio} from './radio-helper.js';

export async function radioContract(app: FastifyInstance, advance: (ms: number) => void) {
  const ids: string[] = [];
  for (const delayed of [true, false]) {
    const guest = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
    ids.push(guest.character.id);
    let token = guest.token, revision = 0, serial = 0;
    const raw = (body: object, key = `radio-${delayed}-move-${++serial}`, rev = revision) => app.inject({method: 'POST', url: '/api/v1/intents', headers: {authorization: `Bearer ${token}`, 'idempotency-key': key}, payload: {revision: rev, ...body}});
    const send = async (body: Omit<Intent, 'revision'>): Promise<State> => {
      const reply = await raw(body); assert.equal(reply.statusCode, 200, reply.body); revision++;
      return reply.json().character.state;
    };
    assert.equal((await raw({kind: 'repair_move', tile: 0})).statusCode, 422);
    await send({kind: 'begin', action: 'learn'}); advance(8000); await send({kind: 'sync'});
    let state = await send({kind: 'begin', action: 'gig'});
    const issued = structuredClone(state.active!.puzzle!);
    assert.equal(issued.turns.length, 6); assert.equal(issued.target.length, 6);
    assert.ok(issued.turns.every((value, index) => Number.isInteger(value) && value >= 0 && value <= 3 && value !== issued.target[index]));
    assert.equal(issued.solved, false);
    for (const invalid of [-1, 6, 1.5, '2']) assert.equal((await raw({kind: 'repair_move', tile: invalid})).statusCode, 400);
    assert.equal((await raw({kind: 'repair_move', tile: 0, solved: true, target: issued.turns})).statusCode, 400);
    if (delayed) {
      advance(10000); state = await send({kind: 'sync'});
      assert.equal(state.coins, 240); assert.equal(state.gig_done, false, 'elapsed timer alone never pays an unsolved puzzle');
      assert.deepEqual(state.active!.puzzle, issued, 'polling does not regenerate a puzzle');
      const firstRevision = revision, firstKey = 'radio-delayed-first-turn';
      const first = await Promise.all([raw({kind: 'repair_move', tile: 0}, firstKey), raw({kind: 'repair_move', tile: 0}, firstKey)]);
      assert.deepEqual(first.map(r => r.statusCode), [200, 200]); assert.deepEqual(first[0].json(), first[1].json()); revision++;
      state = first[0].json().character.state;
      assert.equal(state.active!.puzzle!.turns[0], (issued.turns[0] + 1) % 4, 'identical retry rotates exactly once');
      assert.equal((await raw({kind: 'repair_move', tile: 1}, firstKey, firstRevision)).statusCode, 409);
      assert.equal((await raw({kind: 'repair_move', tile: 1}, 'radio-stale-device-turn', firstRevision)).statusCode, 409);
      const resumed = (await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: guest.recoveryCode}})).json();
      token = resumed.token;
      assert.deepEqual(resumed.character.state.active.puzzle, state.active!.puzzle, 'another device resumes the issued board and moves');
      for (let tile = 0; tile < 6; tile++) {
        const puzzle = state.active!.puzzle!;
        const steps = (puzzle.target[tile] - puzzle.turns[tile] + 4) % 4 - (tile === 5 ? 1 : 0);
        for (let step = 0; step < steps; step++) state = await send({kind: 'repair_move', tile});
      }
      const paidRevision = revision, finalKey = 'radio-last-turn-payment';
      const final = await Promise.all([raw({kind: 'repair_move', tile: 5}, finalKey), raw({kind: 'repair_move', tile: 5}, finalKey)]);
      assert.deepEqual(final.map(r => r.statusCode), [200, 200]); assert.deepEqual(final[0].json(), final[1].json()); revision++;
      state = final[0].json().character.state;
      assert.equal(state.coins, 330); assert.equal(state.gig_done, true); assert.equal(state.active, null);
      assert.equal((await raw({kind: 'repair_move', tile: 5})).statusCode, 422);
      assert.equal((await raw({kind: 'repair_move', tile: 5}, finalKey, paidRevision)).json().character.state.coins, 330);
    } else {
      state = await solveRadio(state, send);
      assert.equal(state.coins, 240); assert.equal(state.active!.puzzle!.solved, true, 'solving early waits for the existing test deadline');
      assert.equal((await raw({kind: 'repair_move', tile: 0})).statusCode, 422);
      advance(9999); state = await send({kind: 'sync'}); assert.equal(state.coins, 240);
      advance(1); state = await send({kind: 'sync'}); assert.equal(state.coins, 330); assert.equal(state.repair, 2);
    }
    assert.equal((await raw({kind: 'begin', action: 'gig'})).statusCode, 422);
    state = await send({kind: 'sync'}); assert.equal(state.coins, 330);
  }
  return ids;
}
