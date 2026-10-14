// CI restore proof: hashes only, never tokens, save codes, passwords or raw player rows.
import {readFile, writeFile} from 'node:fs/promises';
import {Pool} from 'pg';
import {databaseConfig} from './database-config.js';
import {canonical} from './store.js';
import {digest} from './operations.js';
const [mode, file] = process.argv.slice(2);
if (!['record','verify'].includes(mode) || !file) throw new Error('Usage: backup-check record|verify manifest-path');
const config = databaseConfig(process.env);
if (!config) throw new Error('PostgreSQL configuration is required.');
const pool = new Pool(config);
try {
  const manifest: Record<string, {count: number; sha256: string}> = {};
  for (const table of ['characters','sessions','commands','ledger','world_settings','owner_sessions','player_controls','owner_audit','content_reviews','schema_versions']) {
    const count=Number((await pool.query(`SELECT count(*) AS count FROM ${table}`)).rows[0].count);
    if (count>10000) throw new Error('This CI proof utility is limited to disposable test datasets.');
    const rows=(await pool.query(`SELECT * FROM ${table}`)).rows.map(canonical).sort();
    manifest[table]={count,sha256:digest(rows.join('\n'))};
  }
  if(mode==='record') await writeFile(file,JSON.stringify(manifest),{flag:'wx',mode:0o600});
  else {
    const expected=JSON.parse(await readFile(file,'utf8'));
    if(canonical(expected)!==canonical(manifest)) throw new Error('Restored rows do not match the recorded source.');
    // Roll back both probes even if a trigger has accidentally disappeared.
    const client=await pool.connect();
    try {
      for(const table of ['ledger','owner_audit','content_reviews']) {
        await client.query('BEGIN');let blocked=false;
        try {await client.query(`DELETE FROM ${table}`);} catch {blocked=true;} finally {await client.query('ROLLBACK');}
        if(!blocked) throw new Error('Append-only protection missing from restored database.');
      }
    } finally {client.release();}
  }
  console.log(mode==='record'?'Backup proof manifest recorded.':'Restore verified: character state, receipts, sessions, ledger, settings, audit and append-only protections match.');
} finally {await pool.end();}
