import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {queueContract,receiptsHub} from './queue-contract.js';
import {campaignCommand,upgradeCampaign,missions} from '../src/campaign.js';
import {freshQueue,advanceQueue,queueData} from '../src/queue-task.js';
import {contentUnits} from '../src/content-review.js';
test('Fuel Queue: both approaches, manual/guided controls, three prior permission states and once-only mastery',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'nsl-queue-')),file=join(dir,'save.sqlite');let now=1700000000000,store=new Store(file,()=>now),app=createApp(store);
  const seed=async(id:string,c:object)=>{store.db.prepare("UPDATE characters SET state=json_set(state,'$.campaign',json(?)) WHERE id=?").run(JSON.stringify(c),id);};
  try{
    const ids=await queueContract(app,ms=>{now+=ms;},seed);for(const id of ids)assert.equal(store.db.prepare('SELECT COUNT(*) AS total FROM ledger WHERE character_id=?').get(id)!.total,1);
    const c=upgradeCampaign(receiptsHub());campaignCommand(c,'campaign_continue');for(let i=0;i<2;i++)campaignCommand(c,'campaign_choose',i,missions.A26.stages[i].choices[0].id);campaignCommand(c,'campaign_queue',2,'verify');campaignCommand(c,'campaign_queue',2,'earlier:bus');
    const guest=store.createGuest();await seed(guest.character.id,c);await app.close();store=new Store(file,()=>now);app=createApp(store);assert.deepEqual(store.read(guest.character.id).state.campaign.queueTask,c.queueTask);assert.equal(c.queueTask!.lineReady,false);
  }finally{await app.close();rmSync(dir,{recursive:true,force:true});}
});
test('all queue permutations recover without dropping parties, guidance needs check, reset ordering and bounds',()=>{
  const permutations=[['bus','home','cart'],['bus','cart','home'],['home','bus','cart'],['home','cart','bus'],['cart','bus','home'],['cart','home','bus']];
  for(const order of permutations){
    const q=freshQueue();q.order=[...order];advanceQueue(q,'check','line');assert.equal(q.lineReady,false);advanceQueue(q,'verify','line');
    for(const id of queueData.order)while(q.order.indexOf(id)>queueData.order.indexOf(id))advanceQueue(q,'earlier:'+id,'line');
    assert.deepEqual(q.order,queueData.order);advanceQueue(q,'check','line');assert.equal(q.lineReady,true);const held=structuredClone(q);advanceQueue(q,'later:bus','line');assert.deepEqual(q,held);
    advanceQueue(q,'aisle','reset');assert.equal(q.aisleClear,false);advanceQueue(q,'bucket','reset');advanceQueue(q,'aisle','reset');assert.equal(q.resetReady,false);advanceQueue(q,'check','reset');assert.equal(q.resetReady,true);
  }
  const guided=freshQueue();advanceQueue(guided,'assist','line');assert.equal(guided.lineReady,false);advanceQueue(guided,'check','line');assert.equal(guided.lineReady,true);
  guided.checks=100000;advanceQueue(guided,'check','reset');assert.equal(guided.checks,100000);
  const old=receiptsHub(),copy=structuredClone(old),updated=upgradeCampaign(old);assert.deepEqual(old,copy);assert.deepEqual({...updated,version:10},old);
});
test('queue canonical control messages, arrivals and contextual responses are owner-reviewable',()=>{
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/fuel-queue-standoff.json',import.meta.url),'utf8')),missions.A26);assert.deepEqual(JSON.parse(readFileSync(new URL('../../game/story/queue-task.json',import.meta.url),'utf8')),queueData);
  for(const stage of missions.A26.stages){const unit=contentUnits.find(u=>u.id==='A26-'+stage.id)!;assert.ok(unit);for(const response of Object.values(stage.responses??{}))if(response)assert.ok(unit.text.includes(response.text));}
  const board=contentUnits.find(u=>u.id==='queue-board')!;for(const message of Object.values(queueData.messages))assert.ok(board.text.includes(message));
  assert.ok(contentUnits.find(u=>u.id==='journal-transport_allocation')!.text.includes('not wedding evidence'));
});
