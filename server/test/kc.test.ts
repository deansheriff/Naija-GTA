import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {kcContract} from './kc-contract.js';
import {freshCampaign,upgradeCampaign,CAMPAIGN_VERSION,missions} from '../src/campaign.js';
import {freshPhone,advancePhone} from '../src/phone-task.js';
import {contentUnits} from '../src/content-review.js';

test('Four Percent: three routes, both disclosures, manual/guided frames, depletion recovery and exact retries',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-kc-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  try{
    const ids=await kcContract(app,ms=>{now+=ms;});for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const guest=store.createGuest();
    const campaign={...freshCampaign(),version:3,mission:'A12',status:'hub',stage:11,lead:'ngozi',paused:false,completed:['P00','A11','A12'],mastery:{tunde:3,ngozi:3,kc:1},evidence:['wedding_clip','bag_record','catering_invoice']};
    store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(campaign),guest.character.id);
    let revision=0;const send=(kind:any,stage?:number,choice?:string)=>store.execute(guest.character.id,`kc-restart-checkpoint-${revision}`,{kind,revision:revision++,stage,choice});
    send('campaign_continue');send('campaign_choose',0,'next');send('campaign_choose',1,'ask');
    for(let i=0;i<4;i++)send('campaign_phone',2,'record');
    await app.close();store=new Store(file,()=>now);app=createApp(store);now+=86400000;
    assert.equal(store.read(guest.character.id).state.campaign.phone!.battery,0);send('sync');assert.equal(store.read(guest.character.id).state.campaign.phone!.battery,0);
    send('campaign_phone',2,'charge');send('campaign_phone',2,'assist');assert.equal(store.read(guest.character.id).state.campaign.phone!.ready,true);
    assert.equal(store.read(guest.character.id).state.campaign.version,CAMPAIGN_VERSION);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('story phone: only saved attempts cost battery, crop/depletion recovery, frame bounds and once-only takes',()=>{
  const p=freshPhone();advancePhone(p,'left',1);assert.equal(p.pan,0);advancePhone(p,'right',1);advancePhone(p,'right',1);advancePhone(p,'right',1);assert.equal(p.pan,2);assert.equal(p.battery,4);
  advancePhone(p,'wide',1);advancePhone(p,'record',1);assert.equal(p.ready,false);assert.equal(p.battery,3);
  for(let i=0;i<3;i++)advancePhone(p,'record',1);assert.equal(p.battery,0);assert.equal(p.takes,4);
  advancePhone(p,'record',1);assert.equal(p.takes,4);advancePhone(p,'charge',1);assert.equal(p.battery,4);assert.equal(p.charges,1);
  advancePhone(p,'assist',1);assert.equal(p.ready,true);assert.equal(p.pan,1);assert.equal(p.zoom,1);assert.equal(p.battery,3);
  advancePhone(p,'record',1);assert.equal(p.battery,3);assert.equal(p.takes,5);
});
test('KC canonical source, route/subject review coverage and version-3 schedule migration',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/kc-intro.json',import.meta.url),'utf8')),missions.A13);
  for(const stage of missions.A13.stages){const unit=contentUnits.find(u=>u.id==='A13-'+stage.id)!;assert.ok(unit);assert.equal(stage.lead,'kc');assert.ok(stage.summary.length&&stage.choices.some(c=>c.correct));
    for(const subject of stage.subjects??[])assert.ok(unit.text.includes(subject));
    for(const response of Object.values(stage.responses??{})){assert.ok(response);assert.ok(unit.text.includes(response.text));assert.ok(unit.text.includes(response.summary));}
    if(stage.kind==='frame')assert.equal(stage.recordCost,1);
  }
  const old={...freshCampaign(),version:3,mission:'A12',stage:5,choices:{'A12-sola_terms':'firm'}};delete (old as any).phone;
  const updated=upgradeCampaign(old);assert.equal(updated.version,CAMPAIGN_VERSION);assert.equal(updated.phone,null);assert.equal(updated.stage,5);assert.equal(updated.choices['A12-sola_terms'],'firm');assert.equal(old.version,3);
});
