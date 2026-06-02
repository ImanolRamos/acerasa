const { pool } = require("../db/pool");

async function createEvent({
  clientName,
  sessionId,
  userId,
  eventType,
  page,
  element,
  metadata,
}) {
  await pool.query(
    `
    INSERT INTO frontend_events (
      client_name,
      session_id,
      user_id,
      event_type,
      page,
      element,
      metadata
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    `,
    [
      clientName,
      sessionId || null,
      userId || null,
      eventType,
      page || null,
      element || null,
      metadata && typeof metadata === "object" ? metadata : {},
    ]
  );
}

module.exports = {
  createEvent,
};