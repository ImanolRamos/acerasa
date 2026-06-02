const clientProm = require("prom-client");

clientProm.collectDefaultMetrics({
  prefix: "koiote_",
});

async function getMetrics(req, res) {
  res.set("Content-Type", clientProm.register.contentType);
  res.end(await clientProm.register.metrics());
}

module.exports = {
  getMetrics,
};