-- ============================================================
-- Koiote Edge — TimescaleDB schema
-- Se ejecuta automáticamente al crear el contenedor por primera vez.
-- ============================================================

-- ============================================================
-- EVENTOS FRONTEND
-- Registra interacciones del usuario en la interfaz Vue3.
-- ============================================================

CREATE TABLE IF NOT EXISTS frontend_events (
    time        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    client_name TEXT            NOT NULL,
    session_id  UUID,
    user_id     TEXT,
    event_type  TEXT            NOT NULL,
    page        TEXT,
    element     TEXT,
    metadata    JSONB           NOT NULL DEFAULT '{}'
);

SELECT create_hypertable(
    'frontend_events',
    'time',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_frontend_events_client
    ON frontend_events (client_name, time DESC);

CREATE INDEX IF NOT EXISTS idx_frontend_events_session
    ON frontend_events (session_id, time DESC);

CREATE INDEX IF NOT EXISTS idx_frontend_events_type
    ON frontend_events (event_type, time DESC);

-- ============================================================
-- MÉTRICAS DE SISTEMA (opcional — complementa node-exporter)
-- Útil para guardar snapshots históricos con contexto de cliente.
-- ============================================================

CREATE TABLE IF NOT EXISTS system_snapshots (
    time        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    client_name TEXT            NOT NULL,
    cpu_pct     DOUBLE PRECISION,
    mem_pct     DOUBLE PRECISION,
    disk_pct    DOUBLE PRECISION,
    metadata    JSONB           NOT NULL DEFAULT '{}'
);

SELECT create_hypertable(
    'system_snapshots',
    'time',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_system_snapshots_client
    ON system_snapshots (client_name, time DESC);

-- ============================================================
-- Política de retención: borrar datos más antiguos de 90 días.
-- Ajusta el intervalo según necesidades del cliente.
-- ============================================================

SELECT add_retention_policy(
    'frontend_events',
    INTERVAL '90 days',
    if_not_exists => TRUE
);

SELECT add_retention_policy(
    'system_snapshots',
    INTERVAL '90 days',
    if_not_exists => TRUE
);
