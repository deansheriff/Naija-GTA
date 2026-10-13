import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Client} from 'pg';
import {databaseConfig} from '../src/database-config.js';

test('Compose passes a raw punctuation password to pg without URL parsing', () => {
  const password = 'disposable:@/?#%$[] password';
  const config = databaseConfig({NODE_ENV: 'production', PGHOST: 'postgres', PGUSER: 'nsl', PGDATABASE: 'nsl', PGPASSWORD: password, DATABASE_URL: 'a stale invalid URL'});
  const client = new Client(config);
  assert.equal(client.password, password);
  assert.equal(client.host, 'postgres');
  assert.equal(client.port, 5432);
  assert.equal(client.database, 'nsl');
  assert.equal(config?.connectionString, undefined);
});

test('external PostgreSQL URLs still support percent-encoded credentials', () => {
  const password = 'disposable:@/?#%$[] password';
  const config = databaseConfig({NODE_ENV: 'production', DATABASE_URL: `postgresql://nsl:${encodeURIComponent(password)}@localhost:5432/nsl`});
  assert.equal(new Client(config).password, password);
});

test('invalid database configuration fails clearly without revealing credentials', () => {
  for (const url of ['postgresql://nsl:private-secret/?@postgres:5432/nsl', '"postgresql://nsl:private-secret@postgres:5432/nsl"', 'https://private-secret.example/nsl', 'postgresql://nsl:private-secret%xy@postgres/nsl']) {
    assert.throws(() => databaseConfig({NODE_ENV: 'production', DATABASE_URL: url}), error => {
      assert.ok(error instanceof Error);
      assert.match(error.message, /DATABASE_URL is invalid/);
      assert.ok(!error.message.includes('private-secret'));
      assert.ok(!('input' in error));
      return true;
    });
  }
  assert.throws(() => databaseConfig({NODE_ENV: 'production'}), /refusing local SQLite/);
  assert.throws(() => databaseConfig({PGHOST: 'postgres'}), /requires PGUSER/);
  assert.throws(() => databaseConfig({PGUSER: 'nsl'}), /requires PGHOST/);
  for (const port of ['0', '65536', 'abc', '1e3']) {
    assert.throws(() => databaseConfig({PGHOST: 'postgres', PGUSER: 'nsl', PGDATABASE: 'nsl', PGPASSWORD: 'test', PGPORT: port}), /PGPORT/);
  }
  assert.equal(databaseConfig({NODE_ENV: 'development'}), undefined);
});
