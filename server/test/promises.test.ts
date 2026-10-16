import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {promisesContract,viralHub} from './promises-contract.js';
import {campaignCommand,upgradeCampaign,missions} from '../src/campaign.js';
import {freshPromise,advancePromise,promiseData} from '../src/promise-task.js';
import {contentUnits} from '../src/content-review.js';
test('Promises: three questions, four prior scopes, saved record comparison and once-only ensemble completion',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'nsl-promises-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
 const seed=async(id:string,c:object)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);};
 try{
  const ids=await promisesContract(app,ms=>{now+=ms;},seed);for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
  const c=upgradeCampaign(viralHub());campaignCommand(c,'campaign_continue');for(let i=0;i<4;i++)campaignCommand(c,'campaign_choose',i,missions.A31.stages[i].choices[0].id);campaignCommand(c,'campaign_promises',4,'lights:record');
  const guest=store.createGuest();await seed(guest.character.id,c);await app.close();store=new Store(file,()=>now);app=createApp(store);assert.deepEqual(store.read(guest.character.id).state.campaign.promiseTask,c.promiseTask);
 }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('all promise interpretations keep readiness server-owned, recover missing sources and preserve version-12 input',()=>{
 for(let mask=0;mask<8;mask++){
  const task=freshPromise();promiseData.questions.forEach((q,i)=>advancePromise(task,q.id+':'+(mask&(1<<i)?'claim':'record')));advancePromise(task,'check');assert.equal(task.ready,mask===0);
  advancePromise(task,'assist');if(mask!==0){assert.equal(task.ready,false);advancePromise(task,'check');assert.equal(task.ready,true);}
  const held=structuredClone(task);advancePromise(task,'lights:claim');assert.deepEqual(task,held);
 }
 const legacy=viralHub(),copy=structuredClone(legacy),c=upgradeCampaign(legacy);assert.deepEqual(legacy,copy);assert.deepEqual({...c,version:12},legacy);
 campaignCommand(c,'campaign_continue');for(let i=0;i<3;i++)campaignCommand(c,'campaign_choose',i,missions.A31.stages[i].choices[0].id);c.evidence=c.evidence.filter(id=>id!=='diary');assert.throws(()=>campaignCommand(c,'campaign_choose',3,'dated_record'),/source record is missing/);campaignCommand(c,'campaign_review');campaignCommand(c,'campaign_choose',3,'dated_record');assert.equal(c.stage,4);
});
test('promise records, all reply branches, canonical board and separate forum note are owner-reviewable',()=>{
 assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/promises.json',import.meta.url),'utf8')),missions.A31);assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/promise-task.json',import.meta.url),'utf8')),promiseData);
 const board=contentUnits.find(u=>u.id==='promise-board')!;for(const q of promiseData.questions)for(const o of q.options)assert.ok(board.text.includes(o.label));for(const m of Object.values(promiseData.messages))assert.ok(board.text.includes(m));
 const reply=contentUnits.find(u=>u.id==='A31-reply')!;for(const r of Object.values(missions.A31.stages.find(s=>s.id==='reply')!.responses!))assert.ok(reply.text.includes(r!.text));assert.ok(contentUnits.find(u=>u.id==='journal-forum_packet'));
});
