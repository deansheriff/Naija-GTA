import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions} from '../src/campaign.js';

export async function ngoziContract(app:FastifyInstance,advance:(ms:number)=>void){
  const ids:string[]=[];
  for(const approach of ['patient','firm']){
    advance(60000);
    const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();let revision=0,serial=0;
    const headers={authorization:`Bearer ${guest.token}`};
    const raw=(body:object,key=`ngozi-story-command-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_start'});
    for(const id of ['P00','A11']){
      for(let stage=0;stage<missions[id].stages.length;stage++){
        const task=missions[id].stages[stage];
        if(task.kind==='drive')for(let i=0;i<7;i++){advance(1000);await send({kind:'campaign_drive',stage,choice:'assist'});}
        state=await send({kind:'campaign_choose',stage,choice:task.choices.find(c=>c.correct)!.id});
      }
      advance(60000);state=await send({kind:'campaign_continue'});
    }
    assert.equal(state.campaign.mission,'A12');assert.equal(state.campaign.lead,'ngozi');
    let balances={coins:state.coins,food:state.food,energy:state.energy,comfort:state.comfort};
    assert.equal((await raw({kind:'campaign_drive',stage:0,choice:'assist'})).statusCode,422);
    assert.equal((await raw({kind:'campaign_choose',stage:0,choice:'next',records:{paid:true}})).statusCode,400);
    for(let stage=0;stage<missions.A12.stages.length;stage++){
      const task=missions.A12.stages[stage];assert.equal(state.campaign.stage,stage);
      assert.equal((await raw({kind:'campaign_choose',stage:stage+1,choice:'next'})).statusCode,422,'cannot skip a record checkpoint');
      for(const wrong of task.choices.filter(c=>!c.correct)){
        const r=await raw({kind:'campaign_choose',stage,choice:wrong.id});assert.equal(r.statusCode,422);assert.ok(r.json().message.length);
      }
      if(stage===3){
        advance(3600000);state=await send({kind:'sync'});assert.deepEqual({coins:state.coins,food:state.food,energy:state.energy,comfort:state.comfort},balances,'active story reading freezes street needs');
        await send({kind:'campaign_pause'});advance(3600000);state=await send({kind:'sync'});assert.equal(state.campaign.stage,3);assert.equal(state.campaign.choices['A12-bolu_status'],'pending');
        const recovery=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.equal(recovery.character.state.campaign.stage,3);
        state=await send({kind:'campaign_resume'});
        balances={coins:state.coins,food:state.food,energy:state.energy,comfort:state.comfort};
      }
      const choice=task.id==='sola_terms'?approach:task.choices.find(c=>c.correct)!.id;
      if(task.id==='sola_receipt'){
        const expected=revision,key='ngozi-agreed-receipt-once',body={kind:'campaign_choose',stage,choice};
        const replies=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(replies.map(r=>r.statusCode),[200,200]);assert.deepEqual(replies[0].json(),replies[1].json());revision++;state=replies[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.completed,['P00','A11','A12']);
    assert.deepEqual(state.campaign.mastery,{tunde:3,ngozi:3,kc:1});assert.deepEqual(state.campaign.evidence,['wedding_clip','bag_record','catering_invoice']);
    assert.equal(state.campaign.choices['A12-sola_terms'],approach);assert.equal(state.campaign.choices['A12-sola_receipt'],'agreed');assert.equal(state.campaign.choices['A12-appointment'],'private');
    assert.deepEqual({coins:state.coins,food:state.food,energy:state.energy,comfort:state.comfort},balances);
    assert.equal((await raw({kind:'campaign_continue'})).statusCode,422);assert.equal((await raw({kind:'campaign_choose',stage:10,choice:'next'})).statusCode,422);
    ids.push(guest.character.id);
  }
  return ids;
}
