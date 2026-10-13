import type {PoolConfig} from 'pg';

// Keep raw passwords out of URLs. Explicit PG fields take precedence over a
// leftover DATABASE_URL when switching an existing Coolify app to Compose.
export function databaseConfig(env: NodeJS.ProcessEnv): PoolConfig | undefined {
  if (env.PGHOST) {
    for (const key of ['PGUSER', 'PGDATABASE', 'PGPASSWORD'] as const) {
      if (!env[key]) throw new Error(`PostgreSQL configuration requires ${key} when PGHOST is set.`);
    }
    const portText = env.PGPORT ?? '5432';
    const port = Number(portText);
    if (!/^\d+$/.test(portText) || !Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('PGPORT must be an integer between 1 and 65535.');
    }
    return {host: env.PGHOST, port, user: env.PGUSER, database: env.PGDATABASE, password: env.PGPASSWORD};
  }
  if (env.DATABASE_URL) {
    try {
      const url = new URL(env.DATABASE_URL);
      if (!['postgres:', 'postgresql:'].includes(url.protocol) || !url.hostname || url.hash || env.DATABASE_URL !== env.DATABASE_URL.trim()) {
        throw new Error();
      }
      // Detect malformed percent escapes before the driver parses credentials.
      decodeURIComponent(url.username); decodeURIComponent(url.password); decodeURI(url.pathname);
    } catch {
      // Never include the original URL (or an error carrying it) in logs.
      throw new Error('DATABASE_URL is invalid. Use separate PGHOST, PGPORT, PGUSER, PGDATABASE and PGPASSWORD fields, or a postgres:// URL with percent-encoded credentials.');
    }
    return {connectionString: env.DATABASE_URL};
  }
  if (['PGUSER', 'PGDATABASE', 'PGPASSWORD', 'PGPORT'].some(key => env[key])) {
    throw new Error('PostgreSQL configuration requires PGHOST.');
  }
  if (env.NODE_ENV === 'production') {
    throw new Error('Production requires PostgreSQL: set PGHOST, PGUSER, PGDATABASE and PGPASSWORD, or DATABASE_URL; refusing local SQLite.');
  }
  return undefined;
}
