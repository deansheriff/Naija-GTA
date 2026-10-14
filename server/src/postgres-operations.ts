import type {SqlPool, SqlConnection} from './postgres.js';
import {RuleError, upgradeState} from './rules.js';
import type {Operations, WorldSettings} from './operations.js';
import type {ReviewRecord} from './content-review.js';
export function postgresOperations(pool: SqlPool, transaction: <T>(run: (client: SqlConnection) => Promise<T>) => Promise<T>, clock: () => number): Operations {
  const audit = async (client: SqlConnection, actor: string, action: string, target: string, reason: string) => {await client.query('INSERT INTO owner_audit(actor,action,target,reason,created_at) VALUES($1,$2,$3,$4,$5)', [actor, action, target, reason, clock()]);};
  return {
    contentReviews: async () => (await pool.query('SELECT * FROM content_reviews WHERE id IN (SELECT MAX(id) FROM content_reviews GROUP BY unit_id)')).rows.map(row => ({...row,id:Number(row.id),created_at:Number(row.created_at)})) as ReviewRecord[],
    contentHistory: async (unitId, before) => (await pool.query('SELECT * FROM content_reviews WHERE unit_id=$1 AND id<$2 ORDER BY id DESC LIMIT 31', [unitId,before])).rows.map(row => ({...row,id:Number(row.id),created_at:Number(row.created_at)})) as ReviewRecord[],
    reviewContent: (value, actor) => transaction(async client => {
      await client.query('SELECT pg_advisory_xact_lock(193714211,hashtext($1))', [value.unitId]);
      const latest = Number((await client.query('SELECT MAX(id) AS id FROM content_reviews WHERE unit_id=$1', [value.unitId])).rows[0].id ?? 0);
      if (latest !== value.revision) throw new RuleError('review_conflict', 'This review changed. Reload the text and review history first.', 409);
      const row = (await client.query('INSERT INTO content_reviews(unit_id,content_hash,status,notes,actor,created_at) VALUES($1,$2,$3,$4,$5,$6) RETURNING *', [value.unitId,value.contentHash,value.status,value.notes,actor,clock()])).rows[0];
      await audit(client, actor, 'content.review', value.unitId, value.status + ' / text ' + value.contentHash.slice(0,12));
      return {...row,id:Number(row.id),created_at:Number(row.created_at)} as ReviewRecord;
    }),
    settings: async () => (await pool.query('SELECT value FROM world_settings WHERE id=1')).rows[0].value,
    updateSettings: (expected, value, actor, reason) => transaction(async client => {
      const current = (await client.query('SELECT value FROM world_settings WHERE id=1 FOR UPDATE')).rows[0].value as WorldSettings;
      if (current.revision !== expected) throw new RuleError('revision_conflict', 'Settings changed. Reload before publishing.', 409);
      const next = {...value, revision: expected + 1};
      await client.query('UPDATE world_settings SET value=$1 WHERE id=1', [next]);
      await audit(client, actor, 'settings.publish', String(next.revision), reason); return next;
    }),
    audit: (actor, action, target, reason) => audit(pool, actor, action, target, reason),
    ownerSession: async (token, fingerprint) => Number((await pool.query('SELECT expires_at FROM owner_sessions WHERE token_hash=$1 AND fingerprint=$2', [token, fingerprint])).rows[0]?.expires_at ?? 0),
    openOwnerSession: (token, fingerprint, expires, actor) => transaction(async client => {await client.query('INSERT INTO owner_sessions VALUES($1,$2,$3)', [token, fingerprint, expires]); await audit(client, actor, 'owner.login', '', 'Password verified');}),
    closeOwnerSession: (token, actor) => transaction(async client => {await client.query('DELETE FROM owner_sessions WHERE token_hash=$1', [token]); await audit(client, actor, 'owner.logout', '', 'Owner signed out');}),
    overview: async () => {
      const counts: Record<string, number> = {};
      for (const table of ['characters','sessions','commands','ledger','owner_audit']) counts[table] = Number((await pool.query(`SELECT COUNT(*) AS count FROM ${table}`)).rows[0].count);
      return counts;
    },
    players: async before => (await pool.query("SELECT id,revision,state->>'name' AS name,state->>'coins' AS coins,COALESCE((SELECT suspended FROM player_controls WHERE character_id=characters.id),false) AS suspended FROM characters WHERE id::text > $1 ORDER BY id LIMIT 31", [before])).rows,
    inspect: id => transaction(async client => {
      const row = (await client.query('SELECT id,revision,state FROM characters WHERE id=$1 FOR SHARE', [id])).rows[0];
      if (!row) throw new RuleError('not_found', 'Character not found.', 404);
      return {character: {id: row.id, revision: Number(row.revision), state: upgradeState(row.state)}, suspended: Boolean((await client.query('SELECT suspended FROM player_controls WHERE character_id=$1', [id])).rows[0]?.suspended), ledger: (await client.query('SELECT delta,balance,reason,created_at FROM ledger WHERE character_id=$1 ORDER BY created_at DESC,id DESC LIMIT 30', [id])).rows, sessions: Number((await client.query('SELECT COUNT(*) AS count FROM sessions WHERE character_id=$1 AND expires_at>$2', [id, clock()])).rows[0].count)};
    }),
    moderate: (id, action, actor, reason) => transaction(async client => {
      if (!(await client.query('SELECT id FROM characters WHERE id=$1 FOR UPDATE', [id])).rows.length) throw new RuleError('not_found', 'Character not found.', 404);
      if (action === 'revoke_sessions') await client.query('DELETE FROM sessions WHERE character_id=$1', [id]);
      else await client.query('INSERT INTO player_controls VALUES($1,$2) ON CONFLICT(character_id) DO UPDATE SET suspended=excluded.suspended', [id, action === 'suspend']);
      await audit(client, actor, 'player.' + action, id, reason);
    }),
    audits: async before => (await pool.query('SELECT * FROM owner_audit WHERE id<$1 ORDER BY id DESC LIMIT 31', [before])).rows,
    consumeRate: async (key, end) => Number((await pool.query('INSERT INTO rate_buckets VALUES($1,$2,1) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN rate_buckets.window_end=excluded.window_end THEN rate_buckets.count+1 ELSE 1 END,window_end=excluded.window_end RETURNING count', [key, end])).rows[0].count),
    prune: () => transaction(async client => {
      const now = clock(); const counts: Record<string, number> = {};
      for (const table of ['sessions', 'owner_sessions', 'rate_buckets']) {
        const column = table === 'rate_buckets' ? 'window_end' : 'expires_at';
        counts[table] = (await client.query(`DELETE FROM ${table} WHERE ${column}<=$1 RETURNING ${column}`, [now])).rows.length;
      }
      counts.commands = (await client.query('DELETE FROM commands WHERE (character_id,command_key) IN (SELECT character_id,command_key FROM commands WHERE created_at>0 AND created_at<$1 LIMIT 2000) RETURNING command_key', [now - 90 * 86400000])).rows.length;
      await audit(client, 'system', 'retention.prune', '', JSON.stringify(counts)); return counts;
    })
  };
}
