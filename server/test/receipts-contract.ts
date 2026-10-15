import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import {missions,type Campaign} from '../src/campaign.js';
import {journalStatus} from '../src/evidence-journal.js';
import {receiptData,witnessTextHash,hasWitnessConsent} from '../src/receipt-task.js';
import {chaseHub} from './infiltration-contract.js';
export function infiltrationHub(boundary='redacted_review',custody='joint_record'):Campaign{
  const c=chaseHub();return {...c,version:9,mission:'A24',stage:17,lead:'ngozi',completed:[...c.completed,'A24'],mastery:{tunde:9,ngozi:8,kc:8},evidence:[...c.evidence,'nneka_account'],choices:{...c.choices,'A24-consent':boundary,'A14-custody':custody}};
}
export async function receiptsContract(app:FastifyInstance,advance:(ms:number)=>void,seed:(id:string,c:Campaign)=>Promise<void>){
  const ids:string[]=[];
  for(const [boundary,review] of [['private_only','private_records'],['redacted_review','private_records'],['redacted_review','approve_ne1']])for(const custody of ['ngozi_record','joint_record']){
    advance(60000);const guest=(await app.inject({method:'POST',url:'/api/v1/guests',payload:{}})).json();await seed(guest.character.id,infiltrationHub(boundary,custody));
    const headers={authorization:`Bearer ${guest.token}`};let revision=0,serial=0;
    const raw=(body:object,key=`receipts-input-once-${++serial}`,rev=revision)=>app.inject({method:'POST',url:'/api/v1/intents',headers:{...headers,'idempotency-key':key},payload:{revision:rev,...body}});
    const send=async(body:object)=>{const r=await raw(body);assert.equal(r.statusCode,200,r.body);revision++;return r.json().character.state;};
    let state=await send({kind:'campaign_continue'});assert.equal(state.campaign.mission,'A25');assert.equal(state.campaign.receipt.ready,false);
    const phone=JSON.stringify(state.campaign.phone),portfolio=JSON.stringify(state.campaign.portfolio),decisions=JSON.stringify(journalStatus(state.campaign));
    assert.equal((await raw({kind:'campaign_compare',stage:0,choice:'assist'})).statusCode,422);
    for(let stage=0;stage<missions.A25.stages.length;stage++){
      const task=missions.A25.stages[stage];assert.equal(state.campaign.stage,stage);
      if(task.kind==='receipt'){
        assert.equal((await raw({kind:'campaign_choose',stage,choice:'checked'})).statusCode,422);
        assert.equal((await raw({kind:'campaign_compare',stage,choice:'assist',receipt:{ready:true}})).statusCode,400);
        assert.equal((await raw({kind:'campaign_compare',stage,choice:'issue:invented'})).statusCode,422);
        state=await send({kind:'campaign_compare',stage,choice:'account:everything'});state=await send({kind:'campaign_compare',stage,choice:'check'});assert.equal(state.campaign.receipt.ready,false);assert.equal(state.campaign.receipt.attempts,1);
        const held=structuredClone(state.campaign.receipt);state=await send({kind:'campaign_pause'});advance(600000);state=await send({kind:'campaign_resume'});assert.deepEqual(state.campaign.receipt,held);
        const recovered=(await app.inject({method:'POST',url:'/api/v1/sessions',payload:{recoveryCode:guest.recoveryCode}})).json();assert.deepEqual(recovered.character.state.campaign.receipt,held);
        if(ids.length%2)state=await send({kind:'campaign_compare',stage,choice:'assist'});
        else for(const q of receiptData.questions)state=await send({kind:'campaign_compare',stage,choice:q.id+':'+q.options.find(o=>o.correct)!.id});
        assert.equal(state.campaign.receipt.ready,false);
        const expected=revision,key='receipts-check-exact-once',body={kind:'campaign_compare',stage,choice:'check'};const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);
        assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;assert.equal(state.campaign.receipt.ready,true);assert.equal(state.campaign.receipt.attempts,2);
      }
      for(const wrong of task.choices.filter(o=>!o.correct))assert.equal((await raw({kind:'campaign_choose',stage,choice:wrong.id})).statusCode,422);
      if(task.id==='public_review'&&boundary==='private_only')assert.equal((await raw({kind:'campaign_choose',stage,choice:'approve_ne1'})).statusCode,422);
      const choice=task.id==='public_review'?review:task.choices[0].id;
      if(task.id==='close'||task.id==='public_review'){
        const expected=revision,key=`receipts-stage-once-${stage}`,body={kind:'campaign_choose',stage,choice};const pair=await Promise.all([raw(body,key,expected),raw(body,key,expected)]);
        assert.deepEqual(pair.map(r=>r.statusCode),[200,200]);assert.deepEqual(pair[0].json(),pair[1].json());revision++;state=pair[0].json().character.state;
      }else state=await send({kind:'campaign_choose',stage,choice});
      if(task.id==='public_review')assert.equal(hasWitnessConsent(state.campaign),review==='approve_ne1');
    }
    assert.equal(state.campaign.status,'hub');assert.deepEqual(state.campaign.mastery,{tunde:9,ngozi:11,kc:8});assert.equal(state.coins,240);
    for(const id of ['diary','note_discrepancy'])assert.equal(state.campaign.evidence.filter((x:string)=>x===id).length,1);
    assert.equal(state.campaign.evidence.includes('witness_consent'),review==='approve_ne1');assert.equal(state.campaign.choices['A25-public_review'],review);
    if(review==='approve_ne1')assert.deepEqual(state.campaign.witnessConsent,{textHash:witnessTextHash,scope:'redacted_text',active:true});else assert.equal(state.campaign.witnessConsent,null);
    assert.equal(JSON.stringify(state.campaign.phone),phone);assert.equal(JSON.stringify(state.campaign.portfolio),portfolio);assert.equal(JSON.stringify(journalStatus(state.campaign)),decisions);
    assert.equal((await raw({kind:'campaign_choose',stage:12,choice:'next'})).statusCode,422);
    state=await send({kind:'campaign_review'});assert.equal(state.campaign.evidence.length,review==='approve_ne1'?9:8);ids.push(guest.character.id);
  }
  return ids;
}
