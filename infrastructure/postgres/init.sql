-- ─────────────────────────────────────────────────────────────
-- Cloud Incident Lab — PostgreSQL Init Schema
-- Runs automatically on first container start
-- ─────────────────────────────────────────────────────────────

-- Services registered in the incident lab
CREATE TABLE IF NOT EXISTS services (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Deployment history per service
CREATE TABLE IF NOT EXISTS deployments (
    id             SERIAL PRIMARY KEY,
    service_name   VARCHAR(100) NOT NULL,
    version        VARCHAR(50),
    deployed_at    TIMESTAMP DEFAULT NOW(),
    commit_message TEXT,
    config_diff    TEXT,
    deployed_by    VARCHAR(100) DEFAULT 'system'
);

-- Incidents (active or resolved)
CREATE TABLE IF NOT EXISTS incidents (
    id          SERIAL PRIMARY KEY,
    title       TEXT NOT NULL,
    status      VARCHAR(50)  DEFAULT 'open',
    severity    VARCHAR(20)  DEFAULT 'medium',
    started_at  TIMESTAMP    DEFAULT NOW(),
    resolved_at TIMESTAMP,
    summary     TEXT
);

-- Items managed by the backend API
CREATE TABLE IF NOT EXISTS items (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Audit log — written by the Rust worker for every processed job
CREATE TABLE IF NOT EXISTS audit_log (
    id          SERIAL PRIMARY KEY,
    event_type  VARCHAR(100) NOT NULL,
    instance_id VARCHAR(100),
    endpoint    VARCHAR(200),
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Seed: register core services
INSERT INTO services (name, description) VALUES
    ('frontend',  'React user-facing application'),
    ('backend',   'Spring Boot core API service'),
    ('postgres',  'PostgreSQL database'),
    ('redis',     'Redis cache layer'),
    ('worker',    'Rust background job processor')
ON CONFLICT (name) DO NOTHING;
