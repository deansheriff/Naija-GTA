import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions} from '../src/campaign.js';

export async function kcContract(app:FastifyInstance,advance:(ms:number)=>void){
  const ids:string[]=[];
  for(const [route,disclosure] of [['kiosk','admit'],['bank','defer'],['bench','admit']]){
    advance(60000);
    const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();let revision=0,serial=0;
    const headers={authorization:`Bearer ${guest.token}`};
    const raw=(body:object,key=`kc-story-command-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_start'});
    for(const id of ['P00','A11','A12']){
      for(let stage=0;stage<missions[id].stages.length;stage++){
        const task=missions[id].stages[stage];
        if(task.kind==='drive')for(let i=0;i<7;i++){advance(1000);await send({kind:'campaign_drive',stage,choice:'assist'});}
        state=await send({kind:'campaign_choose',stage,choice:task.choices.find(c=>c.correct)!.id});
      }
      advance(60000);state=await send({kind:'campaign_continue'});
    }
    assert.equal(state.campaign.mission,'A13');assert.equal(state.campaign.phone.battery,4);
    assert.equal((await raw({kind:'campaign_phone',stage:0,choice:'record'})).statusCode,422);
    for(let stage=0;stage<missions.A13.stages.length;stage++){
      const task=missions.A13.stages[stage];assert.equal(state.campaign.stage,stage);
      assert.equal((await raw({kind:'campaign_choose',stage:stage+1,choice:'next'})).statusCode,422);
      if(task.kind==='frame'){
        assert.equal((await raw({kind:'campaign_choose',stage,choice:'keep'})).statusCode,422);
        assert.equal((await raw({kind:'campaign_phone',stage,choice:'fly'})).statusCode,422);
        assert.equal((await raw({kind:'campaign_phone',stage,choice:'record',ready:true,battery:100})).statusCode,400);
        if(task.id==='practice'){
          advance(86400000);state=await send({kind:'sync'});assert.equal(state.campaign.phone.battery,4,'reading/closed time never drains story battery');
          await send({kind:'campaign_pause'});advance(86400000);state=await send({kind:'sync'});assert.equal(state.campaign.phone.battery,4);await send({kind:'campaign_resume'});
          for(let take=0;take<4;take++)state=await send({kind:'campaign_phone',stage,choice:'record'});
          assert.equal(state.campaign.phone.battery,0);assert.equal(state.campaign.phone.ready,false);assert.equal(state.campaign.phone.takes,4);assert.deepEqual(state.campaign.evidence,['wedding_clip','bag_record','catering_invoice']);
          state=await send({kind:'campaign_phone',stage,choice:'record'});assert.equal(state.campaign.phone.takes,4);
          const expected=revision,key='kc-empty-charge-once',body={kind:'campaign_phone',stage,choice:'charge'};
          const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
          assert.equal(state.campaign.phone.battery,4);assert.equal(state.campaign.phone.charges,1);
          const recovery=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.equal(recovery.character.state.campaign.phone.battery,4);
          await send({kind:'campaign_phone',stage,choice:'right'});state=await send({kind:'campaign_phone',stage,choice:'wide'});assert.equal(state.campaign.phone.battery,4,'adjusting the camera is free');
          state=await send({kind:'campaign_phone',stage,choice:'record'});
        }else{
          const expected=revision,key='kc-original-take-once',body={kind:'campaign_phone',stage,choice:'assist'};
          const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
        }
        assert.equal(state.campaign.phone.ready,true);assert.equal(state.campaign.phone.battery,3);
        const takes=state.campaign.phone.takes;state=await send({kind:'campaign_phone',stage,choice:'record'});assert.equal(state.campaign.phone.battery,3);assert.equal(state.campaign.phone.takes,takes,'completed take cannot debit twice');
      }
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      const choice=task.id==='route'?route:task.id==='disclose'?disclosure:task.choices.find(c=>c.correct)!.id;
      state=await send({kind:'campaign_choose',stage,choice});
      if(task.id==='charge')assert.equal(state.campaign.phone.battery,4);
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:3,ngozi:3,kc:3});assert.deepEqual(state.campaign.evidence,['wedding_clip','bag_record','catering_invoice','original_clip']);
    assert.equal(state.campaign.choices['A13-route'],route);assert.equal(state.campaign.choices['A13-disclose'],disclosure);assert.equal(state.coins,240);
    assert.equal((await raw({kind:'campaign_choose',stage:10,choice:'next'})).statusCode,422);
    ids.push(guest.character.id);
  }
  return ids;
}
