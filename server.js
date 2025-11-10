const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const bodyParser = require('body-parser');
const path = require('path');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' })); // Increase limit for base64 images
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files from uploads directory
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const shoppingListRoutes = require('./routes/shoppingLists');
const paymentRoutes = require('./routes/payments');
const profileRoutes = require('./routes/profile');

// Email verification page at root level (email links use /verify, not /api/auth/verify)
app.get('/verify', async (req, res) => {
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
            
            // If app doesn't open, verify via API after 3 seconds
            setTimeout(function() {
              verifyViaAPI();
            }, 3000);
          }
          
          // Verify email via API (fallback for web browsers)
          async function verifyViaAPI() {
            try {
              document.getElementById('status').textContent = 'Verifying your email...';
              
              const response = await fetch('/api/auth/verify-email', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                  token: '${token}',
                  email: '${email}'
                })
              });
              
              const data = await response.json();
              
              document.getElementById('spinner').style.display = 'none';
              
              if (data.success) {
                document.getElementById('status').innerHTML = 
                  '<h2 style="color: #4CAF50;">✓ Email Verified Successfully!</h2>' +
                  '<p>Your email has been verified. You can now log in to the Smart Shop app.</p>';
                document.getElementById('manualButton').style.display = 'none';
              } else {
                document.getElementById('status').innerHTML = 
                  '<h2 style="color: #f44336;">✗ Verification Failed</h2>' +
                  '<p>' + (data.error || 'An error occurred during verification.') + '</p>';
                document.getElementById('manualButton').textContent = 'Try Opening App';
                document.getElementById('manualButton').style.display = 'block';
              }
            } catch (error) {
              document.getElementById('spinner').style.display = 'none';
              document.getElementById('status').innerHTML = 
                '<h2 style="color: #f44336;">✗ Connection Error</h2>' +
                '<p>Could not connect to the server. Please try again later.</p>';
              document.getElementById('manualButton').textContent = 'Try Opening App';
              document.getElementById('manualButton').style.display = 'block';
            }
          }
          
          // Auto-trigger on page load
          window.onload = function() {
            openApp();
          };
        </script>
      </head>
      <body>
        <div class="container">
          <h1>Email Verification</h1>
          <div id="spinner" class="spinner"></div>
          <p id="status">Attempting to open Smart Shop app... If the app doesn't open, we'll verify your email automatically.</p>
          <a id="manualButton" href="${deepLink}" class="button" style="display: none;">
            Open in Smart Shop App
          </a>
          <p style="font-size: 12px; color: #999; margin-top: 30px;">
            This verification link will expire in 24 hours.
          </p>
        </div>
      </body>
    </html>
  `);
});

app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/shopping-lists', shoppingListRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/profile', profileRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Smart Shop API is running',
    version: '1.0.0',
    database: 'MySQL',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      products: '/api/products',
      orders: '/api/orders',
      shoppingLists: '/api/shopping-lists',
      payments: '/api/payments',
      profile: '/api/profile'
    }
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Smart Shop API is running' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Smart Shop API server running on port ${PORT}`);
});

module.exports = app;
