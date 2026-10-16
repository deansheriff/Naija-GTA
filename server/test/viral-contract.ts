import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {campaignCommand,upgradeCampaign,missions,type Campaign} from '../src/campaign.js';
import {receiptsHub} from './queue-contract.js';
import {publication} from '../src/viral-task.js';
import {hasWitnessConsent,receiptData} from '../src/receipt-task.js';
export function fuelHub(permission='approved'):Campaign{
 const c=upgradeCampaign(receiptsHub(permission));campaignCommand(c,'campaign_continue');
 for(let stage=0;stage<missions.A26.stages.length;stage++){
  const task=missions.A26.stages[stage];if(task.kind==='queue')for(const input of ['assist','check'])campaignCommand(c,'campaign_queue',stage,input);
  campaignCommand(c,'campaign_choose',stage,task.choices[0].id);
 }
 return {...c,version:11};
}
export async function viralContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
 const ids:string[]=[];
 for(const permission of ['approved','private','declined'])for(const route of ['documents','witness']){
  advance(60000);const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();await seed(guest.character.id,fuelHub(permission));
  const headers={authorization:`Bearer ${guest.token}`};let revision=0,serial=0;
  const raw=(body:object,key=`viral-input-exact-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
  const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
  let state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A27');const retained=structuredClone(state.campaign);
  assert.equal((await raw({kind:'campaign_publish',stage:0,choice:'assist'})).statusCode,422);
  for(let stage=0;stage<missions.A27.stages.length;stage++){
   const task=missions.A27.stages[stage];assert.equal(state.campaign.stage,stage);
   if(task.kind==='viral'){
    assert.equal((await raw({kind:'campaign_choose',stage,choice:task.choices[0].id})).statusCode,422);
    assert.equal((await raw({kind:'campaign_publish',stage,choice:'assist',viral:{ready:true}})).statusCode,400);
    assert.equal((await raw({kind:'campaign_publish',stage,choice:task.viralPhase==='rumour'?'visual:limited':'stamp:limited'})).statusCode,422);
    state=await send({kind:'campaign_publish',stage,choice:'check'});assert.equal(state.campaign.viral[task.viralPhase!].ready,false);
    const partial=task.viralPhase==='rumour'?'stamp:limited':'disclosure:limited';state=await send({kind:'campaign_publish',stage,choice:partial});
    const held=structuredClone(state.campaign.viral);state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});assert.deepEqual(state.campaign.viral,held);
    const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(recovered.character.state.campaign.viral,held);
    state=await send({kind:'campaign_publish',stage,choice:'assist'});assert.equal(state.campaign.viral[task.viralPhase!].ready,false);
    const expected=revision,key='viral-exact-check-'+stage,body={kind:'campaign_publish',stage,choice:'check'};const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);
    assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
    assert.equal(state.campaign.viral[task.viralPhase!].ready,true);assert.equal(state.campaign.viral[task.viralPhase!].attempts,2);
   }
   let choice=task.choices[0].id;
   if(task.id==='permission'){
    if(permission!=='approved')assert.equal((await raw({kind:'campaign_choose',stage,choice:'retain'})).statusCode,422);
    choice=permission==='approved'&&route==='witness'?'retain':permission==='approved'?'withdraw':'documents';
   }
   if(task.id==='route'){
    if(!hasWitnessConsent(state.campaign))assert.equal((await raw({kind:'campaign_choose',stage,choice:'witness'})).statusCode,422);
    choice=hasWitnessConsent(state.campaign)&&route==='witness'?'witness':'documents';
   }
   state=await send({kind:'campaign_choose',stage,choice});
  }
  assert.deepEqual(state.campaign.mastery,{tunde:10,ngozi:12,kc:12});assert.equal(state.coins,240);
  for(const field of ['phone','portfolio','receipt','queueTask'])assert.deepEqual(state.campaign[field],retained[field]);
  for(const [key,value] of Object.entries(retained.choices))assert.equal(state.campaign.choices[key],value);
  assert.equal((await raw({kind:'campaign_choose',stage:9,choice:'next'})).statusCode,422);
  if(permission==='approved'&&route==='witness')assert.deepEqual(publication(state.campaign).lines,[receiptData.witnessText]);
  state=await send({kind:'campaign_withdraw'});assert.equal(hasWitnessConsent(state.campaign),false);assert.equal(publication(state.campaign).route,'documents');assert.equal(state.campaign.evidence.includes('witness_consent'),false);
  state=await send({kind:'campaign_review'});assert.equal(state.campaign.evidence.includes('witness_consent'),false);assert.equal(state.campaign.completed.filter((id:string)=>id==='A27').length,1);
  ids.push(guest.character.id);
 }
 return ids;
}
