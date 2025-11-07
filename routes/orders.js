const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// Apply authentication middleware to all routes
router.use(authenticateToken);

// Get all orders for the authenticated user with filtering and sorting
router.get('/', async (req, res) => {
  try {
    const { 
      sortBy = 'created_at', 
      sortOrder = 'DESC', 
      search = '',
      status = '',
      isFavorite = ''
    } = req.query;

    // Validate sortBy to prevent SQL injection
    const validSortFields = ['id', 'created_at', 'total_amount', 'status', 'payment_status'];
    const sortField = validSortFields.includes(sortBy) ? sortBy : 'created_at';
    const order = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    let query = `
      SELECT 
        o.id,
        o.user_id,
        o.total_amount,
        o.status,
        o.payment_status,
        o.payment_intent_id,
        o.stripe_charge_id,
        o.tracking_number,
        o.is_favorite,
        o.created_at,
        o.updated_at,
        COUNT(oi.id) as item_count,
        GROUP_CONCAT(
          JSON_OBJECT(
            'id', oi.id,
            'product_id', oi.product_id,
            'quantity', oi.quantity,
            'price_at_purchase', oi.price_at_purchase,
            'product_name', p.name,
            'product_image', p.image_url
          )
        ) as items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ?
    `;

    const params = [req.user.userId];

    // Add status filter
    if (status) {
      query += ' AND o.status = ?';
      params.push(status);
    }

    // Add favorite filter
    if (isFavorite !== '') {
      query += ' AND o.is_favorite = ?';
      params.push(isFavorite === 'true' ? 1 : 0);
    }

    // Add search filter (search by order ID or tracking number)
    if (search) {
      query += ' AND (o.id LIKE ? OR o.tracking_number LIKE ?)';
      const searchTerm = `%${search}%`;
      params.push(searchTerm, searchTerm);
    }

    query += ` GROUP BY o.id ORDER BY o.${sortField} ${order}`;

    const result = await pool.query(query, params);

    // Parse the JSON items for each order
    const orders = result.rows.map(order => ({
      ...order,
      items: order.items ? JSON.parse(`[${order.items}]`) : [],
      is_favorite: order.is_favorite === 1 || order.is_favorite === true
    }));

    res.json({ orders });
  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

// Get a specific order by ID with full details
router.get('/:id', async (req, res) => {
  try {
    const orderId = req.params.id;

    // Get order details
    const orderResult = await pool.query(
      `SELECT * FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, req.user.userId]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const order = orderResult.rows[0];
    order.is_favorite = order.is_favorite === 1 || order.is_favorite === true;

    // Get order items with product details
    const itemsResult = await pool.query(
      `SELECT 
        oi.*,
        p.name as product_name,
        p.description as product_description,
        p.image_url as product_image,
        p.category as product_category
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?`,
      [orderId]
    );

    order.items = itemsResult.rows;

    res.json({ order });
  } catch (error) {
    console.error('Get order details error:', error);
    res.status(500).json({ error: 'Failed to fetch order details' });
  }
});

// Toggle favorite status for an order
router.patch('/:id/favorite', async (req, res) => {
  try {
    const orderId = req.params.id;
    const { isFavorite } = req.body;

    // Check if order belongs to user
    const checkResult = await pool.query(
      'SELECT id FROM orders WHERE id = ? AND user_id = ?',
      [orderId, req.user.userId]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    // Update favorite status
    await pool.query(
      'UPDATE orders SET is_favorite = ? WHERE id = ?',
      [isFavorite ? 1 : 0, orderId]
    );

    res.json({ 
      success: true, 
      message: isFavorite ? 'Order added to favorites' : 'Order removed from favorites' 
    });
  } catch (error) {
    console.error('Toggle favorite error:', error);
    res.status(500).json({ error: 'Failed to update favorite status' });
  }
});

// Delete an order
router.delete('/:id', async (req, res) => {
  try {
    const orderId = req.params.id;

    // Check if order belongs to user
    const checkResult = await pool.query(
      'SELECT id FROM orders WHERE id = ? AND user_id = ?',
      [orderId, req.user.userId]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    // Delete order (cascade will delete order_items)
    await pool.query('DELETE FROM orders WHERE id = ?', [orderId]);

    res.json({ success: true, message: 'Order deleted successfully' });
  } catch (error) {
    console.error('Delete order error:', error);
    res.status(500).json({ error: 'Failed to delete order' });
  }
});

// Get favorite orders
router.get('/favorites/list', async (req, res) => {
  try {
    const query = `
      SELECT 
        o.id,
        o.user_id,
        o.total_amount,
        o.status,
        o.payment_status,
        o.payment_intent_id,
        o.stripe_charge_id,
        o.tracking_number,
        o.is_favorite,
        o.created_at,
        o.updated_at,
        COUNT(oi.id) as item_count,
        GROUP_CONCAT(
          JSON_OBJECT(
            'id', oi.id,
            'product_id', oi.product_id,
            'quantity', oi.quantity,
            'price_at_purchase', oi.price_at_purchase,
            'product_name', p.name,
            'product_image', p.image_url
          )
        ) as items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE o.user_id = ? AND o.is_favorite = 1
      GROUP BY o.id
      ORDER BY o.created_at DESC
    `;

    const result = await pool.query(query, [req.user.userId]);

    const orders = result.rows.map(order => ({
      ...order,
      items: order.items ? JSON.parse(`[${order.items}]`) : [],
      is_favorite: true
    }));

    res.json({ orders });
  } catch (error) {
    console.error('Get favorite orders error:', error);
    res.status(500).json({ error: 'Failed to fetch favorite orders' });
  }
});

module.exports = router;
