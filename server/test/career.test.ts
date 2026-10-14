import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {careerContract} from './career-contract.js';

test('repair career and home inventory: authoritative HTTP contract, restart and additive old-save upgrade', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nsl-career-')), path = join(dir, 'career.sqlite');
  let now = 1700000000000;
  let store = new Store(path, () => now), app = createApp(store);
  try {
    const id = await careerContract(app, ms => {now += ms;});
    const rows = store.db.prepare('SELECT delta,reason FROM ledger WHERE character_id=?').all(id);
    assert.equal(rows.reduce((sum,r) => sum + Number(r.delta), 0), 210);
    assert.equal(rows.filter(r => r.reason === 'repair_fan').length, 3);
    assert.equal(rows.filter(r => r.reason === 'home_plant').length, 1);
    await app.close(); store = new Store(path, () => now); app = createApp(store);
    assert.equal(store.read(id).state.career.completed, 4);
    assert.equal(store.read(id).state.inventory.owned.length, 3);
    const legacy = store.createGuest(), old = {...legacy.character.state} as any;
    delete old.career; delete old.inventory; old.gig_done = true; old.favor = 'complete';
    store.db.prepare('UPDATE characters SET state=? WHERE id=?').run(JSON.stringify(old), legacy.character.id);
    const upgraded = store.read(legacy.character.id).state;
    assert.deepEqual(upgraded.career, {completed: 0, readyAt: 0});
    assert.deepEqual(upgraded.inventory, {owned: [], equipped: []});
    assert.equal(upgraded.coins, 240); assert.equal(upgraded.gig_done, true); assert.equal(upgraded.favor, 'complete');
  } finally {await app.close(); rmSync(dir, {recursive: true, force: true});}
});
