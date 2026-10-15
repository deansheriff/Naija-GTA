import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {generatorContract} from './generator-contract.js';
import {freshCampaign,upgradeCampaign,CAMPAIGN_VERSION,missions} from '../src/campaign.js';
import {freshPhone} from '../src/phone-task.js';
import {contentUnits} from '../src/content-review.js';
import type {Intent} from '../src/rules.js';
test('Generator Wars: both pacts and schedules, stopped junctions, recovery and once-only rewards',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-generator-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  try{
    const ids=await generatorContract(app,ms=>{now+=ms;});for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const guest=store.createGuest();
    const campaign={...freshCampaign(),version:5,mission:'A14',status:'hub',stage:12,lead:'ngozi',paused:false,completed:['P00','A11','A12','A13','A14'],mastery:{tunde:4,ngozi:4,kc:4},evidence:['wedding_clip','bag_record','catering_invoice','original_clip'],choices:{'A14-pact':'protect','A14-custody':'joint_record'},phone:{...freshPhone(),battery:0,takes:4}};
    store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(campaign),guest.character.id);
    let revision=0;const send=(kind:Intent['kind'],stage?:number,choice?:string)=>store.execute(guest.character.id,`generator-restart-checkpoint-${revision}`,{kind,revision:revision++,stage,choice});
    send('campaign_continue');for(let stage=0;stage<3;stage++)send('campaign_choose',stage,missions.A21.stages[stage].choices[0].id);
    now+=1000;send('campaign_drive',3,'accelerate');now+=1000;send('campaign_drive',3,'accelerate');
    const before=store.read(guest.character.id).state.campaign;assert.ok(before.drive!.distance>0);await app.close();store=new Store(file,()=>now);app=createApp(store);
    const restored=store.read(guest.character.id).state.campaign;assert.equal(restored.version,CAMPAIGN_VERSION);assert.deepEqual(restored.drive,before.drive);assert.equal(restored.phone!.battery,0);assert.equal(restored.choices['A14-pact'],'protect');
    send('campaign_pause');now+=600000;send('campaign_resume');assert.equal(store.read(guest.character.id).state.campaign.drive!.distance,before.drive!.distance);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('Generator Wars canonical content, review variations and non-destructive version-5 upgrade',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/generator-wars.json',import.meta.url),'utf8')),missions.A21);
  const old={...freshCampaign(),version:5,mission:'A14',choices:{'A14-pact':'public_case'},phone:{...freshPhone(),battery:0,takes:4}};const copy=structuredClone(old),updated=upgradeCampaign(old);
  assert.deepEqual({...updated,version:5},copy);assert.equal(updated.version,CAMPAIGN_VERSION);assert.deepEqual(old,copy);
  assert.equal(missions.A21.stages.filter(s=>s.kind==='drive').length,3);
  for(const stage of missions.A21.stages){const review=contentUnits.find(u=>u.id==='A21-'+stage.id)!;assert.ok(stage.summary&&review);for(const response of Object.values(stage.responses??{}))if(response)assert.ok(review.text.includes(response.text));}
});
