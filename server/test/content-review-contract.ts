import assert from 'node:assert/strict';
import type {FastifyInstance} from 'fastify';
import type {GameStore} from '../src/contract.js';
import {fixtureOwner, fixturePassword} from './operations-contract.js';

export async function contentReviewContract(store: GameStore, app: FastifyInstance) {
  assert.equal((await app.inject({url:'/api/owner/content'})).statusCode,401);
  const login=await app.inject({method:'POST',url:'/api/owner/login',remoteAddress:'127.0.0.19',headers:{origin:fixtureOwner.origin},payload:{username:fixtureOwner.username,password:fixturePassword}});
  assert.equal(login.statusCode,200);
  const headers={cookie:String(login.headers['set-cookie']).split(';')[0],origin:fixtureOwner.origin,'x-csrf-token':login.json().csrfToken};
  const queue=async()=>{const reply=await app.inject({url:'/api/owner/content',headers});assert.equal(reply.statusCode,200);return reply.json();};
  const initial=await queue(); assert.equal(initial.units.length,86); assert.equal(initial.counts.total,86);
  const unit=initial.units.find((u:any)=>u.id==='P00-invitation'); assert.equal(unit.status,'pending');
  assert.ok(unit.text.includes('BURGUNDY'));assert.ok(unit.choices.some((text:string)=>text.includes('Retry hint')));
  const body={unitId:unit.id,contentHash:unit.hash,revision:unit.revision,status:'approved',notes:'Reviewed local wording and readable context in this disposable test.'};
  const post=(payload:object,h=headers)=>app.inject({method:'POST',url:'/api/owner/content/review',headers:h,payload});
  assert.equal((await post(body,{...headers,'x-csrf-token':''})).statusCode,403);
  assert.equal((await post(body,{...headers,origin:'https://other.test'})).statusCode,403);
  assert.equal((await post({...body,notes:'    '})).statusCode,400);
  assert.equal((await post({...body,status:'published'})).statusCode,400);
  assert.equal((await post({...body,approved:true})).statusCode,400);
  assert.equal((await post({...body,unitId:'not-a-unit'})).statusCode,404);
  assert.equal((await post({...body,contentHash:'0'.repeat(64)})).statusCode,409);
  const first=await post(body); assert.equal(first.statusCode,200); const firstId=first.json().review.id;
  assert.equal((await post(body)).statusCode,409,'stale exact retries cannot append another review');
  let current=(await queue()).units.find((u:any)=>u.id===unit.id); assert.equal(current.status,'approved'); assert.equal(current.review.actor,fixtureOwner.username);
  const races=await Promise.all([post({...body,revision:firstId,status:'changes_requested',notes:'Please reconsider this line in the next content build.'}),post({...body,revision:firstId,notes:'A second reviewer opened this earlier version.'})]);
  assert.deepEqual(races.map(r=>r.statusCode).sort(),[200,409]);
  const history=await app.inject({url:'/api/owner/content/'+unit.id+'/history',headers});
  assert.equal(history.statusCode,200);assert.equal(history.json().reviews.length,2);assert.ok(history.json().reviews[0].id>firstId);
  current=(await queue()).units.find((u:any)=>u.id===unit.id);
  await store.ops.reviewContent({...body,contentHash:'f'.repeat(64),revision:current.revision,status:'approved'},fixtureOwner.username);
  current=(await queue()).units.find((u:any)=>u.id===unit.id);assert.equal(current.status,'pending');assert.equal(current.changedSinceReview,true,'changed content never inherits old approval');
  const final=await post({...body,revision:current.revision,status:'changes_requested',notes:'<script>not executable</script> Suggested wording for a future build.'});assert.equal(final.statusCode,200);
  assert.equal((await app.inject({url:'/api/owner/content/'+unit.id+'/history?before='+firstId,headers})).statusCode,200);
  const audits=await app.inject({url:'/api/owner/audit',headers});assert.ok(audits.json().events.some((event:any)=>event.action==='content.review'&&event.target===unit.id));
  assert.equal((await app.inject({method:'POST',url:'/api/owner/logout',headers,payload:{}})).statusCode,200);
  return unit.id as string;
}
