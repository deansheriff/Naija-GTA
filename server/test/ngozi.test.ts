import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {ngoziContract} from './ngozi-contract.js';
import {freshCampaign,upgradeCampaign,CAMPAIGN_VERSION,missions} from '../src/campaign.js';
import {freshDrive} from '../src/driving-task.js';
import {contentUnits} from '../src/content-review.js';

test('Ajo Day: all records, patient/firm schedules, retry/recovery, once-only evidence and no currency',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-ngozi-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  try{
    const ids=await ngoziContract(app,ms=>{now+=ms;});
    for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const before=store.read(ids[0]).state.campaign;
    await app.close();store=new Store(file,()=>now);app=createApp(store);
    assert.deepEqual(store.read(ids[0]).state.campaign,before,'process restart retains schedule, evidence and mastery');
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('Ajo Day source, table-review coverage and version-2 road saves survive additive upgrade',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/ngozi-intro.json',import.meta.url),'utf8')),missions.A12);
  const ids=new Set();
  for(const stage of missions.A12.stages){assert.ok(!ids.has(stage.id));ids.add(stage.id);assert.equal(stage.lead,'ngozi');assert.ok(stage.summary.length&&stage.text.length&&stage.choices.some(c=>c.correct));
    const unit=contentUnits.find(u=>u.id==='A12-'+stage.id)!;assert.ok(unit);
    for(const record of stage.records??[]){assert.ok(unit.text.includes(record.title));for(const line of record.lines)assert.ok(unit.text.includes(line));}
  }
  const old={...freshCampaign(),version:2,mission:'A11',status:'playing' as const,stage:3,completed:['P00'],choices:{'A11-market_drive':'shortcut'},drive:{...freshDrive(1000),distance:150,speed:40,lane:0}};
  const upgraded=upgradeCampaign(old);assert.equal(upgraded.version,CAMPAIGN_VERSION);assert.equal(old.version,2);assert.deepEqual({...upgraded,version:2},old);
  const future={...old,version:99};assert.deepEqual(upgradeCampaign(future),future);
});
