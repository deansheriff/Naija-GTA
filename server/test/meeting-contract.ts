import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions} from '../src/campaign.js';
import {journalAvailable,journalStatus,journalData} from '../src/evidence-journal.js';

export async function meetingContract(app:FastifyInstance,advance:(ms:number)=>void,replaceEvidence:(id:string,evidence:string[])=>Promise<void>){
  const scenarios=[
    {prior:'admit',correction:'later',custody:'ngozi_record',pact:'protect'},
    {prior:'defer',correction:'tell',custody:'joint_record',pact:'public_case'},
    {prior:'defer',correction:'later',custody:'joint_record',pact:'protect'},
    {prior:'admit',correction:'tell',custody:'ngozi_record',pact:'public_case'}
  ];
  const ids:string[]=[];
  for(const [caseIndex,scenario] of scenarios.entries()){
    advance(60000);
    const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();let revision=0,serial=0;
    const headers={authorization:`Bearer ${guest.token}`};
    const raw=(body:object,key=`meeting-story-command-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_start'});
    assert.equal((await raw({kind:'campaign_review'})).statusCode,422);
    for(const id of ['P00','A11','A12','A13']){
      for(let stage=0;stage<missions[id].stages.length;stage++){
        const task=missions[id].stages[stage];
        if(task.kind==='drive')for(let i=0;i<7;i++){advance(1000);await send({kind:'campaign_drive',stage,choice:'assist'});}
        if(task.kind==='frame')await send({kind:'campaign_phone',stage,choice:'assist'});
        state=await send({kind:'campaign_choose',stage,choice:id==='A13'&&task.id==='disclose'?scenario.prior:task.choices.find(c=>c.correct)!.id});
      }
      assert.equal((await raw({kind:'campaign_review'})).statusCode,422);
      advance(60000);state=await send({kind:'campaign_continue'});
    }
    assert.equal(state.campaign.mission,'A14');assert.equal(journalAvailable(state.campaign),true);assert.deepEqual(state.campaign.mastery,{tunde:3,ngozi:3,kc:3});
    const phone=JSON.stringify(state.campaign.phone);
    assert.equal((await raw({kind:'campaign_review',evidence:['diary']})).statusCode,400);
    assert.equal((await raw({kind:'campaign_switch',choice:'kc'})).statusCode,422);
    for(let stage=0;stage<missions.A14.stages.length;stage++){
      const task=missions.A14.stages[stage];assert.equal(state.campaign.stage,stage);assert.equal(state.campaign.lead,task.lead);
      assert.equal((await raw({kind:'campaign_choose',stage:stage+1,choice:'next'})).statusCode,422);
      if(stage===3&&caseIndex===0){
        await replaceEvidence(guest.character.id,state.campaign.evidence.filter((id:string)=>id!=='bag_record'));
        const blocked=await raw({kind:'campaign_choose',stage,choice:'location'});assert.equal(blocked.statusCode,422);assert.match(blocked.json().message,/evidence journal/);
        const expected=revision,key='meeting-restore-records-once',body={kind:'campaign_review'};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
        assert.ok(state.campaign.evidence.includes('bag_record'));assert.deepEqual(state.campaign.mastery,{tunde:3,ngozi:3,kc:3});assert.equal(state.campaign.stage,stage);
        assert.equal(state.campaign.evidence.includes('diary'),false);assert.equal(state.campaign.evidence.includes('nneka_account'),false);
        const recovery=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.equal(recovery.character.state.campaign.stage,stage);assert.ok(recovery.character.state.campaign.evidence.includes('bag_record'));
      }
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      const choice=task.id==='disclosure'?scenario.correction:task.id==='custody'?scenario.custody:task.id==='pact'?scenario.pact:task.choices.find(c=>c.correct)!.id;
      if(task.id==='close'){
        const expected=revision,key='meeting-ensemble-completion-once',body={kind:'campaign_choose',stage,choice};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:4,ngozi:4,kc:4});assert.equal(state.campaign.completed.filter((id:string)=>id==='A14').length,1);
    assert.deepEqual([...state.campaign.evidence].sort(),['wedding_clip','bag_record','catering_invoice','original_clip'].sort());assert.equal(JSON.stringify(state.campaign.phone),phone);assert.equal(state.coins,240);
    const status=journalStatus(state.campaign);assert.equal(status.disclosure,scenario.prior==='admit'||scenario.correction==='tell'?journalData.states.disclosure_admitted:journalData.states.disclosure_open);
    assert.equal(status.custody,scenario.custody==='ngozi_record'?journalData.states.custody_ngozi_record:journalData.states.custody_joint_record);
    assert.equal(status.pact,scenario.pact==='protect'?journalData.states.pact_protect:journalData.states.pact_public_case);
    state=await send({kind:'campaign_review'});assert.deepEqual(state.campaign.mastery,{tunde:4,ngozi:4,kc:4});assert.equal(state.campaign.evidence.length,4);
    assert.equal((await raw({kind:'campaign_choose',stage:11,choice:'next'})).statusCode,422);
    for(const lead of ['tunde','ngozi','kc']){state=await send({kind:'campaign_switch',choice:lead});assert.equal(state.campaign.lead,lead);assert.equal(journalAvailable(state.campaign),true);}
    ids.push(guest.character.id);
  }
  return ids;
}
