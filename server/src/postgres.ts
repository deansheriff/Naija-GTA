import {randomBytes, randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {Pool, type PoolConfig} from 'pg';
import {applyIntent, initialState, upgradeState, RuleError, type Intent} from './rules.js';
import {hash, canonical, lifetime, type Character} from './store.js';
import type {GameStore, Session, Snapshot} from './contract.js';
export interface SqlConnection {query(text: string, values?: unknown[]): Promise<{rows: any[]}>; release?(): void;}
export interface SqlPool extends SqlConnection {connect(): Promise<SqlConnection>; end(): Promise<void>}
export class PostgresStore implements GameStore {
  constructor(readonly pool: SqlPool, private clock: () => number = Date.now) {}
  static async open(config: PoolConfig) {
    const store = new PostgresStore(new Pool({...config, max: 10}));
    await store.migrate(); return store;
  }
  async migrate() {
    const client = await this.pool.connect();
    try {
      await client.query('SELECT pg_advisory_lock(193714209)');
      await client.query('CREATE TABLE IF NOT EXISTS schema_versions(version integer PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
      if (!(await client.query('SELECT version FROM schema_versions WHERE version=1')).rows.length) {
        await client.query('BEGIN');
        try {
          await client.query(await readFile(resolve('migrations/postgres/001_initial.sql'), 'utf8'));
          await client.query('INSERT INTO schema_versions(version) VALUES(1)');
          await client.query('COMMIT');
        } catch (error) {await client.query('ROLLBACK'); throw error;}
      }
    } finally {await client.query('SELECT pg_advisory_unlock(193714209)'); client.release?.();}
  }
  private async transaction<T>(run: (client: SqlConnection) => Promise<T>) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      try {const result = await run(client); await client.query('COMMIT'); return result;}
      catch (error) {await client.query('ROLLBACK'); throw error;}
    } finally {client.release?.();}
  }
  private decode(row: any): Character {return {id: row.id, revision: Number(row.revision), state: upgradeState(row.state)};}
  async createGuest(): Promise<Session> {
    return this.transaction(async client => {
      const now = this.clock(), id = randomUUID(), token = randomBytes(32).toString('base64url'), recoveryCode = randomBytes(32).toString('base64url');
      const state = initialState(now), expiresAt = now + lifetime;
      await client.query('INSERT INTO characters(id,revision,state,save_key_hash) VALUES($1,0,$2,$3)', [id, state, hash(recoveryCode)]);
      await client.query('INSERT INTO sessions VALUES($1,$2,$3)', [hash(token), id, expiresAt]);
      await client.query('INSERT INTO ledger VALUES($1,$2,$3,$4,$5,$6,$7)', [randomUUID(), id, 'initial', 240, 240, 'guest_start', now]);
      return {token, recoveryCode, expiresAt, serverTime: now, character: {id, revision: 0, state}};
    });
  }
  async restore(recoveryCode: string): Promise<Session> {
    const row = (await this.pool.query('SELECT id FROM characters WHERE save_key_hash=$1', [hash(recoveryCode)])).rows[0];
    if (!row) throw new RuleError('invalid_save_code', 'Save access code is invalid.', 401);
    const token = randomBytes(32).toString('base64url'), expiresAt = this.clock() + lifetime;
    await this.pool.query('INSERT INTO sessions VALUES($1,$2,$3)', [hash(token), row.id, expiresAt]);
    return {token, expiresAt, serverTime: this.clock(), character: await this.read(row.id)};
  }
  async authorize(token: string | undefined) {
    if (!token || token.length > 128) throw new RuleError('unauthorized', 'A valid session is required.', 401);
    const row = (await this.pool.query('SELECT character_id,expires_at FROM sessions WHERE token_hash=$1', [hash(token)])).rows[0];
    if (!row || Number(row.expires_at) <= this.clock()) throw new RuleError('unauthorized', 'Session missing or expired.', 401);
    return row.character_id as string;
  }
  async read(id: string) {return this.decode((await this.pool.query('SELECT id,revision,state FROM characters WHERE id=$1', [id])).rows[0]);}
  async execute(id: string, key: string, intent: Intent): Promise<Snapshot> {
    return this.transaction(async client => {
      const character = this.decode((await client.query('SELECT id,revision,state FROM characters WHERE id=$1 FOR UPDATE', [id])).rows[0]);
      const fingerprint = hash(canonical(intent));
      const previous = (await client.query('SELECT request_hash,response FROM commands WHERE character_id=$1 AND command_key=$2', [id, key])).rows[0];
      if (previous) {
        if (previous.request_hash !== fingerprint) throw new RuleError('idempotency_conflict', 'Command key belongs to another request.', 409);
        return previous.response;
      }
      if (character.revision !== intent.revision) throw new RuleError('revision_conflict', 'Progress changed on another device. Refresh and try again.', 409);
      const now = Math.max(this.clock(), character.state.updatedAt);
      const entries = applyIntent(character.state, intent, now);
      character.revision++;
      await client.query('UPDATE characters SET revision=$1,state=$2 WHERE id=$3', [character.revision, character.state, id]);
      let balance = character.state.coins - entries.reduce((sum, entry) => sum + entry.delta, 0);
      for (const entry of entries) {
        balance += entry.delta;
        await client.query('INSERT INTO ledger VALUES($1,$2,$3,$4,$5,$6,$7)', [randomUUID(), id, key, entry.delta, balance, entry.reason, now]);
      }
      const result = {character, serverTime: now};
      await client.query('INSERT INTO commands VALUES($1,$2,$3,$4)', [id, key, fingerprint, result]);
      return result;
    });
  }
  async revoke(token: string) {await this.pool.query('DELETE FROM sessions WHERE token_hash=$1', [hash(token)]);}
  now() {return this.clock();}
  async health() {await this.pool.query('SELECT 1'); return true;}
  async close() {await this.pool.end();}
}
