import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {viralContract,fuelHub} from './viral-contract.js';
import {campaignCommand,upgradeCampaign,missions} from '../src/campaign.js';
import {freshViral,advanceViral,viralData,publication} from '../src/viral-task.js';
import {hasWitnessConsent,witnessTextHash} from '../src/receipt-task.js';
import {contentUnits} from '../src/content-review.js';
import {journalStatus} from '../src/evidence-journal.js';
test('Viral: prior permission routes, saved corrections, recovery, exact checks, withdrawal and once-only mastery',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'nsl-viral-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
 const seed=async(id:string,c:object)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);};
 try{
  const ids=await viralContract(app,ms=>{now+=ms;},seed);for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
  const c=upgradeCampaign(fuelHub());campaignCommand(c,'campaign_continue');campaignCommand(c,'campaign_choose',0,'compare');campaignCommand(c,'campaign_publish',1,'stamp:limited');
  const guest=store.createGuest();await seed(guest.character.id,c);await app.close();store=new Store(file,()=>now);app=createApp(store);assert.deepEqual(store.read(guest.character.id).state.campaign.viral,c.viral);
 }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('Viral manual/guided boards retain source limits, require checks and permission cannot revive after withdrawal',()=>{
 for(const mode of ['manual','guided']){
  const v=freshViral();for(const phase of ['rumour','correction'] as const){
   advanceViral(v,'check',phase);assert.equal(v[phase].ready,false);
   if(mode==='guided')advanceViral(v,'assist',phase);else for(const q of viralData[phase].questions)advanceViral(v,q.id+':limited',phase);
   assert.equal(v[phase].ready,false);advanceViral(v,'check',phase);assert.equal(v[phase].ready,true);const held=structuredClone(v);advanceViral(v,'assist',phase);assert.deepEqual(v,held);
  }
 }
 const c=upgradeCampaign(fuelHub()),old=structuredClone(c);c.choices['A27-permission']='retain';c.choices['A27-route']='witness';assert.equal(publication(c).route,'witness');
 for(const consent of [null,{active:false,scope:'redacted_text' as const,textHash:witnessTextHash},{active:true,scope:'redacted_text' as const,textHash:'wrong'}]){c.witnessConsent=consent;assert.equal(publication(c).route,'documents');}
 c.witnessConsent=old.witnessConsent;campaignCommand(c,'campaign_withdraw');c.witnessConsent=old.witnessConsent;assert.equal(hasWitnessConsent(c),false);assert.equal(publication(c).route,'documents');
 c.choices['A27-correction']='save_correction';assert.ok(journalStatus(c).disclosure.includes('KC explained'));
 const v=freshViral();v.rumour.attempts=100000;advanceViral(v,'check','rumour');assert.equal(v.rumour.attempts,100000);
 const recovery=upgradeCampaign(fuelHub());campaignCommand(recovery,'campaign_continue');campaignCommand(recovery,'campaign_choose',0,'compare');for(const input of ['assist','check'])campaignCommand(recovery,'campaign_publish',1,input);recovery.evidence=recovery.evidence.filter(id=>id!=='original_clip');assert.throws(()=>campaignCommand(recovery,'campaign_choose',1,'limited'),/source record is missing/);campaignCommand(recovery,'campaign_review');campaignCommand(recovery,'campaign_choose',1,'limited');assert.equal(recovery.stage,2);
 const legacy=fuelHub(),copy=structuredClone(legacy);assert.deepEqual({...upgradeCampaign(legacy),version:11},legacy);assert.deepEqual(legacy,copy);
});
test('Viral canonical questions, disclosure, document package and withdrawal wording are owner-reviewable',()=>{
 assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/viral.json',import.meta.url),'utf8')),missions.A27);assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/viral-task.json',import.meta.url),'utf8')),viralData);
 const board=contentUnits.find(u=>u.id==='viral-board')!;assert.ok(board);for(const phase of ['rumour','correction'] as const){assert.ok(board.text.includes(viralData[phase].instructions));for(const q of viralData[phase].questions)for(const o of q.options)assert.ok(board.text.includes(o.label));for(const message of Object.values(viralData[phase].messages))assert.ok(board.text.includes(message));}for(const line of [viralData.disclosure,...viralData.documents,...Object.values(viralData.status)])assert.ok(board.text.includes(line));assert.ok(board.choices.includes(viralData.withdrawLabel));for(const stage of missions.A27.stages)assert.ok(contentUnits.find(u=>u.id==='A27-'+stage.id));
});
