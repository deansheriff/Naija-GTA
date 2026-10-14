import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {neighborContract} from './neighbor-contract.js';

test('neighbor HTTP choices, one-time favor, durable replay and old saves', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'nsl-neighbors-'));
  const file = join(directory, 'save.sqlite');
  let store = new Store(file), app = createApp(store);
  try {
    const id = await neighborContract(app);
    assert.deepEqual(store.db.prepare("SELECT delta,reason FROM ledger WHERE character_id=? AND reason='neighbor_lunch_favor'").all(id).map(r => [r.delta,r.reason]), [[30,'neighbor_lunch_favor']]);
    await app.close();
    store = new Store(file); app = createApp(store);
    assert.equal(store.read(id).state.favor, 'complete');
    assert.equal(store.read(id).state.coins, 270);
    const response = store.db.prepare('SELECT response FROM commands WHERE character_id=? AND command_key=?').get(id, 'neighbor-final-receipt');
    const revision = JSON.parse(response!.response as string).character.revision - 1;
    assert.equal(store.execute(id, 'neighbor-final-receipt', {kind: 'neighbor', choice: 'favor_finish', revision}).character.state.coins, 270);
    const old = store.createGuest();
    const state = {...old.character.state} as any; delete state.neighbors; delete state.favor; state.met_amaka = true;
    store.db.prepare('UPDATE characters SET state=? WHERE id=?').run(JSON.stringify(state), old.character.id);
    assert.equal(store.read(old.character.id).state.neighbors.amaka, 1);
    assert.equal(store.read(old.character.id).state.favor, 'available');
    assert.equal(store.read(old.character.id).state.coins, 240);
  } finally {await app.close(); rmSync(directory, {recursive: true, force: true});}
});
