const bcrypt = require('bcrypt')
const jwt = require('jsonwebtoken')
const loginRepository = require('../repositories/login.repositories')

async function login(req, res) {
  try {
    const { usernameOrEmail, password } = req.body

    if (!usernameOrEmail || !password) {
      return res.status(400).json({
        ok: false,
        error: 'Username/email and password are required',
      })
    }

    const user = await loginRepository.findUserByUsernameOrEmail(usernameOrEmail)

    if (!user || !user.active) {
      return res.status(401).json({
        ok: false,
        error: 'Invalid credentials',
      })
    }

    const validPassword = await bcrypt.compare(password, user.password)

    if (!validPassword) {
      return res.status(401).json({
        ok: false,
        error: 'Invalid credentials',
      })
    }

    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,
        username: user.username,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: '8h',
      }
    )

    return res.json({
      ok: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
      },
    })
  } catch (error) {
    console.error('Login error:', error)

    return res.status(500).json({
      ok: false,
      error: 'Internal server error',
    })
  }
}

module.exports = {
  login,
}