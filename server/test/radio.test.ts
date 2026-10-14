import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {radioContract} from './radio-contract.js';

test('interactive radio: validated moves, deadline, durable replay, recovery and legacy compatibility', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nsl-radio-')), file = join(dir, 'save.sqlite');
  let now = 1700000000000, store = new Store(file, () => now), app = createApp(store);
  try {
    const ids = await radioContract(app, ms => {now += ms;});
    for (const id of ids) assert.deepEqual(store.db.prepare("SELECT delta FROM ledger WHERE character_id=? AND reason='starter_gig'").all(id).map(r => r.delta), [90]);
    const guest = store.createGuest();
    store.execute(guest.character.id, 'radio-restart-practice', {kind: 'begin', action: 'learn', revision: 0});
    now += 8000; store.execute(guest.character.id, 'radio-restart-learned', {kind: 'sync', revision: 1});
    const started = store.execute(guest.character.id, 'radio-restart-begin', {kind: 'begin', action: 'gig', revision: 2});
    await app.close(); store = new Store(file, () => now); app = createApp(store);
    assert.deepEqual(store.read(guest.character.id).state.active!.puzzle, started.character.state.active!.puzzle);
    now += 1200000;
    const waiting = store.execute(guest.character.id, 'radio-restart-return', {kind: 'sync', revision: 3});
    assert.equal(waiting.character.state.coins, 240); assert.ok(waiting.character.state.active!.puzzle);
  } finally {await app.close(); rmSync(dir, {recursive: true, force: true});}
});
