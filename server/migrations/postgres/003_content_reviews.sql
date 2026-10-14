CREATE TABLE content_reviews (
  id bigserial PRIMARY KEY,
  unit_id varchar(100) NOT NULL,
  content_hash char(64) NOT NULL,
  status varchar(30) NOT NULL CHECK(status IN ('approved','changes_requested','pending')),
  notes varchar(2000) NOT NULL,
  actor varchar(80) NOT NULL,
  created_at bigint NOT NULL
);
CREATE INDEX content_reviews_unit ON content_reviews(unit_id,id DESC);
CREATE FUNCTION prevent_content_review_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'content review is append-only'; END;
$$;
CREATE TRIGGER content_review_append_only BEFORE UPDATE OR DELETE ON content_reviews FOR EACH ROW EXECUTE FUNCTION prevent_content_review_mutation();
