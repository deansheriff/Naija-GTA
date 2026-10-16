import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {Pool} from 'pg';
import {PostgresStore, type SqlPool, type SqlConnection} from '../src/postgres.js';
import {createApp} from '../src/app.js';
import type {Intent} from '../src/rules.js';
import {neighborContract} from './neighbor-contract.js';
import {careerContract} from './career-contract.js';
import {errandContract} from './errand-contract.js';
import {radioContract} from './radio-contract.js';
import {campaignContract} from './campaign-contract.js';
import {contentReviewContract} from './content-review-contract.js';
import {tundeContract} from './tunde-contract.js';
import {ngoziContract} from './ngozi-contract.js';
import {kcContract} from './kc-contract.js';
import {meetingContract} from './meeting-contract.js';
import {generatorContract} from './generator-contract.js';
import {interviewContract} from './interview-contract.js';
import {chaseContract} from './chase-contract.js';
import {infiltrationContract} from './infiltration-contract.js';
import {receiptsContract} from './receipts-contract.js';
import {queueContract} from './queue-contract.js';
import {operationsContract,fixtureOwner} from './operations-contract.js';

// Embedded PostgreSQL validates real SQL locally. CI uses a multi-connection PostgreSQL service.
async function embeddedPool(): Promise<SqlPool> {
  const db = new PGlite();
  let tail = Promise.resolve();
  const connect = async (): Promise<SqlConnection> => {
    const previous = tail;
    let release!: () => void;
    tail = new Promise<void>(resolve => {release = resolve;});
    await previous;
    return {
      release,
      query: async (text, values) => {
        if (!values?.length && text.includes(';')) {
          const results = await db.exec(text);
          return results[results.length - 1] ?? {rows: []};
        }
        return db.query(text, values);
      }
    };
  };
  return {connect, end: () => db.close(), query: async (text, values) => {
    const client = await connect();
    try {return await client.query(text, values);} finally {client.release!();}
  }};
}

test('PostgreSQL adapter: migration, cloud recovery, row conflicts, receipts, ledger and drafts', async () => {
  let now = 1700000000000;
  const pool = process.env.TEST_DATABASE_URL ? new Pool({connectionString: process.env.TEST_DATABASE_URL}) : await embeddedPool();
  const store = new PostgresStore(pool, () => now);
  await store.migrate(); await store.migrate();
  const app = createApp(store,{owner:fixtureOwner});
  try {
    const guest = (await app.inject({method: 'POST', url: '/api/v1/guests', payload: {}})).json();
    assert.ok(guest.recoveryCode?.length >= 40);
    const auth = {authorization: `Bearer ${guest.token}`};
    const command = (key: string, payload: Intent | object) => app.inject({method: 'POST', url: '/api/v1/intents', headers: {...auth, 'idempotency-key': key}, payload});
    assert.equal((await command('forge-balance-0001', {kind: 'sync', revision: 0, coins: 99999})).statusCode, 400);
    const races = await Promise.all(['concurrent-greet-1','concurrent-greet-2'].map(key => command(key, {kind: 'greet', revision: 0})));
    assert.deepEqual(races.map(reply => reply.statusCode).sort(), [200,409]);
    await command('start-practice-001', {kind: 'begin', action: 'learn', revision: 1});
    now += 8000;
    await command('finish-practice-01', {kind: 'sync', revision: 2});
    await command('start-paid-gig-001', {kind: 'begin', action: 'gig', revision: 3});
    // A saved pre-0.11 activity must still settle under its original timer.
    await pool.query("UPDATE characters SET state=state #- '{active,puzzle}' WHERE id=$1", [guest.character.id]);
    now += 10000;
    const paidPayload = {kind: 'sync', revision: 4} as const;
    const payments = await Promise.all([command('finish-paid-gig-01', paidPayload), command('finish-paid-gig-01', paidPayload)]);
    assert.equal(payments[0].statusCode, 200); assert.equal(payments[1].statusCode, 200);
    assert.deepEqual(payments[0].json(), payments[1].json());
    assert.equal(payments[0].json().character.state.coins, 330);
    assert.equal((await command('finish-paid-gig-01', {kind: 'greet', revision: 4})).statusCode, 409);
    const posted = await command('private-draft-001', {kind: 'post', title: 'Fix a kitchen radio', budget: 30, revision: 5});
    assert.equal(posted.json().character.state.coins, 200);
    const cancelled = await command('cancel-draft-0001', {kind: 'cancel', jobId: '1', revision: 6});
    assert.equal(cancelled.json().character.state.coins, 230);
    assert.equal((await command('repeat-refund-001', {kind: 'cancel', jobId: '1', revision: 7})).statusCode, 422);
    assert.equal((await store.read(guest.character.id)).revision, 7);
    const ledger = (await pool.query('SELECT delta,balance FROM ledger WHERE character_id=$1 ORDER BY created_at,id', [guest.character.id])).rows;
    assert.equal(ledger.reduce((sum, row) => sum + Number(row.delta), 0), 230);
    assert.equal(ledger.filter(row => row.delta === '90' || row.delta === 90).length, 1);
    await assert.rejects(pool.query('UPDATE ledger SET delta=100 WHERE character_id=$1', [guest.character.id]), /append-only/);
    await app.inject({method: 'DELETE', url: '/api/v1/session', headers: auth});
    assert.equal((await app.inject({url: '/api/v1/me', headers: auth})).statusCode, 401);
    const restored = (await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: guest.recoveryCode}})).json();
    assert.equal(restored.character.id, guest.character.id);
    assert.equal(restored.character.state.coins, 230);
    assert.notEqual(restored.token, guest.token);
    assert.equal((await app.inject({method: 'POST', url: '/api/v1/sessions', payload: {recoveryCode: 'x'.repeat(43)}})).statusCode, 401);
    assert.equal((await pool.query('SELECT version FROM schema_versions')).rows.length, 3);
    const neighborId = await neighborContract(app);
    const favorLedger = (await pool.query("SELECT delta FROM ledger WHERE character_id=$1 AND reason='neighbor_lunch_favor'", [neighborId])).rows;
    assert.equal(favorLedger.length, 1); assert.equal(Number(favorLedger[0].delta), 30);
    const legacy = await store.createGuest();
    await pool.query("UPDATE characters SET state=(state - 'neighbors' - 'favor') WHERE id=$1", [legacy.character.id]);
    assert.equal((await store.read(legacy.character.id)).state.favor, 'available');
    assert.equal((await store.read(legacy.character.id)).state.coins, 240);
    const careerId = await careerContract(app, ms => {now += ms;});
    assert.equal(Number((await pool.query('SELECT SUM(delta) AS total FROM ledger WHERE character_id=$1', [careerId])).rows[0].total), 210);
    await pool.query("UPDATE characters SET state=(state - 'career' - 'inventory') WHERE id=$1", [legacy.character.id]);
    assert.deepEqual((await store.read(legacy.character.id)).state.career, {completed: 0, readyAt: 0});
    assert.deepEqual((await store.read(legacy.character.id)).state.inventory, {owned: [], equipped: []});
    const errandIds = await errandContract(app, ms => {now += ms;});
    for (const id of errandIds) {
      const entries = (await pool.query("SELECT delta FROM ledger WHERE character_id=$1 AND reason='square_lantern_errand'", [id])).rows;
      assert.equal(entries.length, 1); assert.equal(Number(entries[0].delta), 40);
    }
    await pool.query("UPDATE characters SET state=(state - 'errand') WHERE id=$1", [legacy.character.id]);
    assert.deepEqual((await store.read(legacy.character.id)).state.errand, {stage: 'available', spot: ''});
    now += 60000;
    const radioIds = await radioContract(app, ms => {now += ms;});
    for (const id of radioIds) assert.equal((await pool.query("SELECT delta FROM ledger WHERE character_id=$1 AND reason='starter_gig'", [id])).rows.length, 1);
    now += 60000;
    const campaignId = await campaignContract(app, ms => {now += ms;});
    assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1', [campaignId])).rows[0].total), 1);
    await operationsContract(store,app);
    now += 60000;
    await contentReviewContract(store,app);
    now += 60000;
    const tundeId=await tundeContract(app,ms=>{now+=ms;});
    assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[tundeId])).rows[0].total),1);
    const ngoziIds=await ngoziContract(app,ms=>{now+=ms;});
    for(const id of ngoziIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const kcIds=await kcContract(app,ms=>{now+=ms;});
    for(const id of kcIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const meetingIds=await meetingContract(app,ms=>{now+=ms;},async(id,evidence)=>{await pool.query("UPDATE characters SET state=jsonb_set(state,'{campaign,evidence}',$2::jsonb) WHERE id=$1",[id,JSON.stringify(evidence)]);});
    for(const id of meetingIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const generatorIds=await generatorContract(app,ms=>{now+=ms;});
    for(const id of generatorIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const interviewIds=await interviewContract(app,ms=>{now+=ms;},async(id,c)=>{await pool.query("UPDATE characters SET state=jsonb_set(state,'{campaign}',$2::jsonb) WHERE id=$1",[id,JSON.stringify(c)]);});
    for(const id of interviewIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const chaseIds=await chaseContract(app,ms=>{now+=ms;},async(id,c)=>{await pool.query("UPDATE characters SET state=jsonb_set(state,'{campaign}',$2::jsonb) WHERE id=$1",[id,JSON.stringify(c)]);});
    for(const id of chaseIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const infiltrationIds=await infiltrationContract(app,ms=>{now+=ms;},async(id,c)=>{await pool.query("UPDATE characters SET state=jsonb_set(state,'{campaign}',$2::jsonb) WHERE id=$1",[id,JSON.stringify(c)]);});
    for(const id of infiltrationIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const receiptsIds=await receiptsContract(app,ms=>{now+=ms;},async(id,c)=>{await pool.query("UPDATE characters SET state=jsonb_set(state,'{campaign}',$2::jsonb) WHERE id=$1",[id,JSON.stringify(c)]);});
    for(const id of receiptsIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    const queueIds=await queueContract(app,ms=>{now+=ms;},async(id,c)=>{await pool.query("UPDATE characters SET state=jsonb_set(state,'{campaign}',$2::jsonb) WHERE id=$1",[id,JSON.stringify(c)]);});
    for(const id of queueIds)assert.equal(Number((await pool.query('SELECT COUNT(*) AS total FROM ledger WHERE character_id=$1',[id])).rows[0].total),1);
    await assert.rejects(pool.query("UPDATE content_reviews SET notes='changed'"),/append-only/);
    await assert.rejects(pool.query("UPDATE owner_audit SET reason='changed'"),/append-only/);
    const counts=await Promise.all(Array.from({length:12},()=>store.ops.consumeRate('a'.repeat(64),now+60000)));
    assert.deepEqual(counts.map(Number).sort((a,b)=>a-b),Array.from({length:12},(_,i)=>i+1));
  } finally {await app.close();}
});
