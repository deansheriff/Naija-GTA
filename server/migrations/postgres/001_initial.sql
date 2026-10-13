-- Production schema proposal. The development runtime uses SQLite.
-- Apply and integration-test with PostgreSQL before enabling production sessions.
CREATE TABLE characters (
  id uuid PRIMARY KEY,
  revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
  state jsonb NOT NULL,
  save_key_hash char(64) UNIQUE,
  CONSTRAINT nonnegative_coins CHECK ((state->>'coins')::bigint >= 0)
);
CREATE TABLE sessions (
  token_hash char(64) PRIMARY KEY,
  character_id uuid NOT NULL REFERENCES characters(id),
  expires_at bigint NOT NULL
);
CREATE INDEX sessions_expiry ON sessions(expires_at);
CREATE TABLE commands (
  character_id uuid NOT NULL REFERENCES characters(id),
  command_key varchar(80) NOT NULL,
  request_hash char(64) NOT NULL,
  response jsonb NOT NULL,
  PRIMARY KEY(character_id,command_key)
);
CREATE TABLE ledger (
  id uuid PRIMARY KEY,
  character_id uuid NOT NULL REFERENCES characters(id),
  command_key varchar(80) NOT NULL,
  delta bigint NOT NULL,
  balance bigint NOT NULL CHECK(balance >= 0),
  reason varchar(80) NOT NULL,
  created_at bigint NOT NULL
);
CREATE INDEX ledger_character_time ON ledger(character_id,created_at);
CREATE FUNCTION prevent_ledger_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'ledger is append-only'; END;
$$;
CREATE TRIGGER ledger_append_only BEFORE UPDATE OR DELETE ON ledger
  FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();
