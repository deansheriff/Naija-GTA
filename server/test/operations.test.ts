import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {ownerConfig,trustedProxies,makePasswordHash,checkPassword,digest} from '../src/operations.js';
import {fixtureOwner,operationsContract,fixturePassword} from './operations-contract.js';

test('owner HTTP contract, save-code replacement, retained progress and append-only audit',async()=>{
  const store=new Store(':memory:'),app=createApp(store,{owner:fixtureOwner});
  try {await operationsContract(store,app);assert.throws(()=>store.db.exec("UPDATE owner_audit SET reason='changed'"),/append-only/);assert.throws(()=>store.db.exec('DELETE FROM owner_audit'),/append-only/);
    const rows=store.db.prepare('SELECT token_hash FROM owner_sessions').all();assert.ok(rows.every(row=>String(row.token_hash).length===64));
  }finally{await app.close();}
});
test('owner disabled, proxy spoofing rejected, shared rate limits and durable settings',async()=>{
  const directory=mkdtempSync(join(tmpdir(),'nsl-ops-'));const path=join(directory,'ops.sqlite');let now=1700000000000;
  const store=new Store(path,()=>now),other=new Store(path,()=>now);
  const first=createApp(store),second=createApp(other);
  try {
    assert.equal((await first.inject('/api/owner/overview')).statusCode,404);
    for(let i=0;i<10;i++)assert.equal((await (i%2?first:second).inject({method:'POST',url:'/api/v1/guests',headers:{'x-forwarded-for':'203.0.113.'+i},payload:{}})).statusCode,201);
    const rejected=await second.inject({method:'POST',url:'/api/v1/guests',headers:{'x-forwarded-for':'198.51.100.8'},payload:{}});assert.equal(rejected.statusCode,429);assert.ok(rejected.headers['retry-after']);
    now+=60000;assert.equal((await first.inject({method:'POST',url:'/api/v1/guests',payload:{}})).statusCode,201);
    const settings=await store.ops.settings();await store.ops.updateSettings(settings.revision,{...settings,announcement:'A saved update'},'test_owner','Testing durable owner settings');assert.equal((await other.ops.settings()).announcement,'A saved update');
    const count=await store.ops.consumeRate(digest('concurrent'),now+60000);assert.equal(count,1);
    const guest=store.createGuest();store.execute(guest.character.id,'retention-greeting-01',{revision:0,kind:'greet'});
    store.db.prepare('UPDATE commands SET created_at=0 WHERE character_id=?').run(guest.character.id);
    store.execute(guest.character.id,'retention-wall-0001',{revision:1,kind:'decorate',wall:'sage'});
    now+=91*86400000;const pruned=await store.ops.prune();assert.ok(pruned.sessions>0);assert.ok((await store.ops.overview()).characters===12);assert.equal(pruned.commands,1);
    assert.throws(()=>store.execute(guest.character.id,'retention-wall-0001',{revision:1,kind:'decorate',wall:'sage'}),/Refresh/);
    assert.equal(store.db.prepare('SELECT COUNT(*) AS count FROM commands WHERE character_id=?').get(guest.character.id)!.count,1);
    assert.equal(store.read(guest.character.id).state.coins,240);
  }finally{await first.close();await second.close();rmSync(directory,{recursive:true,force:true});}
});
test('owner configuration requires explicit origin and safe proxy addresses',()=>{
  assert.equal(ownerConfig({}),undefined);
  assert.throws(()=>ownerConfig({OWNER_USERNAME:'owner'}));
  assert.throws(()=>ownerConfig({OWNER_USERNAME:'owner',OWNER_PASSWORD_HASH:fixtureOwner.passwordHash,PUBLIC_ORIGIN:'http://game.example',NODE_ENV:'production'}));
  assert.ok(ownerConfig({OWNER_USERNAME:'owner',OWNER_PASSWORD_HASH:fixtureOwner.passwordHash,PUBLIC_ORIGIN:'https://game.example'}));
  assert.throws(()=>trustedProxies({TRUSTED_PROXY_CIDRS:'0.0.0.0/0'}));assert.throws(()=>trustedProxies({TRUSTED_PROXY_CIDRS:'true'}));assert.deepEqual(trustedProxies({TRUSTED_PROXY_CIDRS:'127.0.0.1,172.18.0.2/32'}),['127.0.0.1','172.18.0.2/32']);
  assert.ok(checkPassword(fixturePassword,fixtureOwner.passwordHash));assert.ok(!checkPassword('wrong',fixtureOwner.passwordHash));assert.throws(()=>makePasswordHash('short'));
});

test('owner sessions expire and trusted proxies determine the shared limit identity',async()=>{
  let now=1700000000000;
  const store=new Store(':memory:',()=>now),app=createApp(store,{owner:fixtureOwner,trustedProxies:['127.0.0.1']});
  try {
    const login=await app.inject({method:'POST',url:'/api/owner/login',headers:{origin:fixtureOwner.origin},payload:{username:fixtureOwner.username,password:fixturePassword}});
    const cookie=String(login.headers['set-cookie']).split(';')[0];
    assert.equal((await app.inject({url:'/api/owner/session',headers:{cookie}})).statusCode,200);
    for(let i=0;i<11;i++)assert.equal((await app.inject({method:'POST',url:'/api/v1/guests',headers:{'x-forwarded-for':'203.0.113.'+i},payload:{}})).statusCode,201);
    now+=8*3600000+1;
    assert.equal((await app.inject({url:'/api/owner/session',headers:{cookie}})).statusCode,401);
    assert.equal(await store.ops.ownerSession(digest(cookie.slice(10)),digest('changed credentials')),0);
  }finally{await app.close();}
});
