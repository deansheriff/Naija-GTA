import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {Pool} from 'pg';
import {PostgresStore, type SqlPool, type SqlConnection} from '../src/postgres.js';
import {createApp} from '../src/app.js';
import type {Intent} from '../src/rules.js';
import {neighborContract} from './neighbor-contract.js';
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
    assert.equal((await pool.query('SELECT version FROM schema_versions')).rows.length, 2);
    const neighborId = await neighborContract(app);
    const favorLedger = (await pool.query("SELECT delta FROM ledger WHERE character_id=$1 AND reason='neighbor_lunch_favor'", [neighborId])).rows;
    assert.equal(favorLedger.length, 1); assert.equal(Number(favorLedger[0].delta), 30);
    const legacy = await store.createGuest();
    await pool.query("UPDATE characters SET state=(state - 'neighbors' - 'favor') WHERE id=$1", [legacy.character.id]);
    assert.equal((await store.read(legacy.character.id)).state.favor, 'available');
    assert.equal((await store.read(legacy.character.id)).state.coins, 240);
    await operationsContract(store,app);
    await assert.rejects(pool.query("UPDATE owner_audit SET reason='changed'"),/append-only/);
    const counts=await Promise.all(Array.from({length:12},()=>store.ops.consumeRate('a'.repeat(64),now+60000)));
    assert.deepEqual(counts.map(Number).sort((a,b)=>a-b),Array.from({length:12},(_,i)=>i+1));
  } finally {await app.close();}
});
