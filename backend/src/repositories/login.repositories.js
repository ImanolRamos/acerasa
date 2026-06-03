const pool = require('../db/pool')

async function findUserByUsernameOrEmail(usernameOrEmail) {
  const result = await pool.query(
    `
    SELECT id, email, username, password, active
    FROM users
    WHERE username = $1
       OR email = $1
    LIMIT 1
    `,
    [usernameOrEmail]
  )

  return result.rows[0] || null
}

module.exports = {
  findUserByUsernameOrEmail,
}