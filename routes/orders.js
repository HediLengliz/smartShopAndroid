const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const { status, limit = 20, offset = 0 } = req.query;

  try {
    let query = `
      SELECT o.*, a.address_line1, a.city, a.state, a.postal_code,
        COUNT(oi.id) as item_count
      FROM orders o
      LEFT JOIN addresses a ON o.address_id = a.id
      LEFT JOIN order_items oi ON o.id = oi.order_id
      WHERE o.user_id = ?
    `;
    const params = [req.user.userId];

    if (status) {
      query += ` AND o.status = ?`;
      params.push(status);
    }

    query += ' GROUP BY o.id, a.id ORDER BY o.created_at DESC';
    
    query += ` LIMIT ?`;
    params.push(parseInt(limit));
    
    query += ` OFFSET ?`;
    params.push(parseInt(offset));

    const result = await pool.query(query, params);

    res.json({ orders: result.rows });
  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const orderResult = await pool.query(
      `SELECT o.*, a.address_line1, a.address_line2, a.city, a.state, a.postal_code, a.country
       FROM orders o
       LEFT JOIN addresses a ON o.address_id = a.id
       WHERE o.id = ? AND o.user_id = ?`,
      [id, req.user.userId]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const itemsResult = await pool.query(
      `SELECT oi.*, p.name as product_name, p.image_url
       FROM order_items oi
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE oi.order_id = ?
       ORDER BY oi.id`,
      [id]
    );

    res.json({
      order: orderResult.rows[0],
      items: itemsResult.rows
    });
  } catch (error) {
    console.error('Get order error:', error);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

router.post('/',
  [
    body('addressId').isInt(),
    body('items').isArray({ min: 1 }),
    body('items.*.productId').isInt(),
    body('items.*.quantity').isInt({ min: 1 })
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { addressId, items, paymentIntentId } = req.body;

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const addressCheck = await connection.execute(
        'SELECT * FROM addresses WHERE id = ? AND user_id = ?',
        [addressId, req.user.userId]
      );

      if (addressCheck[0].length === 0) {
        throw new Error('Address not found');
      }

      let totalAmount = 0;
      const productPrices = new Map();

      for (const item of items) {
        const productResult = await connection.execute(
          'SELECT id, price, stock_quantity FROM products WHERE id = ? AND is_active = true',
          [item.productId]
        );

        if (productResult[0].length === 0) {
          throw new Error(`Product ${item.productId} not found`);
        }

        const product = productResult[0][0];

        if (product.stock_quantity < item.quantity) {
          throw new Error(`Insufficient stock for product ${item.productId}`);
        }

        const itemTotal = parseFloat(product.price) * item.quantity;
        totalAmount += itemTotal;
        productPrices.set(item.productId, product.price);
      }

      await connection.execute(
        `INSERT INTO orders (user_id, address_id, total_amount, payment_intent_id, status, payment_status)
         VALUES (?, ?, ?, ?, 'pending', 'pending')`,
        [req.user.userId, addressId, totalAmount, paymentIntentId]
      );

      const [orderResult] = await connection.execute(
        'SELECT * FROM orders WHERE user_id = ? AND address_id = ? AND payment_intent_id = ? ORDER BY id DESC LIMIT 1',
        [req.user.userId, addressId, paymentIntentId]
      );

      const order = orderResult[0];

      for (const item of items) {
        await connection.execute(
          'INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES (?, ?, ?, ?)',
          [order.id, item.productId, item.quantity, productPrices.get(item.productId)]
        );

        await connection.execute(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.productId]
        );
      }

      await connection.commit();

      res.status(201).json({ order });
    } catch (error) {
      await connection.rollback();
      console.error('Create order error:', error);
      res.status(500).json({ error: error.message || 'Failed to create order' });
    } finally {
      connection.release();
    }
  }
);

router.patch('/:id/status',
  [body('status').isIn(['pending', 'processing', 'shipped', 'delivered', 'cancelled'])],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { status, trackingNumber } = req.body;

    try {
      const updates = ['status = ?', 'updated_at = NOW()'];
      const params = [status];

      if (trackingNumber) {
        updates.push(`tracking_number = ?`);
        params.push(trackingNumber);
      }

      params.push(id);
      params.push(req.user.userId);

      const query = `UPDATE orders SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`;

      await pool.query(query, params);

      const result = await pool.query(
        'SELECT * FROM orders WHERE id = ? AND user_id = ?',
        [id, req.user.userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Order not found' });
      }

      res.json({ order: result.rows[0] });
    } catch (error) {
      console.error('Update order status error:', error);
      res.status(500).json({ error: 'Failed to update order status' });
    }
  }
);

module.exports = router;
