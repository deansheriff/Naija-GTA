import {DatabaseSync} from 'node:sqlite';
import {createHash, randomBytes, randomUUID} from 'node:crypto';
import {applyIntent, initialState, RuleError, type Intent, type State} from './rules.js';

export type Character = {id: string; revision: number; state: State};
type Row = {id: string; revision: number; state: string};
export const hash = (text: string) => createHash('sha256').update(text).digest('hex');
export const lifetime = 30 * 24 * 60 * 60 * 1000;
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value !== null && typeof value === 'object') return '{' + Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([k,v]) => JSON.stringify(k) + ':' + canonical(v)).join(',') + '}';
  return JSON.stringify(value);
}
export class Store {
  readonly db: DatabaseSync;
  constructor(path: string, private clock: () => number = Date.now) {
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS characters(id TEXT PRIMARY KEY, revision INTEGER NOT NULL CHECK(revision>=0), state TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY, character_id TEXT NOT NULL REFERENCES characters(id), expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS commands(character_id TEXT NOT NULL REFERENCES characters(id), command_key TEXT NOT NULL, request_hash TEXT NOT NULL, response TEXT NOT NULL, PRIMARY KEY(character_id,command_key));
      CREATE TABLE IF NOT EXISTS ledger(id TEXT PRIMARY KEY, character_id TEXT NOT NULL REFERENCES characters(id), command_key TEXT NOT NULL, delta INTEGER NOT NULL, balance INTEGER NOT NULL CHECK(balance>=0), reason TEXT NOT NULL, created_at INTEGER NOT NULL);
      CREATE TRIGGER IF NOT EXISTS ledger_no_update BEFORE UPDATE ON ledger BEGIN SELECT RAISE(ABORT,'ledger is append-only'); END;
      CREATE TRIGGER IF NOT EXISTS ledger_no_delete BEFORE DELETE ON ledger BEGIN SELECT RAISE(ABORT,'ledger is append-only'); END;`);
    const columns = this.db.prepare('PRAGMA table_info(characters)').all();
    if (!columns.some(column => column.name === 'save_key_hash')) this.db.exec('ALTER TABLE characters ADD COLUMN save_key_hash TEXT');
    this.db.exec('CREATE UNIQUE INDEX IF NOT EXISTS character_save_key ON characters(save_key_hash)');
  }
  private transaction<T>(run: () => T): T {
    this.db.exec('BEGIN IMMEDIATE');
    try {const result = run(); this.db.exec('COMMIT'); return result;}
    catch (error) {this.db.exec('ROLLBACK'); throw error;}
  }
  createGuest() {
    return this.transaction(() => {
      const now = this.clock(), id = randomUUID(), token = randomBytes(32).toString('base64url'), recoveryCode = randomBytes(32).toString('base64url');
      const state = initialState(now), expiresAt = now + lifetime;
      this.db.prepare('INSERT INTO characters(id,revision,state,save_key_hash) VALUES(?,0,?,?)').run(id, JSON.stringify(state), hash(recoveryCode));
      this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hash(token), id, expiresAt);
      this.db.prepare('INSERT INTO ledger VALUES(?,?,?,?,?,?,?)').run(randomUUID(), id, 'initial', 240, 240, 'guest_start', now);
      return {token, recoveryCode, expiresAt, serverTime: now, character: {id, revision: 0, state}};
    });
  }
  restore(recoveryCode: string) {
    const row = this.db.prepare('SELECT id FROM characters WHERE save_key_hash=?').get(hash(recoveryCode)) as {id: string} | undefined;
    if (!row) throw new RuleError('invalid_save_code', 'Save access code is invalid.', 401);
    const token = randomBytes(32).toString('base64url'), expiresAt = this.clock() + lifetime;
    this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hash(token), row.id, expiresAt);
    return {token, expiresAt, serverTime: this.clock(), character: this.read(row.id)};
  }
  now() {return this.clock();}
  health() {return true;}
  authorize(token: string | undefined): string {
    if (!token || token.length > 128) throw new RuleError('unauthorized', 'A valid guest session is required.', 401);
    const session = this.db.prepare('SELECT character_id,expires_at FROM sessions WHERE token_hash=?').get(hash(token)) as {character_id: string; expires_at: number} | undefined;
    if (!session || session.expires_at <= this.clock()) throw new RuleError('unauthorized', 'Session missing or expired.', 401);
    return session.character_id;
  }
  read(id: string): Character {
    const row = this.db.prepare('SELECT * FROM characters WHERE id=?').get(id) as Row;
    return {id: row.id, revision: row.revision, state: JSON.parse(row.state)};
  }
  revoke(token: string) {this.db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token));}
  execute(id: string, key: string, intent: Intent) {
    return this.transaction(() => {
      const fingerprint = hash(canonical(intent));
      const previous = this.db.prepare('SELECT request_hash,response FROM commands WHERE character_id=? AND command_key=?').get(id, key) as {request_hash: string; response: string} | undefined;
      if (previous) {
        if (previous.request_hash !== fingerprint) throw new RuleError('idempotency_conflict', 'This command key already belongs to a different request.', 409);
        return JSON.parse(previous.response) as {character: Character};
      }
      const character = this.read(id);
      if (character.revision !== intent.revision) throw new RuleError('revision_conflict', 'Progress changed on another device. Refresh before trying again.', 409);
      const now = Math.max(this.clock(), character.state.updatedAt);
      const entries = applyIntent(character.state, intent, now);
      character.revision++;
      this.db.prepare('UPDATE characters SET revision=?,state=? WHERE id=?').run(character.revision, JSON.stringify(character.state), id);
      let balance = character.state.coins - entries.reduce((sum, entry) => sum + entry.delta, 0);
      for (const entry of entries) {
        balance += entry.delta;
        this.db.prepare('INSERT INTO ledger VALUES(?,?,?,?,?,?,?)').run(randomUUID(), id, key, entry.delta, balance, entry.reason, now);
      }
      const result = {character, serverTime: now};
      this.db.prepare('INSERT INTO commands VALUES(?,?,?,?)').run(id, key, fingerprint, JSON.stringify(result));
      return result;
    });
  }
  close() {this.db.close();}
}
