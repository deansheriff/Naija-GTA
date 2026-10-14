import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {createApp} from '../src/app.js';
import {Store} from '../src/store.js';
import type {Intent} from '../src/rules.js';

test('authoritative HTTP loop, legacy timed gig upgrade, retries, stale devices, timers and ledger', async () => {
  let now = 1700000000000;
  const store = new Store(':memory:', () => now), app = createApp(store);
  const guest = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
  const auth = {authorization: `Bearer ${guest.token}`};
  assert.equal(guest.character.state.coins, 240);
  assert.equal((await app.inject('/api/v1/me')).statusCode, 401);
  const command = (key: string, payload: Intent | object) => app.inject({method: 'POST', url: '/api/v1/intents', headers: {...auth, 'idempotency-key': key}, payload});
  assert.equal((await command('forged-coins-0001', {kind: 'sync', revision: 0, coins: 999999})).statusCode, 400);
  assert.equal((await command('early-gig-000001', {kind: 'begin', action: 'gig', revision: 0})).statusCode, 422);
  const practice = {kind: 'begin', action: 'learn', revision: 0} as const;
  const first = await command('practice-key-0001', practice);
  assert.equal(first.statusCode, 200);
  assert.deepEqual((await command('practice-key-0001', practice)).json(), first.json());
  assert.equal((await command('practice-key-0001', {...practice, action: 'rest'})).statusCode, 409);
  assert.equal((await command('stale-device-0001', {kind: 'greet', revision: 0})).statusCode, 409);
  assert.equal((await command('concurrent-rest-01', {kind: 'begin', action: 'rest', revision: 1})).statusCode, 422);
  const early = (await command('before-deadline-01', {kind: 'sync', revision: 1})).json();
  assert.equal(early.character.state.repair, 0);
  now += 8000;
  const qualified = (await command('after-deadline-001', {kind: 'sync', revision: 2})).json();
  assert.equal(qualified.character.state.repair, 1);
  assert.equal(qualified.character.state.active, null);
  await command('begin-starter-001', {kind: 'begin', action: 'gig', revision: 3});
  // Fixture for a pre-0.11 activity already saved without a puzzle.
  store.db.prepare("UPDATE characters SET state=json_remove(state,'$.active.puzzle') WHERE id=?").run(guest.character.id);
  now += 10000;
  const paid = await command('finish-starter-01', {kind: 'sync', revision: 4});
  assert.equal(paid.json().character.state.coins, 330);
  assert.deepEqual((await command('finish-starter-01', {kind: 'sync', revision: 4})).json(), paid.json());
  assert.equal((await command('repeat-starter-01', {kind: 'begin', action: 'gig', revision: 5})).statusCode, 422);
  const rows = store.db.prepare('SELECT delta,balance FROM ledger ORDER BY created_at').all();
  assert.deepEqual(rows.map(row => [row.delta, row.balance]), [[240,240],[90,330]]);
  assert.throws(() => store.db.exec('UPDATE ledger SET delta=999'), /append-only/);
  assert.throws(() => store.db.exec('DELETE FROM ledger'), /append-only/);
  const rival = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
  const rivalMe = (await app.inject({url: '/api/v1/me', headers: {authorization: `Bearer ${rival.token}`}})).json();
  assert.notEqual(rivalMe.character.id, guest.character.id);
  assert.equal(rivalMe.character.state.coins, 240);
  const races = await Promise.all(['racing-device-01','racing-device-02'].map(key => command(key, {kind: 'decorate', wall: 'ocean', revision: 5})));
  assert.deepEqual(races.map(reply => reply.statusCode).sort(), [200,409]);
  await app.inject({method: 'DELETE', url: '/api/v1/session', headers: auth});
  assert.equal((await app.inject({url: '/api/v1/me', headers: auth})).statusCode, 401);
  assert.equal(store.read(guest.character.id).state.coins, 330);
  await app.close();
});

test('progress and hashed sessions survive process restart; expiry is enforced', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'nsl-api-'));
  const path = join(directory, 'test.sqlite');
  let now = 1700000000000;
  try {
    let store = new Store(path, () => now);
    const guest = store.createGuest();
    store.execute(guest.character.id, 'persistent-name-01', {kind: 'profile', revision: 0, name: 'Test neighbor', bio: 'A fictional test profile.'});
    const session = store.db.prepare('SELECT token_hash FROM sessions').get();
    assert.notEqual(session!.token_hash, guest.token);
    store.close();
    store = new Store(path, () => now);
    assert.equal(store.read(store.authorize(guest.token)).state.name, 'Test neighbor');
    assert.equal(store.read(guest.character.id).revision, 1);
    now = guest.expiresAt;
    assert.throws(() => store.authorize(guest.token), /expired/);
    store.close();
  } finally {
    assert.ok(resolve(directory).startsWith(join(resolve(tmpdir()), 'nsl-api-')));
    rmSync(directory, {recursive: true, force: true});
  }
});

test('bounded absence completes only an already started activity', async () => {
  let now = 1700000000000;
  const store = new Store(':memory:', () => now);
  const guest = store.createGuest();
  store.execute(guest.character.id, 'start-practice-01', {kind: 'begin', action: 'learn', revision: 0});
  now += 5 * 24 * 3600 * 1000;
  const restored = store.execute(guest.character.id, 'return-after-days', {kind: 'sync', revision: 1}).character;
  assert.equal(restored.state.repair, 1);
  assert.equal(restored.state.coins, 240);
  assert.equal(restored.state.active, null);
  assert.equal(restored.state.food, 35);
  assert.equal(store.execute(guest.character.id, 'second-catchup-01', {kind: 'sync', revision: 2}).character.state.repair, 1);
  store.close();
});
