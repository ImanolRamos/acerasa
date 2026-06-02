const { checkDbConnection } = require("../db/pool");

async function getHealth(req, res) {
  let dbOk = false;

  try {
    await checkDbConnection();
    dbOk = true;
  } catch (error) {
    dbOk = false;
  }

  res.status(dbOk ? 200 : 503).json({
    ok: dbOk,
    service: "koiote-cloud-backend",
    db: dbOk ? "ok" : "unavailable",
    timestamp: new Date().toISOString(),
  });
}

module.exports = {
  getHealth,
};