CREATE SCHEMA IF NOT EXISTS sanju_beta;
CREATE TABLE IF NOT EXISTS sanju_beta.testers (
  id uuid PRIMARY KEY, code_hash text NOT NULL UNIQUE, label text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
  revoked boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS sanju_beta.sessions (
  token_hash text PRIMARY KEY, tester_id uuid NOT NULL REFERENCES sanju_beta.testers(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS beta_session_tester ON sanju_beta.sessions(tester_id);
CREATE TABLE IF NOT EXISTS sanju_beta.usage (
  tester_id uuid NOT NULL REFERENCES sanju_beta.testers(id) ON DELETE CASCADE, day text NOT NULL,
  used integer NOT NULL DEFAULT 0 CHECK (used >= 0), calls integer NOT NULL DEFAULT 0,
  minute_at timestamptz NOT NULL, PRIMARY KEY(tester_id, day)
);
CREATE TABLE IF NOT EXISTS sanju_beta.budget (day text PRIMARY KEY, calls integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS sanju_beta.creations (
  id uuid PRIMARY KEY, tester_id uuid NOT NULL REFERENCES sanju_beta.testers(id) ON DELETE CASCADE,
  digest text NOT NULL, expires_at timestamptz NOT NULL, ready boolean NOT NULL DEFAULT false,
  swaps integer NOT NULL DEFAULT 3 CHECK (swaps >= 0 AND swaps <= 3),
  versions jsonb NOT NULL DEFAULT '{"cool":[],"romantic":[],"youth":[]}'::jsonb
);
CREATE TABLE IF NOT EXISTS sanju_beta.jobs (
  id uuid PRIMARY KEY, tester_id uuid NOT NULL REFERENCES sanju_beta.testers(id) ON DELETE CASCADE,
  creation_id uuid NOT NULL, digest text NOT NULL, style text,
  status text NOT NULL CHECK(status IN ('processing','succeeded','failed')),
  reply jsonb, failure_code text, quota_day text NOT NULL,
  lease_until timestamptz NOT NULL, created_at timestamptz NOT NULL, expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS beta_job_owner ON sanju_beta.jobs(tester_id, status);
CREATE TABLE IF NOT EXISTS sanju_beta.feedback (
  id uuid PRIMARY KEY, tester_id uuid NOT NULL REFERENCES sanju_beta.testers(id) ON DELETE CASCADE,
  creation_id uuid, category text NOT NULL, note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sanju_beta.login_limits (
  address_hash text PRIMARY KEY, started_at timestamptz NOT NULL, attempts integer NOT NULL
);
