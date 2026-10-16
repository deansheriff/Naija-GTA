import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {campaignCommand,upgradeCampaign,missions,type Campaign} from '../src/campaign.js';
import {fuelHub} from './viral-contract.js';
import {publication} from '../src/viral-task.js';
export function viralHub(permission='approved'):Campaign{
 const c=upgradeCampaign(fuelHub(permission==='withdrawn'?'approved':permission));campaignCommand(c,'campaign_continue');
 for(let stage=0;stage<missions.A27.stages.length;stage++){
  const task=missions.A27.stages[stage];if(task.kind==='viral')for(const input of ['assist','check'])campaignCommand(c,'campaign_publish',stage,input);
  const choice=task.id==='permission'?(permission==='approved'?'retain':permission==='withdrawn'?'withdraw':'documents'):task.id==='route'?(permission==='approved'?'witness':'documents'):task.choices[0].id;
  campaignCommand(c,'campaign_choose',stage,choice);
 }
 return {...c,version:12};
}
export async function promisesContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
 const ids:string[]=[];
 for(const permission of ['approved','private','declined','withdrawn'])for(const question of ['lights','bus','pay']){
  advance(60000);const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();await seed(guest.character.id,viralHub(permission));
  const headers={authorization:`Bearer ${guest.token}`};let revision=0,serial=0;
  const raw=(body:object,key=`promise-input-exact-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
  const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
  let state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A31');const retained=structuredClone(state.campaign);
  assert.equal((await raw({kind:'campaign_promises',stage:0,choice:'assist'})).statusCode,422);
  for(let stage=0;stage<missions.A31.stages.length;stage++){
   const task=missions.A31.stages[stage];assert.equal(state.campaign.stage,stage);assert.equal(state.campaign.lead,task.lead);
   if(task.kind==='promise'){
    assert.equal((await raw({kind:'campaign_choose',stage,choice:'checked'})).statusCode,422);
    assert.equal((await raw({kind:'campaign_promises',stage,choice:'assist',promiseTask:{ready:true}})).statusCode,400);
    assert.equal((await raw({kind:'campaign_promises',stage,choice:'time:request'})).statusCode,422);
    state=await send({kind:'campaign_promises',stage,choice:'check'});assert.equal(state.campaign.promiseTask.ready,false);
    state=await send({kind:'campaign_promises',stage,choice:'lights:record'});const partial=structuredClone(state.campaign.promiseTask);
    state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});assert.deepEqual(state.campaign.promiseTask,partial);
    const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(recovered.character.state.campaign.promiseTask,partial);
    for(const choice of question==='lights'?['bus:record','pay:record']:['assist'])state=await send({kind:'campaign_promises',stage,choice});
    assert.equal(state.campaign.promiseTask.ready,false);state=await send({kind:'campaign_promises',stage,choice:'check'});assert.equal(state.campaign.promiseTask.ready,true);
   }
   const body={kind:'campaign_choose',stage,choice:task.id==='question'?question:task.choices[0].id};
   if(task.id==='close'){
    const expected=revision,key='promise-complete-once',pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
   }else state=await send(body);
  }
  assert.deepEqual(state.campaign.mastery,{tunde:11,ngozi:13,kc:13});assert.equal(state.coins,240);
  assert.equal(state.campaign.choices['A31-question'],question);assert.equal(state.campaign.choices['A31-allies'],'recorded');assert.equal(state.campaign.choices['A31-readiness'],'packet_ready');
  for(const field of ['phone','portfolio','receipt','queueTask','viral','witnessConsent','evidence'])assert.deepEqual(state.campaign[field],retained[field]);
  for(const [key,value] of Object.entries(retained.choices))assert.equal(state.campaign.choices[key],value);
  assert.equal((await raw({kind:'campaign_choose',stage:10,choice:'next'})).statusCode,422);
  state=await send({kind:'campaign_withdraw'});assert.equal(publication(state.campaign).route,'documents');assert.equal(state.campaign.completed.filter((id:string)=>id==='A31').length,1);
  ids.push(guest.character.id);
 }
 return ids;
}
