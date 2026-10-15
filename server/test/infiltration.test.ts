import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {infiltrationContract,chaseHub} from './infiltration-contract.js';
import {campaignCommand,upgradeCampaign,CAMPAIGN_VERSION,missions} from '../src/campaign.js';
import {journalData} from '../src/evidence-journal.js';
import {contentUnits} from '../src/content-review.js';
test('Aso-Ebi: labelled invitation, source recovery, both permissions/custodies and once-only account',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-infiltration-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  const seed=async(id:string,c:object)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);};
  try{
    const ids=await infiltrationContract(app,ms=>{now+=ms;},seed);for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const id=ids[3],before=store.read(id).state.campaign;await app.close();store=new Store(file,()=>now);app=createApp(store);assert.deepEqual(store.read(id).state.campaign,before);
    assert.equal(before.choices['A24-consent'],'redacted_review');assert.equal(before.evidence.includes('witness_consent'),false);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('version-8 driving and interview checkpoints retain clearance and portfolio through upgrade',()=>{
  const old=chaseHub(),copy=structuredClone(old),upgraded=upgradeCampaign(old);assert.deepEqual(old,copy);assert.equal(upgraded.version,CAMPAIGN_VERSION);assert.deepEqual({...upgraded,version:8},old);
  const driving={...old,mission:'A23',status:'playing' as const,stage:4,drive:{distance:170,speed:0,lane:1,lastAt:1000,ready:false,misses:2,hint:'',gateCleared:true}};
  const migrated=upgradeCampaign(driving);assert.deepEqual(migrated.drive,driving.drive);assert.deepEqual(migrated.portfolio,old.portfolio);campaignCommand(migrated,'campaign_drive',4,'assist',2000);assert.equal(migrated.drive!.gateCleared,true);assert.equal(migrated.drive!.distance,220);
});
test('canonical invitation, permission responses and journal scopes are owner-reviewable',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/aso-ebi-infiltration.json',import.meta.url),'utf8')),missions.A24);
  for(const stage of missions.A24.stages){const unit=contentUnits.find(u=>u.id==='A24-'+stage.id)!;assert.ok(unit&&stage.summary);for(const response of Object.values(stage.responses??{}))if(response)assert.ok(unit.text.includes(response.text));}
  for(const text of Object.values(journalData.accountScopes))assert.ok(contentUnits.find(u=>u.id==='journal-account-permission')!.text.includes(text));
  assert.ok(contentUnits.find(u=>u.id==='journal-diary_lead')!.text.includes('not the recovered diary'));
});
