import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions,type Campaign} from '../src/campaign.js';
import {journalStatus} from '../src/evidence-journal.js';
import {interviewHub} from './chase-contract.js';
export function chaseHub():Campaign{
  const c=interviewHub();return {...c,version:8,mission:'A23',stage:12,lead:'tunde',completed:[...c.completed,'A23'],mastery:{tunde:9,ngozi:6,kc:6},evidence:[...c.evidence,'service_slip'],choices:{...c.choices,'A23-market_turn':'cousin_detour','A23-gap_turn':'loop_rejoin','A23-copy':'redacted_copy'}};
}
export async function infiltrationContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
  const ids:string[]=[];
  for(const consent of ['private_only','redacted_review'])for(const custody of ['ngozi_record','joint_record']){
    advance(60000);const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();const c=chaseHub();c.choices['A14-custody']=custody;await seed(guest.character.id,c);
    const headers={authorization:`Bearer ${guest.token}`};let revision=0,serial=0;
    const raw=(body:object,key=`infiltration-input-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A24');
    const phone=JSON.stringify(state.campaign.phone),portfolio=JSON.stringify(state.campaign.portfolio),decisions=JSON.stringify(journalStatus(state.campaign));
    assert.equal((await raw({kind:'campaign_choose',stage:16,choice:'next'})).statusCode,422);
    assert.equal((await raw({kind:'campaign_choose',stage:0,choice:'invited',evidence:['diary']})).statusCode,400);
    state=await send({kind:'campaign_review'});assert.equal(state.campaign.evidence.length,5);
    for(let stage=0;stage<missions.A24.stages.length;stage++){
      const task=missions.A24.stages[stage];assert.equal(state.campaign.stage,stage);assert.equal(state.campaign.lead,task.lead);
      for(const wrong of task.choices.filter(c=>!c.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      if(task.id==='reference'&&ids.length===0){
        const missing=structuredClone(state.campaign);missing.evidence=missing.evidence.filter((id:string)=>id!=='service_slip');await seed(guest.character.id,missing);
        assert.equal((await raw({kind:'campaign_choose',stage,choice:'compare'})).statusCode,422);
        state=await send({kind:'campaign_review'});assert.ok(state.campaign.evidence.includes('service_slip'));assert.equal(state.campaign.evidence.includes('nneka_account'),false);
      }
      const choice=task.id==='consent'?consent:task.choices[0].id;
      if(task.id==='consent'||task.id==='close'){
        const expected=revision,key=`infiltration-once-${stage}`,body={kind:'campaign_choose',stage,choice};
        const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
      if(task.id==='consent'){
        const held=structuredClone(state.campaign);state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});assert.deepEqual(state.campaign,held);
        const restored=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(restored.character.state.campaign,state.campaign);
      }
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:9,ngozi:8,kc:8});assert.equal(state.coins,240);assert.equal(state.campaign.evidence.filter((id:string)=>id==='nneka_account').length,1);
    for(const unearned of ['diary','diary_lead','witness_consent','note_discrepancy'])assert.equal(state.campaign.evidence.includes(unearned),false);
    assert.equal(state.campaign.choices['A24-consent'],consent);assert.equal(state.campaign.choices['A14-custody'],custody);
    assert.equal(JSON.stringify(state.campaign.phone),phone);assert.equal(JSON.stringify(state.campaign.portfolio),portfolio);assert.equal(JSON.stringify(journalStatus(state.campaign)),decisions);
    assert.equal((await raw({kind:'campaign_choose',stage:16,choice:'next'})).statusCode,422);
    state=await send({kind:'campaign_review'});assert.equal(state.campaign.evidence.length,6);assert.equal(state.campaign.mastery.ngozi,8);ids.push(guest.character.id);
  }
  return ids;
}
