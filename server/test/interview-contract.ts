import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {freshCampaign,missions,type Campaign} from '../src/campaign.js';
import {freshPhone} from '../src/phone-task.js';
import {journalData,journalStatus} from '../src/evidence-journal.js';
export function generatorHub():Campaign{return {...freshCampaign(),version:6,mission:'A21',status:'hub',stage:13,lead:'tunde',paused:false,completed:['P00','A11','A12','A13','A14','A21'],mastery:{tunde:6,ngozi:6,kc:4},evidence:['wedding_clip','bag_record','catering_invoice','original_clip'],choices:{'A14-pact':'protect','A14-custody':'joint_record','A13-disclose':'defer','A21-hours':'two_first'},phone:{...freshPhone(),battery:0,takes:4},portfolio:null};}
export async function interviewContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
  const ids:string[]=[];let caseIndex=0;
  for(const route of ['first','practice','callback'])for(const piece of ['original_excerpt','practice_piece']){
    advance(60000);const index=caseIndex++;
    const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();let revision=0,serial=0;
    const headers={authorization:`Bearer ${guest.token}`};
    const raw=(body:object,key=`interview-command-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state:any;
    if(index===0){
      state=await send({kind:'campaign_start'});
      for(const id of ['P00','A11','A12','A13','A14','A21']){
        for(let stage=0;stage<missions[id].stages.length;stage++){
          const task=missions[id].stages[stage];
          if(task.kind==='drive')for(let i=0;i<7;i++){advance(1000);await send({kind:'campaign_drive',stage,choice:'assist'});}
          if(task.kind==='frame')await send({kind:'campaign_phone',stage,choice:'assist'});
          state=await send({kind:'campaign_choose',stage,choice:task.choices.find(c=>c.correct)!.id});
        }
        advance(60000);state=await send({kind:'campaign_continue'});
      }
    }else{
      const c=generatorHub();if(index%2)c.choices['A14-pact']='public_case';await seed(guest.character.id,c);state=await send({kind:'campaign_continue'});
    }
    assert.equal(state.campaign.mission,'A22');assert.deepEqual(state.campaign.mastery,{tunde:6,ngozi:6,kc:4});
    const evidence=JSON.stringify(state.campaign.evidence),phone=JSON.stringify(state.campaign.phone),meeting=JSON.stringify(journalStatus(state.campaign));
    assert.equal((await raw({kind:'campaign_portfolio',stage:0,choice:'assist'})).statusCode,422);
    assert.equal((await raw({kind:'campaign_choose',stage:9,choice:'keep_open'})).statusCode,422);
    for(let stage=0;stage<missions.A22.stages.length;stage++){
      const task=missions.A22.stages[stage];assert.equal(state.campaign.stage,stage);
      if(task.kind==='portfolio'){
        assert.equal((await raw({kind:'campaign_choose',stage,choice:'ready'})).statusCode,422);
        assert.equal((await raw({kind:'campaign_portfolio',stage,choice:'assist',portfolio:{ready:true}})).statusCode,400);
        assert.equal((await raw({kind:'campaign_portfolio',stage,choice:'role:invented'})).statusCode,422);
        if(route!=='first'){
          state=await send({kind:'campaign_portfolio',stage,choice:'role:everything'});
          state=await send({kind:'campaign_portfolio',stage,choice:'present'});assert.equal(state.campaign.portfolio.needsRecovery,true);assert.equal(state.campaign.portfolio.ready,false);
          const held=structuredClone(state.campaign.portfolio);state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});assert.deepEqual(state.campaign.portfolio,held);
          const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(recovered.character.state.campaign.portfolio,held);
          state=await send({kind:'campaign_portfolio',stage,choice:'assist'});assert.deepEqual(state.campaign.portfolio.answers,held.answers);assert.equal(state.campaign.portfolio.attempts,1);
          state=await send({kind:'campaign_portfolio',stage,choice:route});assert.equal(state.campaign.portfolio.route,route);assert.equal(state.campaign.portfolio.needsRecovery,false);
        }
        if(index%2)state=await send({kind:'campaign_portfolio',stage,choice:'assist'});
        else for(const choice of ['role:team','source:original','context:limits'])state=await send({kind:'campaign_portfolio',stage,choice});
        assert.equal(state.campaign.portfolio.ready,false);
        const expected=revision,key='interview-check-answers-once',body={kind:'campaign_portfolio',stage,choice:'present'};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
        assert.equal(state.campaign.portfolio.ready,true);assert.equal(state.campaign.portfolio.attempts,route==='first'?1:2);assert.equal(state.campaign.portfolio.route,route);
        state=await send({kind:'campaign_portfolio',stage,choice:'present'});assert.equal(state.campaign.portfolio.attempts,route==='first'?1:2);
      }
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      const choice=task.id==='piece'?piece:task.id==='opportunity'&&index%2?'ask_time':task.choices.find(c=>c.correct)!.id;
      if(task.id==='close'){
        const expected=revision,key='interview-complete-exactly-once',body={kind:'campaign_choose',stage,choice};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:6,ngozi:6,kc:6});assert.equal(state.coins,240);
    assert.equal(JSON.stringify(state.campaign.evidence),evidence);assert.equal(JSON.stringify(state.campaign.phone),phone);assert.equal(JSON.stringify(journalStatus(state.campaign)),meeting);
    assert.equal(state.campaign.choices['A22-piece'],piece);assert.ok(['keep_open','ask_time'].includes(state.campaign.choices['A22-opportunity']));assert.equal(state.campaign.portfolio.route,route);
    assert.ok(journalData.notes.some(n=>n.mission==='A22'&&state.campaign.completed.includes(n.mission)));assert.equal(state.campaign.evidence.includes('open_window'),false);
    assert.equal((await raw({kind:'campaign_choose',stage:11,choice:'next'})).statusCode,422);
    state=await send({kind:'campaign_review'});assert.equal(state.campaign.mastery.kc,6);assert.equal(state.campaign.evidence.length,4);ids.push(guest.character.id);
  }
  return ids;
}
