-- Daily aggregate counters only — one row per (day, event, version, os).
-- No per-request rows, no timestamps finer than a day, no IPs.
-- Apply: npx wrangler d1 execute blink-analytics --remote --file worker/schema.sql
CREATE TABLE IF NOT EXISTS events (
  day             TEXT    NOT NULL,   -- YYYY-MM-DD (UTC)
  event           TEXT    NOT NULL,   -- 'appcast' | 'download'
  app_version     TEXT    NOT NULL DEFAULT '',
  sparkle_version TEXT    NOT NULL DEFAULT '',
  os              TEXT    NOT NULL DEFAULT '',
  count           INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, event, app_version, sparkle_version, os)
);
