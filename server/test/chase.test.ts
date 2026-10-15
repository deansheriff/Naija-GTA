import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {chaseContract,interviewHub} from './chase-contract.js';
import {freshDrive,advanceDrive,chaseDrivingData} from '../src/driving-task.js';
import {upgradeCampaign,campaignCommand,CAMPAIGN_VERSION,missions} from '../src/campaign.js';
import {restoreEarnedRecords} from '../src/evidence-journal.js';
import {contentUnits} from '../src/content-review.js';
test('Danfo Chase: both turns, both copies, required waits, recovery and once-only clue/mastery',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-chase-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  const seed=async(id:string,c:object)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);};
  try{
    const ids=await chaseContract(app,ms=>{now+=ms;},seed);
    for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const guest=store.createGuest(),c=upgradeCampaign(interviewHub());campaignCommand(c,'campaign_continue',undefined,undefined,now);campaignCommand(c,'campaign_choose',0,'public_route',now);
    for(let i=0;i<3;i++)advanceDrive(c.drive!,'assist',now+=1000,350,missions.A23.stages[1].driveGate);
    await seed(guest.character.id,c);await app.close();store=new Store(file,()=>now);app=createApp(store);
    const restored=store.read(guest.character.id).state.campaign;assert.deepEqual(restored.drive,c.drive);assert.equal(restored.drive!.gateCleared,false);assert.deepEqual(restored.portfolio,c.portfolio);
    campaignCommand(restored,'campaign_drive',1,'yield',now+=1000);await seed(guest.character.id,restored);await app.close();store=new Store(file,()=>now);app=createApp(store);
    assert.equal(store.read(guest.character.id).state.campaign.drive!.gateCleared,true);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('crossing and queue gates bound elapsed time and require stopped lower-lane explicit waiting',()=>{
  for(const at of [150,170]){
    const gate={at,kind:at===150?'crossing':'queue'},d=freshDrive(1000);
    advanceDrive(d,'assist',1000000,350,gate);assert.equal(d.distance,50);assert.equal(d.ready,false);
    for(const [distance,speed,lane] of [[at-31,0,1],[at,3,1],[at,0,0],[at+1,0,1]]){
      Object.assign(d,{distance,speed,lane});advanceDrive(d,'yield',1001000,350,gate);assert.equal(d.gateCleared,undefined);
    }
    Object.assign(d,{distance:at,speed:0,lane:1});advanceDrive(d,'assist',1002000,350,gate);assert.equal(d.ready,false);assert.equal(d.distance,at);
    advanceDrive(d,'yield',1003000,350,gate);assert.equal(d.gateCleared,true);const stopped={...d};advanceDrive(d,'yield',1003000,350,gate);assert.deepEqual(d,stopped);
    for(let i=1;i<=4;i++)advanceDrive(d,'assist',1003000+i*1000,350,gate);assert.equal(d.ready,true);
  }
  const c=upgradeCampaign(interviewHub()),before=structuredClone(c.portfolio);assert.equal(c.version,CAMPAIGN_VERSION);assert.deepEqual(c.portfolio,before);
  c.mission='A21';c.status='playing';c.stage=5;c.drive=freshDrive(1000);assert.throws(()=>campaignCommand(c,'campaign_drive',5,'yield',2000));assert.equal(c.drive.gateCleared,undefined);
  restoreEarnedRecords(c);assert.equal(c.evidence.includes('service_slip'),false);c.completed.push('A23');restoreEarnedRecords(c);assert.equal(c.evidence.filter(id=>id==='service_slip').length,1);
});
test('chase authored data matches both clients and is available to owner review',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/danfo-chase.json',import.meta.url),'utf8')),missions.A23);
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/chase-driving.json',import.meta.url),'utf8')),chaseDrivingData);
  for(const stage of missions.A23.stages){const unit=contentUnits.find(u=>u.id==='A23-'+stage.id)!;assert.ok(unit&&stage.summary);for(const response of Object.values(stage.responses??{}))if(response)assert.ok(unit.text.includes(response.text));}
  const unit=contentUnits.find(u=>u.id==='chase-driving')!;for(const message of Object.values(chaseDrivingData.messages))assert.ok(unit.text.includes(message));
  assert.ok(contentUnits.find(u=>u.id==='journal-service_slip')!.text.includes('21:14'));
});
