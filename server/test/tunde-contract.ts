import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions,prologue} from '../src/campaign.js';

export async function tundeContract(app:FastifyInstance,advance:(ms:number)=>void){
  const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();let revision=0,serial=0;
  const headers={authorization:`Bearer ${guest.token}`};
  const raw=(body:object,key=`tunde-story-command-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
  const send=async(body:object)=>{const reply=await raw(body);assert.equal(reply.statusCode,200,reply.body);revision++;return reply.json().character.state;};
  let state=await send({kind:'campaign_start'});
  assert.equal((await raw({kind:'campaign_continue'})).statusCode,422);
  for(let stage=0;stage<prologue.stages.length;stage++)state=await send({kind:'campaign_choose',stage,choice:prologue.stages[stage].choices.find(c=>c.correct)!.id});
  state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A11');assert.equal(state.campaign.lead,'tunde');assert.deepEqual(state.campaign.completed,['P00']);
  assert.equal((await raw({kind:'campaign_switch',choice:'kc'})).statusCode,422);
  assert.equal((await raw({kind:'campaign_drive',stage:0,choice:'assist'})).statusCode,422);
  for(let stage=0;stage<missions.A11.stages.length;stage++){
    const task=missions.A11.stages[stage];assert.equal(state.campaign.stage,stage);
    if(task.kind==='drive'){
      assert.equal(state.campaign.drive.distance,0);assert.equal(state.campaign.drive.speed,0);
      assert.equal((await raw({kind:'campaign_choose',stage,choice:task.choices.find(c=>c.correct)!.id})).statusCode,422);
      assert.equal((await raw({kind:'campaign_drive',stage,choice:'fly'})).statusCode,422);
      assert.equal((await raw({kind:'campaign_drive',stage,choice:'assist',distance:350,ready:true})).statusCode,400);
      for(let i=0;i<3;i++)state=await send({kind:'campaign_drive',stage,choice:'accelerate'});
      assert.equal(state.campaign.drive.distance,0,'rapid commands cannot invent elapsed movement');
      advance(1000);const expected=revision,key=`tunde-drive-durable-${stage}`,body={kind:'campaign_drive',stage,choice:'assist'};
      const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;
      state=pair[0].json().character.state;assert.equal(state.campaign.drive.distance,50);
      assert.equal((await raw({...body,choice:'brake'},key,expected)).statusCode,409);
      if(stage===1){
        await send({kind:'campaign_pause'});advance(3600000);state=await send({kind:'sync'});assert.equal(state.campaign.drive.distance,50);
        const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.equal(recovered.character.state.campaign.drive.distance,50);
        state=await send({kind:'campaign_resume'});state=await send({kind:'campaign_drive',stage,choice:'assist'});assert.equal(state.campaign.drive.distance,50,'resume never catches up a closed road task');
      }
      for(let i=0;i<6;i++){advance(1000);state=await send({kind:'campaign_drive',stage,choice:'assist'});}
      assert.equal(state.campaign.drive.ready,true);assert.equal(state.campaign.drive.speed,0);assert.equal(state.campaign.drive.lane,1);
    }
    const wrong=task.choices.find(c=>!c.correct);if(wrong)assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
    state=await send({kind:'campaign_choose',stage,choice:task.choices.find(c=>c.correct)!.id});
  }
  assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.completed,['P00','A11']);assert.equal(state.campaign.mastery.tunde,3);assert.equal(state.campaign.mastery.ngozi,1);
  assert.deepEqual(state.campaign.evidence,['wedding_clip','bag_record']);assert.equal(state.coins,240);
  assert.equal((await raw({kind:'campaign_choose',stage:missions.A11.stages.length,choice:'next'})).statusCode,422);
  return guest.character.id as string;
}
