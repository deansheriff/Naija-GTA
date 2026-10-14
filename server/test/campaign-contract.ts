import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {prologue} from '../src/campaign.js';

export async function campaignContract(app: FastifyInstance, advance: (ms: number) => void) {
  const guest = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
  let token = guest.token, revision = 0, serial = 0;
  const raw = (body: object, key = `campaign-command-${++serial}`, expected = revision) => app.inject({method: 'POST', url: '/api/v1/intents', headers: {authorization: `Bearer ${token}`, 'idempotency-key': key}, payload: {revision: expected, ...body}});
  const send = async (body: object) => {const r = await raw(body); assert.equal(r.statusCode, 200, r.body); revision++; return r.json().character.state;};
  const initial = guest.character.state;
  assert.equal(initial.campaign.status, 'unstarted');
  assert.equal((await raw({kind: 'campaign_choose', stage: 0, choice: 'next'})).statusCode, 422);
  await send({kind: 'begin', action: 'learn'});
  let state = await send({kind: 'campaign_start'});
  const frozen = {food: state.food, energy: state.energy, comfort: state.comfort, coins: state.coins, repair: state.repair};
  assert.equal((await raw({kind: 'campaign_start'})).statusCode, 422);
  assert.equal((await raw({kind: 'campaign_switch', choice: 'ngozi'})).statusCode, 422);
  assert.equal((await raw({kind: 'campaign_choose', stage: 13, choice: 'next'})).statusCode, 422);
  assert.equal((await raw({kind: 'campaign_choose', stage: 0, choice: 'next', mastery: 99})).statusCode, 400);
  advance(1200000); state = await send({kind: 'sync'});
  for (const [key, value] of Object.entries(frozen)) assert.equal(state[key], value, `story freezes sandbox ${key}`);
  assert.equal(state.active.code, 'learn'); assert.ok(state.active.endsAt > state.updatedAt);
  assert.equal((await raw({kind: 'begin', action: 'rest'})).statusCode, 422);
  for (let index = 0; index < prologue.stages.length; index++) {
    const task = prologue.stages[index];
    assert.equal(state.campaign.stage, index); assert.equal(state.campaign.lead, task.lead);
    const wrong = task.choices.find(c => !c.correct);
    if (wrong) {
      const bad = await raw({kind: 'campaign_choose', stage: index, choice: wrong.id});
      assert.equal(bad.statusCode, 422); assert.ok(bad.json().message.length > 15);
      const stored = (await app.inject({url: '/api/v1/me', headers: {authorization: `Bearer ${token}`}})).json().character;
      assert.equal(stored.revision, revision); assert.equal(stored.state.campaign.stage, index);
    }
    if (index === 6) {
      await send({kind: 'campaign_pause'});
      assert.equal((await raw({kind: 'campaign_choose', stage: index, choice: task.choices.find(c => c.correct)!.id})).statusCode, 422);
      const recovered = (await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: guest.recoveryCode}})).json();
      token = recovered.token; assert.equal(recovered.character.state.campaign.stage, index);
      state = await send({kind: 'campaign_resume'});
    }
    const body = {kind: 'campaign_choose', stage: index, choice: task.choices.find(c => c.correct)!.id};
    const key = `campaign-task-retry-${index}`, expected = revision;
    const replies = await Promise.all([raw(body, key, expected), raw(body, key, expected)]);
    assert.deepEqual(replies.map(r => r.statusCode), [200, 200]); assert.deepEqual(replies[0].json(), replies[1].json());
    revision++; state = replies[0].json().character.state;
    assert.equal((await raw(body, `campaign-task-stale-${index}`, expected)).statusCode, 409);
  }
  assert.equal(state.campaign.status, 'hub'); assert.deepEqual(state.campaign.completed, ['P00']);
  assert.deepEqual(state.campaign.mastery, {tunde: 1, ngozi: 1, kc: 1}); assert.deepEqual(state.campaign.evidence, ['wedding_clip']);
  assert.equal(state.coins, initial.coins);
  assert.equal((await raw({kind: 'campaign_choose', stage: prologue.stages.length, choice: 'next'})).statusCode, 422);
  for (const choice of ['ngozi', 'tunde', 'kc']) {state = await send({kind: 'campaign_switch', choice}); assert.equal(state.campaign.lead, choice);}
  assert.equal((await raw({kind: 'campaign_switch', choice: 'invented'})).statusCode, 422);
  await send({kind: 'campaign_pause'}); advance(8000); state = await send({kind: 'sync'});
  assert.equal(state.active, null); assert.equal(state.repair, 1, 'sandbox activity resumes after pause');
  assert.deepEqual(state.campaign.mastery, {tunde: 1, ngozi: 1, kc: 1});
  return guest.character.id as string;
}
