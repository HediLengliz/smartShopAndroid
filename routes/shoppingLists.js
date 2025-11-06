const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sl.*, 
        COUNT(sli.id) as item_count,
        COUNT(CASE WHEN sli.is_purchased = true THEN 1 END) as purchased_count
       FROM shopping_lists sl
       LEFT JOIN shopping_list_items sli ON sl.id = sli.list_id
       WHERE sl.user_id = ?
       GROUP BY sl.id
       ORDER BY sl.updated_at DESC`,
      [req.user.userId]
    );

    res.json({ lists: result.rows });
  } catch (error) {
    console.error('Get shopping lists error:', error);
    res.status(500).json({ error: 'Failed to fetch shopping lists' });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const listResult = await pool.query(
      'SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    if (listResult.rows.length === 0) {
      return res.status(404).json({ error: 'Shopping list not found' });
    }

    const itemsResult = await pool.query(
      `SELECT sli.*, p.name as product_name, p.price, p.image_url
       FROM shopping_list_items sli
       JOIN products p ON sli.product_id = p.id
       WHERE sli.list_id = ?
       ORDER BY sli.position, sli.created_at`,
      [id]
    );

    res.json({
      list: listResult.rows[0],
      items: itemsResult.rows
    });
  } catch (error) {
    console.error('Get shopping list error:', error);
    res.status(500).json({ error: 'Failed to fetch shopping list' });
  }
});

router.post('/',
  [body('name').trim().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name } = req.body;

    try {
      await pool.query(
        'INSERT INTO shopping_lists (user_id, name) VALUES (?, ?)',
        [req.user.userId, name]
      );

      const result = await pool.query(
        'SELECT * FROM shopping_lists WHERE user_id = ? AND name = ? ORDER BY id DESC LIMIT 1',
        [req.user.userId, name]
      );

      res.status(201).json({ list: result.rows[0] });
    } catch (error) {
      console.error('Create shopping list error:', error);
      res.status(500).json({ error: 'Failed to create shopping list' });
    }
  }
);

router.put('/:id',
  [body('name').trim().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { name } = req.body;

    try {
      await pool.query(
        'UPDATE shopping_lists SET name = ?, updated_at = NOW() WHERE id = ? AND user_id = ?',
        [name, id, req.user.userId]
      );

      const result = await pool.query(
        'SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?',
        [id, req.user.userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Shopping list not found' });
      }

      res.json({ list: result.rows[0] });
    } catch (error) {
      console.error('Update shopping list error:', error);
      res.status(500).json({ error: 'Failed to update shopping list' });
    }
  }
);

router.delete('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Shopping list not found' });
    }

    await pool.query(
      'DELETE FROM shopping_lists WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    res.json({ message: 'Shopping list deleted successfully' });
  } catch (error) {
    console.error('Delete shopping list error:', error);
    res.status(500).json({ error: 'Failed to delete shopping list' });
  }
});

router.post('/:id/items',
  [
    body('productId').isInt(),
    body('quantity').optional().isInt({ min: 1 })
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { productId, quantity = 1 } = req.body;

    try {
      const listCheck = await pool.query(
        'SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?',
        [id, req.user.userId]
      );

      if (listCheck.rows.length === 0) {
        return res.status(404).json({ error: 'Shopping list not found' });
      }

      const existingItem = await pool.query(
        'SELECT * FROM shopping_list_items WHERE list_id = ? AND product_id = ?',
        [id, productId]
      );

      let result;
      if (existingItem.rows.length > 0) {
        await pool.query(
          'UPDATE shopping_list_items SET quantity = quantity + ? WHERE list_id = ? AND product_id = ?',
          [quantity, id, productId]
        );

        result = await pool.query(
          'SELECT * FROM shopping_list_items WHERE list_id = ? AND product_id = ?',
          [id, productId]
        );
      } else {
        await pool.query(
          'INSERT INTO shopping_list_items (list_id, product_id, quantity) VALUES (?, ?, ?)',
          [id, productId, quantity]
        );

        result = await pool.query(
          'SELECT * FROM shopping_list_items WHERE list_id = ? AND product_id = ?',
          [id, productId]
        );
      }

      await pool.query(
        'UPDATE shopping_lists SET updated_at = NOW() WHERE id = ?',
        [id]
      );

      res.status(201).json({ item: result.rows[0] });
    } catch (error) {
      console.error('Add item to shopping list error:', error);
      res.status(500).json({ error: 'Failed to add item to shopping list' });
    }
  }
);

router.put('/:listId/items/:itemId', async (req, res) => {
  const { listId, itemId } = req.params;
  const { quantity, isPurchased, position } = req.body;

  try {
    const listCheck = await pool.query(
      'SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?',
      [listId, req.user.userId]
    );

    if (listCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Shopping list not found' });
    }

    let query = 'UPDATE shopping_list_items SET';
    const params = [];
    const updates = [];

    if (quantity !== undefined) {
      updates.push(`quantity = ?`);
      params.push(quantity);
    }

    if (isPurchased !== undefined) {
      updates.push(`is_purchased = ?`);
      params.push(isPurchased);
    }

    if (position !== undefined) {
      updates.push(`position = ?`);
      params.push(position);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No updates provided' });
    }

    query += ' ' + updates.join(', ');
    
    query += ` WHERE id = ?`;
    params.push(itemId);
    
    query += ` AND list_id = ?`;
    params.push(listId);

    await pool.query(query, params);

    const result = await pool.query(
      'SELECT * FROM shopping_list_items WHERE id = ? AND list_id = ?',
      [itemId, listId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }

    await pool.query(
      'UPDATE shopping_lists SET updated_at = NOW() WHERE id = ?',
      [listId]
    );

    res.json({ item: result.rows[0] });
  } catch (error) {
    console.error('Update shopping list item error:', error);
    res.status(500).json({ error: 'Failed to update item' });
  }
});

router.delete('/:listId/items/:itemId', async (req, res) => {
  const { listId, itemId } = req.params;

  try {
    const listCheck = await pool.query(
      'SELECT * FROM shopping_lists WHERE id = ? AND user_id = ?',
      [listId, req.user.userId]
    );

    if (listCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Shopping list not found' });
    }

    const result = await pool.query(
      'SELECT * FROM shopping_list_items WHERE id = ? AND list_id = ?',
      [itemId, listId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }

    await pool.query(
      'DELETE FROM shopping_list_items WHERE id = ? AND list_id = ?',
      [itemId, listId]
    );

    await pool.query(
      'UPDATE shopping_lists SET updated_at = NOW() WHERE id = ?',
      [listId]
    );

    res.json({ message: 'Item removed from shopping list' });
  } catch (error) {
    console.error('Delete shopping list item error:', error);
    res.status(500).json({ error: 'Failed to remove item' });
  }
});

module.exports = router;
