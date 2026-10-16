import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions,type Campaign} from '../src/campaign.js';
import {infiltrationHub} from './receipts-contract.js';
import {freshReceipt,advanceReceipt,witnessTextHash} from '../src/receipt-task.js';
export function receiptsHub(permission='approved'):Campaign{
  const c=infiltrationHub(permission==='private'?'private_only':'redacted_review'),receipt=freshReceipt();advanceReceipt(receipt,'assist');advanceReceipt(receipt,'check');
  return {...c,version:10,mission:'A25',stage:13,status:'hub',completed:[...c.completed,'A25'],mastery:{tunde:9,ngozi:11,kc:8},evidence:[...c.evidence,'diary','note_discrepancy',...(permission==='approved'?['witness_consent']:[])],choices:{...c.choices,'A25-public_review':permission==='approved'?'approve_ne1':'private_records'},receipt,witnessConsent:permission==='approved'?{textHash:witnessTextHash,scope:'redacted_text',active:true}:null};
}
export async function queueContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
  const ids:string[]=[];
  for(const permission of ['approved','private','declined'])for(const approach of ['talk','patient']){
    advance(60000);const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();await seed(guest.character.id,receiptsHub(permission));
    const headers={authorization:`Bearer ${guest.token}`};let revision=0,serial=0;
    const raw=(body:object,key=`queue-input-exact-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A26');const retained=structuredClone(state.campaign);
    assert.equal((await raw({kind:'campaign_queue',stage:0,choice:'assist'})).statusCode,422);
    for(let stage=0;stage<missions.A26.stages.length;stage++){
      const task=missions.A26.stages[stage];assert.equal(state.campaign.stage,stage);assert.equal(state.campaign.lead,task.lead);
      if(task.kind==='queue'){
        const command={kind:'campaign_queue',stage};
        assert.equal((await raw({kind:'campaign_choose',stage,choice:task.choices[0].id})).statusCode,422);
        assert.equal((await raw({...command,choice:'assist',queueTask:{lineReady:true}})).statusCode,400);
        assert.equal((await raw({...command,choice:task.queuePhase==='line'?'bucket':'earlier:bus'})).statusCode,422);
        state=await send({...command,choice:'check'});assert.equal(state.campaign.queueTask[task.queuePhase==='line'?'lineReady':'resetReady'],false);
        if(task.queuePhase==='line'){
          const expected=revision,key='queue-move-bus-once',body={...command,choice:'earlier:bus'};const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);
          assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;assert.deepEqual(state.campaign.queueTask.order,['cart','bus','home']);
          const held=structuredClone(state.campaign.queueTask);state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});assert.deepEqual(state.campaign.queueTask,held);
          const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(recovered.character.state.campaign.queueTask,held);
          if(approach==='talk')for(const choice of ['earlier:bus','later:cart','verify'])state=await send({...command,choice});else state=await send({...command,choice:'assist'});
          assert.equal(state.campaign.queueTask.lineReady,false);assert.deepEqual(state.campaign.queueTask.order,['bus','home','cart']);
        }else{
          state=await send({...command,choice:'aisle'});assert.equal(state.campaign.queueTask.aisleClear,false);
          if(approach==='talk')for(const choice of ['bucket','aisle'])state=await send({...command,choice});else state=await send({...command,choice:'assist'});
          assert.equal(state.campaign.queueTask.resetReady,false);
        }
        state=await send({...command,choice:'check'});assert.equal(state.campaign.queueTask[task.queuePhase==='line'?'lineReady':'resetReady'],true);
        const checks=state.campaign.queueTask.checks;state=await send({...command,choice:'check'});assert.equal(state.campaign.queueTask.checks,checks);
      }
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      const choice=task.id==='approach'?approach:task.choices[0].id;
      if(task.id==='close'){
        const expected=revision,key='queue-complete-once',body={kind:'campaign_choose',stage,choice};const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);
        assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:10,ngozi:12,kc:9});assert.equal(state.coins,240);assert.equal(state.campaign.completed.filter((id:string)=>id==='A26').length,1);
    for(const field of ['phone','portfolio','receipt','witnessConsent','evidence'])assert.deepEqual(state.campaign[field],(retained as any)[field]);
    for(const [key,value] of Object.entries(retained.choices))assert.equal(state.campaign.choices[key],value);
    assert.equal(state.campaign.choices['A26-approach'],approach);assert.equal(state.campaign.queueTask.lineReady,true);assert.equal(state.campaign.queueTask.resetReady,true);
    assert.equal((await raw({kind:'campaign_choose',stage:12,choice:'next'})).statusCode,422);ids.push(guest.character.id);
  }
  return ids;
}
