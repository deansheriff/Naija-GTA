CREATE TABLE world_settings (id integer PRIMARY KEY CHECK(id=1), value jsonb NOT NULL);
CREATE TABLE owner_sessions (token_hash char(64) PRIMARY KEY, fingerprint char(64) NOT NULL, expires_at bigint NOT NULL);
CREATE TABLE player_controls (character_id uuid PRIMARY KEY REFERENCES characters(id), suspended boolean NOT NULL DEFAULT false);
CREATE TABLE owner_audit (id bigserial PRIMARY KEY, actor varchar(80) NOT NULL, action varchar(60) NOT NULL, target varchar(80) NOT NULL, reason varchar(200) NOT NULL, created_at bigint NOT NULL);
CREATE FUNCTION prevent_owner_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'owner audit is append-only'; END;
$$;
CREATE TRIGGER owner_audit_append_only BEFORE UPDATE OR DELETE ON owner_audit FOR EACH ROW EXECUTE FUNCTION prevent_owner_audit_mutation();
CREATE TABLE rate_buckets (key char(64) PRIMARY KEY, window_end bigint NOT NULL, count integer NOT NULL);
ALTER TABLE commands ADD COLUMN created_at bigint NOT NULL DEFAULT 0;
CREATE INDEX commands_retention ON commands(created_at) WHERE created_at > 0;
CREATE INDEX owner_sessions_expiry ON owner_sessions(expires_at);
