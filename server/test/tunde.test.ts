import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {tundeContract} from './tunde-contract.js';
import {freshDrive,advanceDrive} from '../src/driving-task.js';
import {upgradeCampaign,prologue,CAMPAIGN_VERSION,type Campaign} from '../src/campaign.js';
import type {Intent} from '../src/rules.js';

test('Tunde mission: three authoritative road legs, checkpoints, recovery and once-only bag/mastery',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-tunde-')),file=join(dir,'save.sqlite');
  let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  try{
    const id=await tundeContract(app,ms=>{now+=ms;});assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const guest=store.createGuest();let revision=0;
    const command=(kind:Intent['kind'],stage?:number,choice?:string)=>store.execute(guest.character.id,`tunde-restart-command-${revision}`,{kind,revision:revision++,stage,choice});
    command('campaign_start');for(let stage=0;stage<prologue.stages.length;stage++)command('campaign_choose',stage,prologue.stages[stage].choices.find(c=>c.correct)!.id);
    command('campaign_continue');command('campaign_choose',0,'next');now+=1000;command('campaign_drive',1,'assist');
    await app.close();store=new Store(file,()=>now);app=createApp(store);now+=3600000;
    assert.equal(store.read(guest.character.id).state.campaign.drive!.distance,50);
    command('sync');assert.equal(store.read(guest.character.id).state.campaign.drive!.distance,50,'restart/sync never drives without input');
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('driving rules: pace bounds, braking, lane requirements, missed-bay recovery and long-gap clamp',()=>{
  const d=freshDrive(1000);advanceDrive(d,'accelerate',2000,350);assert.equal(d.speed,30);assert.equal(d.distance,15);
  advanceDrive(d,'accelerate',102000,350);assert.equal(d.speed,60);assert.equal(d.distance,60,'long gaps advance at most one second');
  advanceDrive(d,'brake',103000,350);assert.equal(d.speed,0);assert.equal(d.distance,90);
  Object.assign(d,{distance:340,speed:0,lane:0,lastAt:103000});advanceDrive(d,'coast',104000,350);assert.equal(d.ready,false);
  advanceDrive(d,'lower',105000,350);assert.equal(d.ready,true);
  const missed=freshDrive(1000);for(let i=1;i<=12;i++)advanceDrive(missed,'accelerate',1000+i*1000,350);
  assert.ok(missed.misses>=1);assert.match(missed.hint,/free loop/);
  const assisted=freshDrive(1000);for(let i=1;i<=7;i++)advanceDrive(assisted,'assist',1000+i*1000,350);assert.equal(assisted.ready,true);
});
test('campaign version 1 upgrades without resetting a completed or unfinished wedding',()=>{
  for(const status of ['hub','playing'] as const){const old={version:1,status,stage:status==='hub'?14:6,lead:'ngozi',paused:true,completed:status==='hub'?['P00']:[],mastery:{tunde:1,ngozi:1,kc:1},evidence:['wedding_clip']} as unknown as Campaign;
    const result=upgradeCampaign(old);assert.equal(result.version,CAMPAIGN_VERSION);assert.equal(result.mission,'P00');assert.equal(result.stage,old.stage);assert.equal(result.status,status);assert.deepEqual(result.mastery,old.mastery);assert.deepEqual(result.evidence,old.evidence);}
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/tunde-intro.json',import.meta.url),'utf8')),JSON.parse(readFileSync(new URL('../src/tunde-intro.json',import.meta.url),'utf8')));
});
