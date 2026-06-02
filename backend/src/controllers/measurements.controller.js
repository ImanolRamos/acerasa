const measurementsRepository = require("../repositories/measurements.repository");

async function getVariables(req, res) {
  try {
    const data = await measurementsRepository.findVariables();

    res.json({
      ok: true,
      data,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error.message,
    });
  }
}

async function getLatestMeasurements(req, res) {
  try {
    const data = await measurementsRepository.findLatestMeasurements();

    res.json({
      ok: true,
      data,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error.message,
    });
  }
}

async function getMeasurementHistory(req, res) {
  const {
    variable_id,
    variable,
    from,
    to,
    limit = 1000,
  } = req.query;

  if (!variable_id && !variable) {
    return res.status(400).json({
      ok: false,
      error: "Debes indicar variable_id o variable",
    });
  }

  try {
    const data = await measurementsRepository.findMeasurementHistory({
      variableId: variable_id ? Number(variable_id) : null,
      variableName: variable || null,
      from: from || null,
      to: to || null,
      limit: Number(limit),
    });

    res.json({
      ok: true,
      data,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error.message,
    });
  }
}

module.exports = {
  getVariables,
  getLatestMeasurements,
  getMeasurementHistory,
};