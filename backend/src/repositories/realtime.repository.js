const { pool } = require('../db/pool')

async function findActiveVariablesByNames(variableNames) {
  const result = await pool.query(
    `
    SELECT
      id,
      original_name,
      new_name,
      unit,
      active
    FROM measurement_variables
    WHERE active = TRUE
      AND new_name = ANY($1::text[])
    ORDER BY id;
    `,
    [variableNames],
  )

  return result.rows
}

module.exports = {
  findActiveVariablesByNames,
}