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

async function getAverageHistory(req, res) {
  try {
    const variables = String(req.query.variables || "")
      .split(",")
      .map((v) => v.trim())
      .filter(Boolean);

    const bucketMinutes = Number(req.query.bucket_minutes);
    const startDate = req.query.startDate || null;
    const endDate = req.query.endDate || null;

    if (variables.length === 0) {
      return res.status(400).json({
        ok: false,
        error: "Debes indicar al menos una variable",
      });
    }

    if (!Number.isFinite(bucketMinutes) || bucketMinutes <= 0) {
      return res.status(400).json({
        ok: false,
        error: "bucket_minutes debe ser un número positivo",
      });
    }

    if (startDate && Number.isNaN(Date.parse(startDate))) {
      return res.status(400).json({
        ok: false,
        error: "startDate no tiene un formato válido",
      });
    }

    if (endDate && Number.isNaN(Date.parse(endDate))) {
      return res.status(400).json({
        ok: false,
        error: "endDate no tiene un formato válido",
      });
    }

    const data = await measurementsRepository.getAverageHistory({
      variables,
      bucketMinutes,
      startDate,
      endDate,
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

async function getMeasurementCount(req, res) {
  try {
    const count = await measurementsRepository.getMeasurementCount();

    res.json({
      ok: true,
      data: { count },
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
  getAverageHistory,
  getMeasurementCount,
};