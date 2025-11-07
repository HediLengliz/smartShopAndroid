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

app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/shopping-lists', shoppingListRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/profile', profileRoutes);

// Serve verification page (outside /api)
app.use('/verify', authRoutes);

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
