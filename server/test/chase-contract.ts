import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {freshCampaign,missions,type Campaign} from '../src/campaign.js';
import {freshPhone} from '../src/phone-task.js';
import {freshPortfolio,advancePortfolio} from '../src/portfolio-task.js';
import {journalStatus} from '../src/evidence-journal.js';
export function interviewHub():Campaign{
  const portfolio=freshPortfolio();advancePortfolio(portfolio,'present');advancePortfolio(portfolio,'callback');advancePortfolio(portfolio,'assist');advancePortfolio(portfolio,'present');
  return {...freshCampaign(),version:7,mission:'A22',status:'hub',stage:12,lead:'kc',paused:false,completed:['P00','A11','A12','A13','A14','A21','A22'],mastery:{tunde:6,ngozi:6,kc:6},evidence:['wedding_clip','bag_record','catering_invoice','original_clip'],choices:{'A14-pact':'protect','A14-custody':'joint_record','A13-disclose':'defer','A22-piece':'practice_piece','A22-opportunity':'ask_time'},phone:{...freshPhone(),battery:0,takes:4},portfolio};
}
export async function chaseContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
  const ids:string[]=[];
  for(const first of ['left_marked','cousin_detour'])for(const second of ['canal_right','loop_rejoin'])for(const copy of ['private_copy','redacted_copy']){
    advance(60000);
    const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();await seed(guest.character.id,interviewHub());
    const headers={authorization:`Bearer ${guest.token}`};let revision=0,serial=0;
    const raw=(body:object,key=`chase-command-input-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A23');
    const phone=JSON.stringify(state.campaign.phone),portfolio=JSON.stringify(state.campaign.portfolio),decisions=JSON.stringify(journalStatus(state.campaign));
    assert.equal((await raw({kind:'campaign_drive',stage:0,choice:'yield'})).statusCode,422);
    for(let stage=0;stage<missions.A23.stages.length;stage++){
      const task=missions.A23.stages[stage];assert.equal(state.campaign.stage,stage);
      if(task.kind==='drive'){
        const command={kind:'campaign_drive',stage};
        assert.equal((await raw({kind:'campaign_choose',stage,choice:task.choices[0].id})).statusCode,422);
        assert.equal((await raw({...command,choice:'yield',gateCleared:true})).statusCode,400);
        state=await send({...command,choice:'yield'});assert.equal(state.campaign.drive.gateCleared,false);
        if(ids.length===0){
          for(let i=0;i<4;i++){advance(1000);state=await send({...command,choice:'accelerate'});}
          assert.equal(state.campaign.drive.misses,1);assert.equal(state.campaign.drive.distance,0);assert.equal(state.coins,240);
        }
        for(let i=0;i<4;i++){advance(1000);state=await send({...command,choice:'assist'});}
        assert.equal(state.campaign.drive.distance,task.driveGate!.at);assert.equal(state.campaign.drive.speed,0);assert.equal(state.campaign.drive.ready,false);assert.equal(state.campaign.drive.gateCleared,false);
        const held=structuredClone(state.campaign.drive);state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});
        assert.deepEqual({...state.campaign.drive,lastAt:0},{...held,lastAt:0});
        const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(recovered.character.state.campaign.drive,state.campaign.drive);
        assert.equal((await raw({kind:'campaign_choose',stage,choice:task.choices[0].id})).statusCode,422);
        const expected=revision,key=`chase-wait-once-${stage}`,body={...command,choice:'yield'};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
        assert.equal(state.campaign.drive.gateCleared,true);assert.equal(state.campaign.drive.ready,false);assert.equal(state.campaign.drive.distance,task.driveGate!.at);
        for(let i=0;i<4;i++){advance(1000);state=await send({...command,choice:'assist'});}
        assert.equal(state.campaign.drive.ready,true);
      }
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      const choice=task.id==='market_turn'?first:task.id==='gap_turn'?second:task.id==='copy'?copy:task.choices[0].id;
      if(task.id==='close'){
        const expected=revision,key='chase-complete-once',body={kind:'campaign_choose',stage,choice};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:9,ngozi:6,kc:6});assert.equal(state.coins,240);assert.equal(state.campaign.completed.filter((id:string)=>id==='A23').length,1);
    assert.deepEqual(state.campaign.evidence,['wedding_clip','bag_record','catering_invoice','original_clip','service_slip']);
    assert.equal(JSON.stringify(state.campaign.phone),phone);assert.equal(JSON.stringify(state.campaign.portfolio),portfolio);assert.equal(JSON.stringify(journalStatus(state.campaign)),decisions);
    assert.equal(state.campaign.choices['A23-market_turn'],first);assert.equal(state.campaign.choices['A23-gap_turn'],second);assert.equal(state.campaign.choices['A23-copy'],copy);
    assert.equal((await raw({kind:'campaign_choose',stage:11,choice:'next'})).statusCode,422);
    state=await send({kind:'campaign_review'});assert.equal(state.campaign.evidence.length,5);assert.equal(state.campaign.mastery.tunde,9);ids.push(guest.character.id);
  }
  return ids;
}
