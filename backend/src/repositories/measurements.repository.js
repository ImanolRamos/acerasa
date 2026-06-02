const { pool } = require("../db/pool");

async function findVariables() {
  const result = await pool.query(`
    SELECT
      id,
      original_name,
      new_name,
      unit,
      active
    FROM measurement_variables
    WHERE active = TRUE
    ORDER BY id;
  `);

  return result.rows;
}

async function findLatestMeasurements() {
  const result = await pool.query(`
    SELECT DISTINCT ON (mv.id)
      mv.id AS variable_id,
      mv.original_name,
      mv.new_name,
      mv.unit,
      m.value,
      m.created_at
    FROM measurement_variables mv
    JOIN measurements m ON m.variable_id = mv.id
    WHERE mv.active = TRUE
    ORDER BY mv.id, m.created_at DESC;
  `);

  return result.rows;
}

async function findMeasurementHistory({ variableId, variableName, from, to, limit }) {
  const result = await pool.query(
    `
    SELECT
      m.created_at,
      mv.id AS variable_id,
      mv.original_name,
      mv.new_name,
      mv.unit,
      m.value
    FROM measurements m
    JOIN measurement_variables mv ON mv.id = m.variable_id
    WHERE mv.active = TRUE
      AND ($1::integer IS NULL OR mv.id = $1)
      AND ($2::text IS NULL OR mv.new_name = $2 OR mv.original_name = $2)
      AND m.created_at >= COALESCE($3::timestamptz, NOW() - INTERVAL '24 hours')
      AND m.created_at <= COALESCE($4::timestamptz, NOW())
    ORDER BY m.created_at ASC
    LIMIT $5;
    `,
    [
      variableId || null,
      variableName || null,
      from || null,
      to || null,
      limit || 1000,
    ]
  );

  return result.rows;
}
async function getAverageHistory({ variables, bucketMinutes }) {
  const result = await pool.query(
    `
    SELECT
      time_bucket(($2::int || ' minutes')::interval, m.created_at) AS time,
      mv.id AS variable_id,
      mv.new_name AS variable,
      mv.unit,
      ROUND(AVG(m.value)::numeric, 3)::double precision AS value
    FROM measurements m
    JOIN measurement_variables mv ON mv.id = m.variable_id
    WHERE mv.active = TRUE
      AND mv.new_name = ANY($1::text[])
    GROUP BY time, mv.id, mv.new_name, mv.unit
    ORDER BY time ASC, mv.id ASC;
    `,
    [variables, bucketMinutes]
  );

  return result.rows;
}

module.exports = {
  findVariables,
  findLatestMeasurements,
  findMeasurementHistory,
  getAverageHistory,
};