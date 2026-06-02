const eventsRepository = require("../repositories/events.repository");

async function createEvent(req, res) {
  const {
    session_id,
    user_id,
    event_type,
    page,
    element,
    metadata,
  } = req.body;

  if (!event_type) {
    return res.status(400).json({
      ok: false,
      error: "event_type requerido",
    });
  }

  try {
    await eventsRepository.createEvent({
      clientName: process.env.CLIENT_NAME || "koiote",
      sessionId: session_id,
      userId: user_id,
      eventType: event_type,
      page,
      element,
      metadata,
    });

    res.json({
      ok: true,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error.message,
    });
  }
}

module.exports = {
  createEvent,
};