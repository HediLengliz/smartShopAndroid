const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { generateToken, generateVerificationToken, generatePasswordResetToken, authenticateToken, JWT_SECRET } = require('../middleware/auth');
const { sendEmail } = require('../config/email');

const router = express.Router();

router.post('/signup',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
    body('firstName').trim().notEmpty(),
    body('lastName').trim().notEmpty()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password, firstName, lastName, phone } = req.body;

    try {
      const existingUser = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
      
      if (existingUser.rows.length > 0) {
        return res.status(400).json({ error: 'Email already registered' });
      }

      const hashedPassword = await bcrypt.hash(password, 10);
      const verificationToken = generateVerificationToken();

      await pool.query(
        'INSERT INTO users (email, password_hash, first_name, last_name, phone, verification_token) VALUES (?, ?, ?, ?, ?, ?)',
        [email, hashedPassword, firstName, lastName, phone, verificationToken]
      );

      const result = await pool.query(
        'SELECT id, email, first_name, last_name FROM users WHERE email = ?',
        [email]
      );

      const user = result.rows[0];

      const verificationLink = `${process.env.APP_URL || 'http://localhost:3000'}/api/auth/verify-email?token=${verificationToken}&email=${email}`;
      
      await sendEmail(
        email,
        'Verify Your Smart Shop Account',
        `<h2>Welcome to Smart Shop!</h2>
         <p>Please verify your email address by clicking the link below:</p>
         <a href="${verificationLink}">Verify Email</a>
         <p>This link will expire in 24 hours.</p>`
      );

      res.status(201).json({
        message: 'Registration successful. Please check your email to verify your account.',
        user: { id: user.id, email: user.email, firstName: user.first_name, lastName: user.last_name }
      });
    } catch (error) {
      console.error('Signup error:', error);
      res.status(500).json({ error: 'Registration failed' });
    }
  }
);

router.get('/verify-email', async (req, res) => {
  const { token, email } = req.query;

  try {
    jwt.verify(token, JWT_SECRET);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(400).json({ error: 'Verification link has expired. Please request a new one.' });
    }
    return res.status(400).json({ error: 'Invalid verification token' });
  }

  try {
    const user = await pool.query(
      'SELECT * FROM users WHERE email = ? AND verification_token = ?',
      [email, token]
    );

    if (user.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired verification token' });
    }

      await pool.query(
        'UPDATE users SET email_verified = true, verification_token = NULL WHERE email = ?',
        [email]
      );

    res.json({ message: 'Email verified successfully. You can now log in.' });
  } catch (error) {
    console.error('Email verification error:', error);
    res.status(500).json({ error: 'Verification failed' });
  }
});

router.post('/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;

    try {
      const result = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
      
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const user = result.rows[0];

      if (!user.email_verified) {
        return res.status(403).json({ error: 'Please verify your email before logging in' });
      }

      const isValidPassword = await bcrypt.compare(password, user.password_hash);
      
      if (!isValidPassword) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = generateToken(user.id, user.email);

      res.json({
        token,
        user: {
          id: user.id,
          email: user.email,
          firstName: user.first_name,
          lastName: user.last_name,
          phone: user.phone,
          profilePicture: user.profile_picture_url
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ error: 'Login failed' });
    }
  }
);

router.post('/forgot-password',
  [body('email').isEmail().normalizeEmail()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email } = req.body;

    try {
      const user = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
      
      if (user.rows.length === 0) {
        return res.json({ message: 'If the email exists, a password reset link has been sent.' });
      }

      const resetToken = generatePasswordResetToken();
      const resetExpires = new Date(Date.now() + 3600000);

      await pool.query(
        'UPDATE users SET reset_password_token = ?, reset_password_expires = ? WHERE email = ?',
        [resetToken, resetExpires, email]
      );

      const resetLink = `${process.env.APP_URL || 'http://localhost:3000'}/api/auth/reset-password?token=${resetToken}&email=${email}`;
      
      await sendEmail(
        email,
        'Reset Your Smart Shop Password',
        `<h2>Password Reset Request</h2>
         <p>You requested to reset your password. Click the link below to reset it:</p>
         <a href="${resetLink}">Reset Password</a>
         <p>This link will expire in 1 hour.</p>
         <p>If you didn't request this, please ignore this email.</p>`
      );

      res.json({ message: 'If the email exists, a password reset link has been sent.' });
    } catch (error) {
      console.error('Forgot password error:', error);
      res.status(500).json({ error: 'Password reset request failed' });
    }
  }
);

router.post('/reset-password',
  [
    body('email').isEmail().normalizeEmail(),
    body('token').notEmpty(),
    body('newPassword').isLength({ min: 6 })
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, token, newPassword } = req.body;

    try {
      jwt.verify(token, JWT_SECRET);
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        return res.status(400).json({ error: 'Password reset link has expired. Please request a new one.' });
      }
      return res.status(400).json({ error: 'Invalid reset token' });
    }

    try {
      const user = await pool.query(
        'SELECT * FROM users WHERE email = ? AND reset_password_token = ? AND reset_password_expires > NOW()',
        [email, token]
      );

      if (user.rows.length === 0) {
        return res.status(400).json({ error: 'Invalid or expired reset token' });
      }

      const hashedPassword = await bcrypt.hash(newPassword, 10);

      await pool.query(
        'UPDATE users SET password_hash = ?, reset_password_token = NULL, reset_password_expires = NULL WHERE email = ?',
        [hashedPassword, email]
      );

      res.json({ message: 'Password reset successful. You can now log in with your new password.' });
    } catch (error) {
      console.error('Reset password error:', error);
      res.status(500).json({ error: 'Password reset failed' });
    }
  }
);

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, first_name, last_name, phone, profile_picture_url, email_verified, created_at FROM users WHERE id = ?',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];

    res.json({
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      phone: user.phone,
      profilePicture: user.profile_picture_url,
      emailVerified: user.email_verified,
      createdAt: user.created_at
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to fetch user data' });
  }
});

module.exports = router;
