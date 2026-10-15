import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {receiptsContract,infiltrationHub} from './receipts-contract.js';
import {campaignCommand,upgradeCampaign,missions} from '../src/campaign.js';
import {freshReceipt,advanceReceipt,receiptData,witnessTextHash,hasWitnessConsent} from '../src/receipt-task.js';
import {restoreEarnedRecords} from '../src/evidence-journal.js';
import {contentUnits} from '../src/content-review.js';
test('Small Small Receipts: both custodies, three permission paths, saved comparison and once-only records',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-receipts-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  const seed=async(id:string,c:object)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);};
  try{
    const ids=await receiptsContract(app,ms=>{now+=ms;},seed);for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const c=upgradeCampaign(infiltrationHub());campaignCommand(c,'campaign_continue');for(let i=0;i<7;i++)campaignCommand(c,'campaign_choose',i,missions.A25.stages[i].choices[0].id);campaignCommand(c,'campaign_compare',7,'check');
    const guest=store.createGuest();await seed(guest.character.id,c);await app.close();store=new Store(file,()=>now);app=createApp(store);assert.deepEqual(store.read(guest.character.id).state.campaign.receipt,c.receipt);assert.equal(c.receipt!.attempts,1);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('comparison bounds, exact witness-text scope and earned-only conditional recovery',()=>{
  for(let mask=0;mask<8;mask++){
    const task=freshReceipt();receiptData.questions.forEach((q,i)=>advanceReceipt(task,q.id+':'+q.options[(mask>>i)&1].id));advanceReceipt(task,'check');assert.equal(task.ready,mask===0);assert.equal(task.attempts,1);
    if(mask){advanceReceipt(task,'assist');assert.equal(task.ready,false);advanceReceipt(task,'check');assert.equal(task.ready,true);}
    const held=structuredClone(task);advanceReceipt(task,'check');advanceReceipt(task,'issue:current');assert.deepEqual(task,held);
  }
  const c=upgradeCampaign(infiltrationHub());c.completed.push('A25');c.choices['A25-public_review']='approve_ne1';c.witnessConsent={textHash:witnessTextHash,scope:'redacted_text',active:true};
  assert.equal(hasWitnessConsent(c),true);restoreEarnedRecords(c);assert.ok(c.evidence.includes('witness_consent'));
  for(const change of ['hash','inactive','private']){
    const invalid=structuredClone(c);invalid.evidence=invalid.evidence.filter(id=>id!=='witness_consent');
    if(change==='hash')invalid.witnessConsent!.textHash='f'.repeat(64);if(change==='inactive')invalid.witnessConsent!.active=false;if(change==='private')invalid.choices['A24-consent']='private_only';
    assert.equal(hasWitnessConsent(invalid),false);restoreEarnedRecords(invalid);assert.equal(invalid.evidence.includes('witness_consent'),false);assert.ok(invalid.evidence.includes('diary'));
  }
  const final=upgradeCampaign(infiltrationHub());final.mission='A25';final.status='playing';final.stage=12;final.choices['A25-public_review']='private_records';final.evidence=final.evidence.filter(id=>id!=='wedding_clip');
  campaignCommand(final,'campaign_choose',12,'next');assert.equal(final.evidence.includes('wedding_clip'),false);assert.ok(final.evidence.includes('diary'));
});
test('receipt board and exact reviewed text match clients and owner catalogue',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/small-small-receipts.json',import.meta.url),'utf8')),missions.A25);assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/receipt-task.json',import.meta.url),'utf8')),receiptData);
  assert.equal(missions.A25.stages.find(s=>s.id==='public_review')!.records![0].lines[0],receiptData.witnessText);
  for(const stage of missions.A25.stages)assert.ok(contentUnits.find(u=>u.id==='A25-'+stage.id));
  const board=contentUnits.find(u=>u.id==='receipt-board')!;for(const q of receiptData.questions)for(const option of q.options)assert.ok(board.text.includes(option.label));assert.ok(board.text.includes(receiptData.witnessText));
});
