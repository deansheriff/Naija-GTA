import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {campaignContract} from './campaign-contract.js';
import {freshCampaign, prologue, campaignCommand} from '../src/campaign.js';

test('wedding campaign: validated checkpoints, all leads, retries, recovery and sandbox isolation', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'nsl-story-')), file = join(dir, 'save.sqlite');
  let now = 1700000000000, store = new Store(file, () => now), app = createApp(store);
  try {
    const id = await campaignContract(app, ms => {now += ms;});
    assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total, 1, 'no story currency awards');
    const guest = store.createGuest();
    store.execute(guest.character.id, 'story-restart-start', {kind: 'campaign_start', revision: 0});
    store.execute(guest.character.id, 'story-restart-arrival', {kind: 'campaign_choose', revision: 1, stage: 0, choice: 'next'});
    await app.close(); store = new Store(file, () => now); app = createApp(store);
    assert.equal(store.read(guest.character.id).state.campaign.stage, 1);
    const legacy = store.createGuest();
    store.db.prepare("UPDATE characters SET state=json_remove(state,'$.campaign') WHERE id=?").run(legacy.character.id);
    assert.deepEqual(store.read(legacy.character.id).state.campaign, freshCampaign());
    assert.equal(store.read(legacy.character.id).state.coins, 240);
    store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify({version: 99, custom: 'preserve'}), legacy.character.id);
    assert.throws(() => store.execute(legacy.character.id, 'story-future-blocked', {kind: 'campaign_start', revision: 0}), /newer game/);
    assert.equal((store.read(legacy.character.id).state.campaign as unknown as {custom:string}).custom, 'preserve');
  } finally {await app.close(); rmSync(dir, {recursive: true, force: true});}
});

test('campaign content has reachable labelled tasks, summaries and shared browser source', () => {
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/prologue.json', import.meta.url), 'utf8')), prologue);
  const ids = new Set(); const seen = new Set();
  for (const task of prologue.stages) {
    assert.ok(!ids.has(task.id)); ids.add(task.id); seen.add(task.lead);
    assert.ok(task.title.length && task.text.length && task.summary.length);
    assert.equal(task.choices.filter(c => c.correct).length, 1);
    assert.equal(new Set(task.choices.map(c => c.id)).size, task.choices.length);
    assert.ok(task.choices.every(c => c.label.length));
  }
  assert.equal(seen.size, 3);
  const c = freshCampaign(); campaignCommand(c, 'campaign_start');
  for (let i = 0; i < prologue.stages.length; i++) campaignCommand(c, 'campaign_choose', i, prologue.stages[i].choices.find(c => c.correct)!.id);
  assert.equal(c.status, 'hub');
});
