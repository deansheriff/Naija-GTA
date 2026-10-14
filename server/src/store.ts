import {DatabaseSync} from 'node:sqlite';
import {createHash, randomBytes, randomUUID} from 'node:crypto';
import {applyIntent, initialState, upgradeState, RuleError, type Intent, type State} from './rules.js';
import {allowIntent, defaultSettings, type Operations, type WorldSettings} from './operations.js';
import type {ReviewRecord} from './content-review.js';

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
  readonly ops: Operations;
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
    this.db.exec(`CREATE TABLE IF NOT EXISTS world_settings(id INTEGER PRIMARY KEY CHECK(id=1), value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS owner_sessions(token_hash TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS player_controls(character_id TEXT PRIMARY KEY REFERENCES characters(id), suspended INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS owner_audit(id INTEGER PRIMARY KEY AUTOINCREMENT, actor TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL, reason TEXT NOT NULL, created_at INTEGER NOT NULL);
      CREATE TRIGGER IF NOT EXISTS owner_audit_no_update BEFORE UPDATE ON owner_audit BEGIN SELECT RAISE(ABORT,'owner audit is append-only'); END;
      CREATE TRIGGER IF NOT EXISTS owner_audit_no_delete BEFORE DELETE ON owner_audit BEGIN SELECT RAISE(ABORT,'owner audit is append-only'); END;
      CREATE TABLE IF NOT EXISTS rate_buckets(key TEXT PRIMARY KEY, window_end INTEGER NOT NULL, count INTEGER NOT NULL);`);
    if (!this.db.prepare('PRAGMA table_info(commands)').all().some(column => column.name === 'created_at')) this.db.exec('ALTER TABLE commands ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0');
    this.db.prepare('INSERT OR IGNORE INTO world_settings VALUES(1,?)').run(JSON.stringify(defaultSettings()));
    this.db.exec(`CREATE TABLE IF NOT EXISTS content_reviews(id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id TEXT NOT NULL, content_hash TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('approved','changes_requested','pending')), notes TEXT NOT NULL, actor TEXT NOT NULL, created_at INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS content_reviews_unit ON content_reviews(unit_id,id DESC);
      CREATE TRIGGER IF NOT EXISTS content_review_no_update BEFORE UPDATE ON content_reviews BEGIN SELECT RAISE(ABORT,'content review is append-only'); END;
      CREATE TRIGGER IF NOT EXISTS content_review_no_delete BEFORE DELETE ON content_reviews BEGIN SELECT RAISE(ABORT,'content review is append-only'); END;`);
    const audit = (actor: string, action: string, target: string, reason: string) => {this.db.prepare('INSERT INTO owner_audit(actor,action,target,reason,created_at) VALUES(?,?,?,?,?)').run(actor, action, target, reason, this.clock());};
    this.ops = {
      contentReviews: () => this.db.prepare('SELECT * FROM content_reviews WHERE id IN (SELECT MAX(id) FROM content_reviews GROUP BY unit_id)').all() as unknown as ReviewRecord[],
      contentHistory: (unitId, before) => this.db.prepare('SELECT * FROM content_reviews WHERE unit_id=? AND id<? ORDER BY id DESC LIMIT 31').all(unitId, before) as unknown as ReviewRecord[],
      reviewContent: (value, actor) => this.transaction(() => {
        const latest = Number(this.db.prepare('SELECT MAX(id) AS id FROM content_reviews WHERE unit_id=?').get(value.unitId)?.id ?? 0);
        if (latest !== value.revision) throw new RuleError('review_conflict', 'This review changed. Reload the text and review history first.', 409);
        const row = this.db.prepare('INSERT INTO content_reviews(unit_id,content_hash,status,notes,actor,created_at) VALUES(?,?,?,?,?,?) RETURNING *').get(value.unitId,value.contentHash,value.status,value.notes,actor,this.clock()) as unknown as ReviewRecord;
        audit(actor, 'content.review', value.unitId, value.status + ' / text ' + value.contentHash.slice(0,12));
        return row;
      }),
      settings: () => JSON.parse(this.db.prepare('SELECT value FROM world_settings WHERE id=1').get()!.value as string) as WorldSettings,
      updateSettings: (expected, value, actor, reason) => this.transaction(() => {
        if ((this.ops.settings() as WorldSettings).revision !== expected) throw new RuleError('revision_conflict', 'Settings changed. Reload before publishing.', 409);
        const next = {...value, revision: expected + 1};
        this.db.prepare('UPDATE world_settings SET value=? WHERE id=1').run(JSON.stringify(next));
        audit(actor, 'settings.publish', String(next.revision), reason); return next;
      }),
      audit,
      ownerSession: (token, fingerprint) => Number(this.db.prepare('SELECT expires_at FROM owner_sessions WHERE token_hash=? AND fingerprint=?').get(token, fingerprint)?.expires_at ?? 0),
      openOwnerSession: (token, fingerprint, expires, actor) => this.transaction(() => {
        this.db.prepare('INSERT INTO owner_sessions VALUES(?,?,?)').run(token, fingerprint, expires); audit(actor, 'owner.login', '', 'Password verified');
      }),
      closeOwnerSession: (token, actor) => this.transaction(() => {this.db.prepare('DELETE FROM owner_sessions WHERE token_hash=?').run(token); audit(actor, 'owner.logout', '', 'Owner signed out');}),
      overview: () => Object.fromEntries(['characters','sessions','commands','ledger','owner_audit'].map(table => [table, Number(this.db.prepare(`SELECT COUNT(*) AS count FROM ${table}`).get()!.count)])),
      players: before => this.db.prepare("SELECT id,revision,json_extract(state,'$.name') AS name,json_extract(state,'$.coins') AS coins,COALESCE((SELECT suspended FROM player_controls WHERE character_id=characters.id),0) AS suspended FROM characters WHERE id > ? ORDER BY id LIMIT 31").all(before),
      inspect: id => {
        if (!this.db.prepare('SELECT id FROM characters WHERE id=?').get(id)) throw new RuleError('not_found', 'Character not found.', 404);
        return {character: this.read(id), suspended: Boolean(this.db.prepare('SELECT suspended FROM player_controls WHERE character_id=?').get(id)?.suspended), ledger: this.db.prepare('SELECT delta,balance,reason,created_at FROM ledger WHERE character_id=? ORDER BY created_at DESC,id DESC LIMIT 30').all(id), sessions: Number(this.db.prepare('SELECT COUNT(*) AS count FROM sessions WHERE character_id=? AND expires_at>?').get(id, this.clock())!.count)};
      },
      moderate: (id, action, actor, reason) => this.transaction(() => {
        if (!this.db.prepare('SELECT id FROM characters WHERE id=?').get(id)) throw new RuleError('not_found', 'Character not found.', 404);
        if (action === 'revoke_sessions') this.db.prepare('DELETE FROM sessions WHERE character_id=?').run(id);
        else this.db.prepare('INSERT INTO player_controls VALUES(?,?) ON CONFLICT(character_id) DO UPDATE SET suspended=excluded.suspended').run(id, action === 'suspend' ? 1 : 0);
        audit(actor, 'player.' + action, id, reason);
      }),
      audits: before => this.db.prepare('SELECT * FROM owner_audit WHERE id < ? ORDER BY id DESC LIMIT 31').all(before),
      consumeRate: (key, end) => Number(this.db.prepare('INSERT INTO rate_buckets VALUES(?,?,1) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN rate_buckets.window_end=excluded.window_end THEN rate_buckets.count+1 ELSE 1 END,window_end=excluded.window_end RETURNING count').get(key, end)!.count),
      prune: () => this.transaction(() => {
        const now = this.clock(); const counts: Record<string, number> = {};
        counts.sessions = Number(this.db.prepare('DELETE FROM sessions WHERE expires_at<=?').run(now).changes);
        counts.owner_sessions = Number(this.db.prepare('DELETE FROM owner_sessions WHERE expires_at<=?').run(now).changes);
        counts.rate_buckets = Number(this.db.prepare('DELETE FROM rate_buckets WHERE window_end<=?').run(now).changes);
        counts.commands = Number(this.db.prepare('DELETE FROM commands WHERE rowid IN (SELECT rowid FROM commands WHERE created_at>0 AND created_at<? LIMIT 2000)').run(now - 90 * 86400000).changes);
        audit('system', 'retention.prune', '', JSON.stringify(counts)); return counts;
      })
    };
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
      state.world_seed = (this.ops.settings() as WorldSettings).newCharacterSeed;
      this.db.prepare('INSERT INTO characters(id,revision,state,save_key_hash) VALUES(?,0,?,?)').run(id, JSON.stringify(state), hash(recoveryCode));
      this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hash(token), id, expiresAt);
      this.db.prepare('INSERT INTO ledger VALUES(?,?,?,?,?,?,?)').run(randomUUID(), id, 'initial', 240, 240, 'guest_start', now);
      return {token, recoveryCode, expiresAt, serverTime: now, character: {id, revision: 0, state}};
    });
  }
  restore(recoveryCode: string) {
    const row = this.db.prepare('SELECT id FROM characters WHERE save_key_hash=?').get(hash(recoveryCode)) as {id: string} | undefined;
    if (!row) throw new RuleError('invalid_save_code', 'Save access code is invalid.', 401);
    this.checkAccess(row.id);
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
    this.checkAccess(session.character_id);
    return session.character_id;
  }
  read(id: string): Character {
    const row = this.db.prepare('SELECT * FROM characters WHERE id=?').get(id) as Row;
    return {id: row.id, revision: row.revision, state: upgradeState(JSON.parse(row.state))};
  }
  revoke(token: string) {this.db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token));}
  private checkAccess(id: string) {
    if (this.db.prepare('SELECT suspended FROM player_controls WHERE character_id=?').get(id)?.suspended) throw new RuleError('suspended', 'This save is suspended. Contact the game owner.', 403);
  }
  rotate(id: string, token: string, revision: number) {
    return this.transaction(() => {
      const character = this.read(id);
      this.checkAccess(id);
      if (character.revision !== revision) throw new RuleError('revision_conflict', 'Refresh progress before replacing the access code.', 409);
      const recoveryCode = randomBytes(32).toString('base64url'); character.revision++;
      this.db.prepare('UPDATE characters SET revision=?,save_key_hash=? WHERE id=?').run(character.revision, hash(recoveryCode), id);
      this.db.prepare('DELETE FROM sessions WHERE character_id=? AND token_hash<>?').run(id, hash(token));
      this.ops.audit('player', 'save_code.rotate', id, 'Player replaced access code; other sessions revoked');
      return {character, recoveryCode, serverTime: this.clock()};
    });
  }
  execute(id: string, key: string, intent: Intent) {
    return this.transaction(() => {
      const fingerprint = hash(canonical(intent));
      const previous = this.db.prepare('SELECT request_hash,response FROM commands WHERE character_id=? AND command_key=?').get(id, key) as {request_hash: string; response: string} | undefined;
      if (previous) {
        if (previous.request_hash !== fingerprint) throw new RuleError('idempotency_conflict', 'This command key already belongs to a different request.', 409);
        return JSON.parse(previous.response) as {character: Character};
      }
      const character = this.read(id);
      this.checkAccess(id);
      if (character.revision !== intent.revision) throw new RuleError('revision_conflict', 'Progress changed on another device. Refresh before trying again.', 409);
      const now = Math.max(this.clock(), character.state.updatedAt);
      allowIntent(this.ops.settings() as WorldSettings, intent.kind, intent.choice);
      const entries = applyIntent(character.state, intent, now);
      character.revision++;
      this.db.prepare('UPDATE characters SET revision=?,state=? WHERE id=?').run(character.revision, JSON.stringify(character.state), id);
      let balance = character.state.coins - entries.reduce((sum, entry) => sum + entry.delta, 0);
      for (const entry of entries) {
        balance += entry.delta;
        this.db.prepare('INSERT INTO ledger VALUES(?,?,?,?,?,?,?)').run(randomUUID(), id, key, entry.delta, balance, entry.reason, now);
      }
      const result = {character, serverTime: now};
      this.db.prepare('INSERT INTO commands(character_id,command_key,request_hash,response,created_at) VALUES(?,?,?,?,?)').run(id, key, fingerprint, JSON.stringify(result), now);
      return result;
    });
  }
  close() {this.db.close();}
}
