-- 004_owner_address.sql
-- Allow-list: which sender address belongs to which owner.
-- No seed rows here on purpose: real addresses stay out of the repo and are inserted by hand.
-- Safe to re-run: IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS ctl.owner_address (
  address  text PRIMARY KEY,                    -- sender address, lowercase
  owner_id text NOT NULL
);
