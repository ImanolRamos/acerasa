function getInfo(req, res) {
  res.json({
    ok: true,
    client: process.env.CLIENT_NAME || "koiote",
    backend: "nodejs",
    version: "1.0.0",
    status: "running",
    timestamp: new Date().toISOString(),
  });
}

module.exports = {
  getInfo,
};