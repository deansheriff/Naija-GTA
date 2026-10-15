import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {meetingContract} from './meeting-contract.js';
import {freshCampaign,upgradeCampaign,CAMPAIGN_VERSION,missions,type Campaign} from '../src/campaign.js';
import {freshPhone} from '../src/phone-task.js';
import {journalData,journalStatus,restoreEarnedRecords,journalAvailable} from '../src/evidence-journal.js';
import {contentUnits} from '../src/content-review.js';
import type {Intent} from '../src/rules.js';

test('Family Meeting: custody/pacts/disclosure combinations, missing-source recovery, retries and once-only ensemble awards',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-meeting-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  try{
    const ids=await meetingContract(app,ms=>{now+=ms;},async(id,evidence)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign.evidence',json(?)) WHERE id=?").run(JSON.stringify(evidence),id);});
    for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const guest=store.createGuest();
    const campaign={...freshCampaign(),version:4,mission:'A13',status:'hub',stage:11,lead:'kc',paused:false,completed:['P00','A11','A12','A13'],mastery:{tunde:3,ngozi:3,kc:3},evidence:['wedding_clip','bag_record','catering_invoice','original_clip'],choices:{'A13-disclose':'defer'},phone:{...freshPhone(),battery:3,pan:1,zoom:1,ready:true,takes:2}};
    store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(campaign),guest.character.id);
    let revision=0;const send=(kind:Intent['kind'],stage?:number,choice?:string)=>store.execute(guest.character.id,`meeting-restart-checkpoint-${revision}`,{kind,revision:revision++,stage,choice});
    send('campaign_continue');for(let stage=0;stage<10;stage++)send('campaign_choose',stage,stage===9?'joint_record':missions.A14.stages[stage].choices.find(c=>c.correct)!.id);
    await app.close();store=new Store(file,()=>now);app=createApp(store);
    const restored=store.read(guest.character.id).state.campaign;assert.equal(restored.version,CAMPAIGN_VERSION);assert.equal(restored.stage,10);assert.equal(restored.phone!.battery,3);assert.equal(restored.choices['A14-custody'],'joint_record');assert.equal(journalStatus(restored).disclosure,journalData.states.disclosure_admitted);
    send('campaign_choose',10,'protect');send('campaign_choose',11,'next');assert.deepEqual(store.read(guest.character.id).state.campaign.mastery,{tunde:4,ngozi:4,kc:4});
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('journal restores only eligible records and never erases a prior admission or grants mastery',()=>{
  const c={...freshCampaign(),mission:'A14',status:'playing',completed:['P00'],evidence:[],choices:{'A13-disclose':'admit','A14-disclosure':'later'}} as Campaign;
  restoreEarnedRecords(c);restoreEarnedRecords(c);assert.deepEqual(c.evidence,['wedding_clip']);assert.deepEqual(c.mastery,{tunde:0,ngozi:0,kc:0});assert.equal(journalAvailable(c),true);assert.equal(journalStatus(c).disclosure,journalData.states.disclosure_admitted);
  const old={...freshCampaign(),version:4,mission:'A13',status:'playing' as const,stage:2,phone:{...freshPhone(),battery:0,takes:4},choices:{'A13-consent':'ask'}};
  const updated=upgradeCampaign(old);assert.deepEqual({...updated,version:4},old);assert.equal(updated.version,CAMPAIGN_VERSION);assert.equal(old.version,4);
});
test('meeting/journal canonical sources, evidence requirements and owner-review coverage',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/family-meeting.json',import.meta.url),'utf8')),missions.A14);
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/evidence-journal.json',import.meta.url),'utf8')),journalData);
  for(const entry of journalData.entries){assert.ok(missions[entry.mission].evidence.includes(entry.id));const unit=contentUnits.find(u=>u.id==='journal-'+entry.id)!;assert.ok(unit.text.includes(entry.scope));assert.ok(unit.text.includes(entry.source));}
  for(const note of journalData.notes)assert.ok(contentUnits.find(u=>u.id==='journal-'+note.id)!.text.includes(note.scope));
  for(const text of Object.values(journalData.states))assert.ok(contentUnits.find(u=>u.id==='journal-meeting-status')!.text.includes(text));
  for(const stage of missions.A14.stages){assert.ok(stage.summary.length&&stage.choices.some(c=>c.correct));assert.ok(contentUnits.some(u=>u.id==='A14-'+stage.id));for(const id of stage.requiresEvidence??[])assert.ok(journalData.entries.some(e=>e.id===id));}
});
