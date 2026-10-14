import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {errandContract} from './errand-contract.js';

test('lantern errand: both branches, ordered stages, exact reward replay, recovery and restart', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nsl-lantern-')), file = join(dir, 'save.sqlite');
  let now = 1700000000000, store = new Store(file, () => now), app = createApp(store);
  try {
    const ids = await errandContract(app, ms => {now += ms;});
    for (const id of ids) {
      const rows = store.db.prepare("SELECT delta FROM ledger WHERE character_id=? AND reason='square_lantern_errand'").all(id);
      assert.deepEqual(rows.map(r => r.delta), [40]);
    }
    await app.close(); store = new Store(file, () => now); app = createApp(store);
    assert.deepEqual(ids.map(id => store.read(id).state.errand), [{stage: 'complete', spot: 'board'}, {stage: 'complete', spot: 'bench'}]);
    const legacy = store.createGuest(), state = {...legacy.character.state} as any;
    delete state.errand; state.gig_done = true; state.favor = 'complete'; state.career.completed = 4; state.inventory.owned = ['plant'];
    store.db.prepare('UPDATE characters SET state=? WHERE id=?').run(JSON.stringify(state), legacy.character.id);
    const restored = store.read(legacy.character.id).state;
    assert.deepEqual(restored.errand, {stage: 'available', spot: ''});
    assert.equal(restored.career.completed, 4); assert.equal(restored.favor, 'complete'); assert.equal(restored.gig_done, true);
    assert.deepEqual(restored.inventory.owned, ['plant']); assert.equal(restored.coins, 240);
  } finally {await app.close(); rmSync(dir, {recursive: true, force: true});}
});
