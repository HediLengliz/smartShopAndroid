const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');
const fs = require('fs');
const path = require('path');

const router = express.Router();

router.use(authenticateToken);

// Upload profile picture
router.post('/upload-picture', async (req, res) => {
  try {
    const { imageBase64 } = req.body;

    if (!imageBase64) {
      return res.status(400).json({ error: 'Image data is required' });
    }

    // Create uploads directory if it doesn't exist
    const uploadsDir = path.join(__dirname, '..', 'uploads', 'profiles');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    // Extract base64 data (remove data:image/png;base64, prefix if present)
    const base64Data = imageBase64.replace(/^data:image\/\w+;base64,/, '');
    const imageBuffer = Buffer.from(base64Data, 'base64');

    // Generate unique filename
    const filename = `profile_${req.user.userId}_${Date.now()}.jpg`;
    const filepath = path.join(uploadsDir, filename);

    // Save file
    fs.writeFileSync(filepath, imageBuffer);

    // Generate URL (adjust based on your server setup)
    const baseUrl = process.env.BASE_URL || 'http://localhost:3000';
    const imageUrl = `${baseUrl}/uploads/profiles/${filename}`;

    // Update user's profile picture URL
    await pool.query(
      'UPDATE users SET profile_picture_url = ?, updated_at = NOW() WHERE id = ?',
      [imageUrl, req.user.userId]
    );

    res.json({ 
      success: true,
      imageUrl,
      message: 'Profile picture uploaded successfully'
    });
  } catch (error) {
    console.error('Upload profile picture error:', error);
    res.status(500).json({ error: 'Failed to upload profile picture' });
  }
});

router.put('/',
  [
    body('firstName').optional().trim().notEmpty(),
    body('lastName').optional().trim().notEmpty(),
    body('phone').optional().trim()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { firstName, lastName, phone, profilePictureUrl } = req.body;

    try {
      const updates = [];
      const params = [];

      if (firstName !== undefined) {
        updates.push(`first_name = ?`);
        params.push(firstName);
      }

      if (lastName !== undefined) {
        updates.push(`last_name = ?`);
        params.push(lastName);
      }

      if (phone !== undefined) {
        updates.push(`phone = ?`);
        params.push(phone);
      }

      if (profilePictureUrl !== undefined) {
        updates.push(`profile_picture_url = ?`);
        params.push(profilePictureUrl);
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: 'No updates provided' });
      }

      updates.push('updated_at = NOW()');

      params.push(req.user.userId);

      const query = `UPDATE users SET ${updates.join(', ')} WHERE id = ?`;

      await pool.query(query, params);

      const result = await pool.query(
        'SELECT id, email, first_name, last_name, phone, profile_picture_url FROM users WHERE id = ?',
        [req.user.userId]
      );

      res.json({ user: result.rows[0] });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({ error: 'Failed to update profile' });
    }
  }
);

router.put('/password',
  [
    body('currentPassword').notEmpty(),
    body('newPassword').isLength({ min: 6 })
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { currentPassword, newPassword } = req.body;

    try {
      const userResult = await pool.query(
        'SELECT password_hash FROM users WHERE id = ?',
        [req.user.userId]
      );

      const user = userResult.rows[0];
      const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);

      if (!isValidPassword) {
        return res.status(401).json({ error: 'Current password is incorrect' });
      }

      const hashedPassword = await bcrypt.hash(newPassword, 10);

      await pool.query(
        'UPDATE users SET password_hash = ?, updated_at = NOW() WHERE id = ?',
        [hashedPassword, req.user.userId]
      );

      res.json({ message: 'Password updated successfully' });
    } catch (error) {
      console.error('Update password error:', error);
      res.status(500).json({ error: 'Failed to update password' });
    }
  }
);

router.get('/addresses', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, created_at DESC',
      [req.user.userId]
    );

    res.json({ addresses: result.rows });
  } catch (error) {
    console.error('Get addresses error:', error);
    res.status(500).json({ error: 'Failed to fetch addresses' });
  }
});

router.post('/addresses',
  [
    body('addressLine1').trim().notEmpty(),
    body('city').trim().notEmpty(),
    body('postalCode').trim().notEmpty(),
    body('country').trim().notEmpty()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { addressLine1, addressLine2, city, state, postalCode, country, isDefault = false } = req.body;

    try {
      if (isDefault) {
        await pool.query(
          'UPDATE addresses SET is_default = false WHERE user_id = ?',
          [req.user.userId]
        );
      }

      await pool.query(
        'INSERT INTO addresses (user_id, address_line1, address_line2, city, state, postal_code, country, is_default) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [req.user.userId, addressLine1, addressLine2, city, state, postalCode, country, isDefault]
      );

      const result = await pool.query(
        'SELECT * FROM addresses WHERE user_id = ? AND address_line1 = ? AND postal_code = ? ORDER BY id DESC LIMIT 1',
        [req.user.userId, addressLine1, postalCode]
      );

      res.status(201).json({ address: result.rows[0] });
    } catch (error) {
      console.error('Create address error:', error);
      res.status(500).json({ error: 'Failed to create address' });
    }
  }
);

router.put('/addresses/:id',
  [
    body('addressLine1').optional().trim().notEmpty(),
    body('city').optional().trim().notEmpty(),
    body('postalCode').optional().trim().notEmpty(),
    body('country').optional().trim().notEmpty()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { addressLine1, addressLine2, city, state, postalCode, country, isDefault } = req.body;

    try {
      if (isDefault) {
        await pool.query(
          'UPDATE addresses SET is_default = false WHERE user_id = ?',
          [req.user.userId]
        );
      }

      const updates = [];
      const params = [];

      if (addressLine1 !== undefined) {
        updates.push(`address_line1 = ?`);
        params.push(addressLine1);
      }

      if (addressLine2 !== undefined) {
        updates.push(`address_line2 = ?`);
        params.push(addressLine2);
      }

      if (city !== undefined) {
        updates.push(`city = ?`);
        params.push(city);
      }

      if (state !== undefined) {
        updates.push(`state = ?`);
        params.push(state);
      }

      if (postalCode !== undefined) {
        updates.push(`postal_code = ?`);
        params.push(postalCode);
      }

      if (country !== undefined) {
        updates.push(`country = ?`);
        params.push(country);
      }

      if (isDefault !== undefined) {
        updates.push(`is_default = ?`);
        params.push(isDefault);
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: 'No updates provided' });
      }

      params.push(id);
      params.push(req.user.userId);

      const query = `UPDATE addresses SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`;

      await pool.query(query, params);

      const result = await pool.query(
        'SELECT * FROM addresses WHERE id = ? AND user_id = ?',
        [id, req.user.userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Address not found' });
      }

      res.json({ address: result.rows[0] });
    } catch (error) {
      console.error('Update address error:', error);
      res.status(500).json({ error: 'Failed to update address' });
    }
  }
);

router.delete('/addresses/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM addresses WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Address not found' });
    }

    await pool.query(
      'DELETE FROM addresses WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    res.json({ message: 'Address deleted successfully' });
  } catch (error) {
    console.error('Delete address error:', error);
    res.status(500).json({ error: 'Failed to delete address' });
  }
});

router.delete('/account', async (req, res) => {
  try {
    await pool.query('DELETE FROM users WHERE id = ?', [req.user.userId]);

    res.json({ message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

router.get('/stats', async (req, res) => {
  try {
    const ordersCount = await pool.query(
      'SELECT COUNT(*) as total, SUM(total_amount) as total_spent FROM orders WHERE user_id = ?',
      [req.user.userId]
    );

    const listsCount = await pool.query(
      'SELECT COUNT(*) as count FROM shopping_lists WHERE user_id = ?',
      [req.user.userId]
    );

    res.json({
      ordersCount: parseInt(ordersCount.rows[0].total || 0),
      totalSpent: parseFloat(ordersCount.rows[0].total_spent || 0),
      shoppingListsCount: parseInt(listsCount.rows[0].count || 0)
    });
  } catch (error) {
    console.error('Get profile stats error:', error);
    res.status(500).json({ error: 'Failed to fetch profile statistics' });
  }
});

// Get user dashboard statistics
router.get('/dashboard', async (req, res) => {
  try {
    // Get most bought products
    const topProducts = await pool.query(
      `SELECT 
        p.id,
        p.name,
        p.image_url,
        p.price,
        p.category,
        SUM(oi.quantity) as total_quantity,
        COUNT(DISTINCT o.id) as order_count,
        SUM(oi.quantity * oi.price_at_purchase) as total_spent
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ?
      GROUP BY p.id, p.name, p.image_url, p.price, p.category
      ORDER BY total_quantity DESC
      LIMIT 10`,
      [req.user.userId]
    );

    // Get recent orders
    const recentOrders = await pool.query(
      `SELECT 
        id,
        total_amount,
        status,
        payment_status,
        created_at
      FROM orders
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 5`,
      [req.user.userId]
    );

    // Get spending by month (last 6 months)
    const spendingTrend = await pool.query(
      `SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as month,
        SUM(total_amount) as total,
        COUNT(*) as order_count
      FROM orders
      WHERE user_id = ? 
        AND created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
        AND payment_status IN ('paid', 'succeeded')
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')
      ORDER BY month ASC`,
      [req.user.userId]
    );

    // Get category breakdown
    const categoryBreakdown = await pool.query(
      `SELECT 
        p.category,
        COUNT(DISTINCT oi.id) as item_count,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.quantity * oi.price_at_purchase) as total_spent
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ? AND o.payment_status IN ('paid', 'succeeded')
      GROUP BY p.category
      ORDER BY total_spent DESC`,
      [req.user.userId]
    );

    // Get purchase timeline (orders per day for last 30 days)
    const purchaseTimeline = await pool.query(
      `SELECT 
        DATE(created_at) as date,
        COUNT(*) as order_count,
        SUM(total_amount) as daily_total
      FROM orders
      WHERE user_id = ? 
        AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
      GROUP BY DATE(created_at)
      ORDER BY date ASC`,
      [req.user.userId]
    );

    // Overall statistics
    const overallStats = await pool.query(
      `SELECT 
        COUNT(*) as total_orders,
        SUM(total_amount) as total_spent,
        AVG(total_amount) as avg_order_value,
        MAX(total_amount) as highest_order,
        MIN(total_amount) as lowest_order
      FROM orders
      WHERE user_id = ? AND payment_status IN ('paid', 'succeeded')`,
      [req.user.userId]
    );

    res.json({
      topProducts: topProducts.rows.map(row => ({
        ...row,
        total_quantity: parseInt(row.total_quantity || 0),
        order_count: parseInt(row.order_count || 0),
        total_spent: parseFloat(row.total_spent || 0),
        price: parseFloat(row.price || 0)
      })),
      recentOrders: recentOrders.rows,
      spendingTrend: spendingTrend.rows.map(row => ({
        month: row.month,
        total: parseFloat(row.total || 0),
        order_count: parseInt(row.order_count || 0)
      })),
      categoryBreakdown: categoryBreakdown.rows.map(row => ({
        category: row.category || 'Other',
        item_count: parseInt(row.item_count || 0),
        total_quantity: parseInt(row.total_quantity || 0),
        total_spent: parseFloat(row.total_spent || 0)
      })),
      purchaseTimeline: purchaseTimeline.rows.map(row => ({
        date: row.date,
        order_count: parseInt(row.order_count || 0),
        daily_total: parseFloat(row.daily_total || 0)
      })),
      overallStats: {
        total_orders: parseInt(overallStats.rows[0]?.total_orders || 0),
        total_spent: parseFloat(overallStats.rows[0]?.total_spent || 0),
        avg_order_value: parseFloat(overallStats.rows[0]?.avg_order_value || 0),
        highest_order: parseFloat(overallStats.rows[0]?.highest_order || 0),
        lowest_order: parseFloat(overallStats.rows[0]?.lowest_order || 0)
      }
    });
  } catch (error) {
    console.error('Get dashboard error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard data' });
  }
});

// Delete user account
router.delete('/account', async (req, res) => {
  try {
    const userId = req.user.userId;

    // Check if user exists
    const userCheck = await pool.query(
      'SELECT id, email FROM users WHERE id = ?',
      [userId]
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Delete user (cascade will delete related records)
    await pool.query('DELETE FROM users WHERE id = ?', [userId]);

    res.json({ 
      success: true, 
      message: 'Account deleted successfully' 
    });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

// Get product purchase analytics
router.get('/analytics/products', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { limit = 10, sortBy = 'most' } = req.query;

    // Get most/least bought products with purchase history
    const sortOrder = sortBy === 'least' ? 'ASC' : 'DESC';
    
    const productsQuery = `
      SELECT 
        p.id,
        p.name,
        p.description,
        p.price,
        p.image_url,
        p.category,
        COUNT(oi.id) as purchase_count,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.quantity * oi.price_at_purchase) as total_spent,
        MAX(o.created_at) as last_purchased,
        MIN(o.created_at) as first_purchased,
        GROUP_CONCAT(
          JSON_OBJECT(
            'order_id', o.id,
            'quantity', oi.quantity,
            'price', oi.price_at_purchase,
            'date', o.created_at
          )
          ORDER BY o.created_at DESC
        ) as purchase_history
      FROM order_items oi
      INNER JOIN orders o ON oi.order_id = o.id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ? AND o.payment_status IN ('paid', 'succeeded')
      GROUP BY p.id, p.name, p.description, p.price, p.image_url, p.category
      ORDER BY purchase_count ${sortOrder}, total_quantity ${sortOrder}
      LIMIT ?
    `;

    const productsResult = await pool.query(productsQuery, [userId, parseInt(limit)]);

    const products = productsResult.rows.map(product => ({
      ...product,
      purchase_count: parseInt(product.purchase_count),
      total_quantity: parseInt(product.total_quantity),
      total_spent: parseFloat(product.total_spent),
      purchase_history: product.purchase_history 
        ? JSON.parse(`[${product.purchase_history}]`)
        : []
    }));

    // Get category statistics
    const categoryStats = await pool.query(
      `SELECT 
        p.category,
        COUNT(DISTINCT oi.id) as purchase_count,
        SUM(oi.quantity) as total_items,
        SUM(oi.quantity * oi.price_at_purchase) as total_spent
      FROM order_items oi
      INNER JOIN orders o ON oi.order_id = o.id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ? AND o.payment_status IN ('paid', 'succeeded')
      GROUP BY p.category
      ORDER BY total_spent DESC`,
      [userId]
    );

    // Get monthly purchase trends
    const monthlyTrends = await pool.query(
      `SELECT 
        DATE_FORMAT(o.created_at, '%Y-%m') as month,
        COUNT(DISTINCT o.id) as order_count,
        SUM(oi.quantity) as items_bought,
        SUM(oi.quantity * oi.price_at_purchase) as total_spent
      FROM orders o
      INNER JOIN order_items oi ON o.id = oi.order_id
      WHERE o.user_id = ? AND o.payment_status IN ('paid', 'succeeded')
      GROUP BY DATE_FORMAT(o.created_at, '%Y-%m')
      ORDER BY month DESC
      LIMIT 12`,
      [userId]
    );

    res.json({
      products,
      categoryStats: categoryStats.rows.map(cat => ({
        category: cat.category || 'Uncategorized',
        purchase_count: parseInt(cat.purchase_count),
        total_items: parseInt(cat.total_items),
        total_spent: parseFloat(cat.total_spent)
      })),
      monthlyTrends: monthlyTrends.rows.map(trend => ({
        month: trend.month,
        order_count: parseInt(trend.order_count),
        items_bought: parseInt(trend.items_bought),
        total_spent: parseFloat(trend.total_spent)
      }))
    });
  } catch (error) {
    console.error('Get product analytics error:', error);
    res.status(500).json({ error: 'Failed to fetch product analytics' });
  }
});

// Get latest orders for profile
router.get('/latest-orders', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { limit = 5 } = req.query;

    const ordersQuery = `
      SELECT 
        o.id,
        o.total_amount,
        o.status,
        o.payment_status,
        o.created_at,
        COUNT(oi.id) as item_count,
        GROUP_CONCAT(
          JSON_OBJECT(
            'product_name', p.name,
            'quantity', oi.quantity,
            'image_url', p.image_url
          )
        ) as items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ?
      GROUP BY o.id
      ORDER BY o.created_at DESC
      LIMIT ?
    `;

    const result = await pool.query(ordersQuery, [userId, parseInt(limit)]);

    const orders = result.rows.map(order => ({
      ...order,
      item_count: parseInt(order.item_count),
      total_amount: parseFloat(order.total_amount),
      items: order.items ? JSON.parse(`[${order.items}]`) : []
    }));

    res.json({ orders });
  } catch (error) {
    console.error('Get latest orders error:', error);
    res.status(500).json({ error: 'Failed to fetch latest orders' });
  }
});

module.exports = router;
