import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions} from '../src/campaign.js';
import {journalAvailable,journalStatus} from '../src/evidence-journal.js';
export async function generatorContract(app:FastifyInstance,advance:(ms:number)=>void){
  const ids:string[]=[];
  for(const pact of ['protect','public_case'])for(const hours of ['one_first','two_first']){
    advance(60000);
    const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();let revision=0,serial=0;
    const headers={authorization:`Bearer ${guest.token}`};
    const raw=(body:object,key=`generator-command-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_start'});
    for(const id of ['P00','A11','A12','A13','A14']){
      for(let stage=0;stage<missions[id].stages.length;stage++){
        const task=missions[id].stages[stage];
        if(task.kind==='drive')for(let i=0;i<7;i++){advance(1000);await send({kind:'campaign_drive',stage,choice:'assist'});}
        if(task.kind==='frame')await send({kind:'campaign_phone',stage,choice:'assist'});
        state=await send({kind:'campaign_choose',stage,choice:id==='A14'&&task.id==='pact'?pact:task.choices.find(c=>c.correct)!.id});
      }
      advance(60000);state=await send({kind:'campaign_continue'});
    }
    assert.equal(state.campaign.mission,'A21');assert.equal(journalAvailable(state.campaign),true);
    const evidence=JSON.stringify(state.campaign.evidence),phone=JSON.stringify(state.campaign.phone),meeting=JSON.stringify(journalStatus(state.campaign));
    assert.equal((await raw({kind:'campaign_choose',stage:9,choice:'yard_c'})).statusCode,422);
    assert.equal((await raw({kind:'campaign_switch',choice:'kc'})).statusCode,422);
    assert.equal((await raw({kind:'campaign_drive',stage:0,choice:'assist'})).statusCode,422);
    for(let stage=0;stage<missions.A21.stages.length;stage++){
      const task=missions.A21.stages[stage];assert.equal(state.campaign.stage,stage);assert.equal(state.campaign.lead,task.lead);
      if(task.kind==='drive'){
        assert.equal((await raw({kind:'campaign_choose',stage,choice:task.choices[0].id})).statusCode,422);
        assert.equal((await raw({kind:'campaign_drive',stage,choice:'teleport',distance:350})).statusCode,400);
        state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});
        assert.equal(state.campaign.drive.distance,0);
        state=await send({kind:'campaign_review'});assert.equal(state.campaign.drive.distance,0);
        for(let i=0;i<7;i++){advance(1000);state=await send({kind:'campaign_drive',stage,choice:'assist'});}
        assert.equal(state.campaign.drive.ready,true);assert.equal(state.campaign.drive.speed,0);
        const recovery=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();
        assert.equal(recovery.character.state.campaign.stage,stage);assert.equal(recovery.character.state.campaign.drive.ready,true);
      }
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      const choice=task.id==='hours'?hours:task.id==='permission'&&hours==='two_first'?'joint_copy':task.choices.find(c=>c.correct)!.id;
      if(task.id==='close'){
        const expected=revision,key='generator-complete-exactly-once',body={kind:'campaign_choose',stage,choice};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:6,ngozi:6,kc:4});assert.equal(state.coins,240);
    assert.equal(JSON.stringify(state.campaign.evidence),evidence);assert.equal(JSON.stringify(state.campaign.phone),phone);assert.equal(JSON.stringify(journalStatus(state.campaign)),meeting);
    assert.equal(state.campaign.choices['A21-placement'],'yard_c');assert.equal(state.campaign.choices['A21-hours'],hours);assert.equal(state.campaign.choices['A14-pact'],pact);
    assert.equal((await raw({kind:'campaign_choose',stage:12,choice:'next'})).statusCode,422);
    state=await send({kind:'campaign_review'});assert.deepEqual(state.campaign.mastery,{tunde:6,ngozi:6,kc:4});
    ids.push(guest.character.id);
  }
  return ids;
}
