-- ============================================================
-- Koiote Cloud Stack — TimescaleDB schema
-- ============================================================

-- Eventos del frontend
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

SELECT create_hypertable('frontend_events', 'time', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_fe_client ON frontend_events (client_name, time DESC);

-- Mensajes MQTT — datos del Teltonika / sensores
CREATE TABLE IF NOT EXISTS mqtt_messages (
    time        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    client_name TEXT            NOT NULL,
    topic       TEXT            NOT NULL,
    payload     JSONB           NOT NULL DEFAULT '{}',
    raw         TEXT
);

SELECT create_hypertable('mqtt_messages', 'time', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_mqtt_client  ON mqtt_messages (client_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_mqtt_topic   ON mqtt_messages (topic, time DESC);

-- Vista útil: último valor por topic
CREATE OR REPLACE VIEW mqtt_latest AS
SELECT DISTINCT ON (topic)
    time, client_name, topic, payload, raw
FROM mqtt_messages
ORDER BY topic, time DESC;

-- Políticas de retención
SELECT add_retention_policy('frontend_events', INTERVAL '90 days', if_not_exists => TRUE);
SELECT add_retention_policy('mqtt_messages',   INTERVAL '90 days', if_not_exists => TRUE);
