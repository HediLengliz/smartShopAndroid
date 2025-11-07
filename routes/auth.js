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

      // Deep link for Flutter app - opens verification screen in mobile app
      const deepLink = `smartshop://verify?token=${verificationToken}&email=${encodeURIComponent(email)}`;
      // Android intent URL (works better in emulators)
      const androidIntent = `intent://verify?token=${verificationToken}&email=${encodeURIComponent(email)}#Intent;scheme=smartshop;package=com.smartshop.app.smart_shop;end`;
      // Web verification page that redirects to app
      const webLink = `${process.env.APP_URL || 'http://localhost:3000'}/verify?token=${verificationToken}&email=${encodeURIComponent(email)}`;
      
      await sendEmail(
        email,
        'Verify Your Smart Shop Account',
        `<html>
          <body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <h2 style="color: #ff9800; text-align: center;">Welcome to Smart Shop!</h2>
              <p style="font-size: 16px; color: #333; line-height: 1.6;">
                Please verify your email address by clicking the button below. This will open the Smart Shop app on your device.
              </p>
              <div style="text-align: center; margin: 30px 0;">
                <a href="${webLink}" 
                   style="display: inline-block; background-color: #ff9800; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">
                  Verify Email Address
                </a>
              </div>
              <p style="font-size: 14px; color: #666; text-align: center; margin-top: 20px;">
                Or copy and paste this link in your browser:<br>
                <a href="${webLink}" style="color: #ff9800; word-break: break-all;">${webLink}</a>
              </p>
              <p style="font-size: 12px; color: #999; text-align: center; margin-top: 30px;">
                This link will expire in 24 hours.
              </p>
            </div>
          </body>
        </html>`
      );

      // Log verification link for easy testing in development
      if (process.env.NODE_ENV === 'development') {
        console.log('\n' + '='.repeat(80));
        console.log('📧 VERIFICATION EMAIL SENT');
        console.log('='.repeat(80));
        console.log(`Email: ${email}`);
        console.log(`Token: ${verificationToken}`);
        console.log(`\n🌐 Web Link (open in browser):`);
        console.log(`${webLink}`);
        console.log(`\n📱 Emulator Link (open in browser on your computer):`);
        console.log(`http://10.0.2.2:3000/verify?token=${verificationToken}&email=${encodeURIComponent(email)}`);
        console.log(`\n🔧 ADB Command (paste in terminal):`);
        console.log(`adb shell am start -W -a android.intent.action.VIEW -d "http://10.0.2.2:3000/verify?token=${verificationToken}&email=${encodeURIComponent(email)}" com.smartshop.app.smart_shop`);
        console.log('='.repeat(80) + '\n');
      }

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

// Web verification page that redirects to app
router.get('/verify', async (req, res) => {
  const { token, email } = req.query;

  if (!token || !email) {
    return res.status(400).send(`
      <html>
        <head>
          <title>Verification Error</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: Arial, sans-serif; padding: 20px; text-align: center;">
          <h2 style="color: #f44336;">Invalid Verification Link</h2>
          <p>The verification link is missing required parameters.</p>
        </body>
      </html>
    `);
  }

  // HTML page that tries to open the app, then falls back to API verification
  const deepLink = `smartshop://verify?token=${token}&email=${encodeURIComponent(email)}`;
  const androidIntent = `intent://verify?token=${token}&email=${encodeURIComponent(email)}#Intent;scheme=smartshop;package=com.smartshop.app.smart_shop;end`;
  
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Email Verification - Smart Shop</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta charset="UTF-8">
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
          }
          .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #ff9800;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
          h1 {
            color: #333;
            margin-bottom: 10px;
          }
          p {
            color: #666;
            line-height: 1.6;
            margin-bottom: 20px;
          }
          .button {
            display: inline-block;
            background-color: #ff9800;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin-top: 20px;
            border: none;
            cursor: pointer;
            font-size: 16px;
          }
          .button:hover {
            background-color: #fb8c00;
          }
        </style>
        <script>
          // Try to open the app immediately
          function openApp() {
            const deepLink = '${deepLink}';
            const androidIntent = '${androidIntent}';
            
            // Try Android intent first (works better in emulators)
            if (navigator.userAgent.toLowerCase().indexOf('android') > -1) {
              window.location.href = androidIntent;
              // Fallback to custom scheme after a delay
              setTimeout(function() {
                window.location.href = deepLink;
              }, 500);
            } else {
              // For iOS or other platforms
              window.location.href = deepLink;
            }
            
            // If app doesn't open, show manual button after 2 seconds
            setTimeout(function() {
              document.getElementById('manualButton').style.display = 'block';
              document.getElementById('spinner').style.display = 'none';
              document.getElementById('status').textContent = 'If the app didn\'t open, click the button below:';
            }, 2000);
          }
          
          // Auto-trigger on page load
          window.onload = function() {
            openApp();
          };
        </script>
      </head>
      <body>
        <div class="container">
          <h1>Opening Smart Shop App...</h1>
          <div id="spinner" class="spinner"></div>
          <p id="status">Redirecting to the app for email verification...</p>
          <a id="manualButton" href="${deepLink}" class="button" style="display: none;">
            Open in Smart Shop App
          </a>
          <p style="font-size: 12px; color: #999; margin-top: 30px;">
            If you don't have the app installed, please install it first.
          </p>
        </div>
      </body>
    </html>
  `);
});

// GET endpoint for web browser verification (API endpoint)
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

// POST endpoint for Flutter mobile app verification
router.post('/verify-email',
  [
    body('token').notEmpty(),
    body('email').isEmail().normalizeEmail()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { token, email } = req.body;

    try {
      jwt.verify(token, JWT_SECRET);
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        return res.status(400).json({ 
          success: false,
          error: 'Verification link has expired. Please request a new one.' 
        });
      }
      return res.status(400).json({ 
        success: false,
        error: 'Invalid verification token' 
      });
    }

    try {
      const user = await pool.query(
        'SELECT * FROM users WHERE email = ? AND verification_token = ?',
        [email, token]
      );

      if (user.rows.length === 0) {
        return res.status(400).json({ 
          success: false,
          error: 'Invalid or expired verification token' 
        });
      }

      // Check if already verified
      if (user.rows[0].email_verified) {
        return res.json({ 
          success: true,
          message: 'Email already verified',
          alreadyVerified: true
        });
      }

      await pool.query(
        'UPDATE users SET email_verified = true, verification_token = NULL WHERE email = ?',
        [email]
      );

      res.json({ 
        success: true,
        message: 'Email verified successfully. You can now log in.',
        alreadyVerified: false
      });
    } catch (error) {
      console.error('Email verification error:', error);
      res.status(500).json({ 
        success: false,
        error: 'Verification failed' 
      });
    }
  }
);

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
