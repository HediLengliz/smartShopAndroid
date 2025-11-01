const express = require('express');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.get('/', async (req, res) => {
  const { category, search, limit = 50, offset = 0 } = req.query;

  try {
    let query = 'SELECT * FROM products WHERE is_active = true';
    const params = [];

    if (category) {
      query += ' AND category = ?';
      params.push(category);
    }

    if (search) {
      query += ' AND (LOWER(name) LIKE ? OR LOWER(description) LIKE ?)';
      const searchPattern = `%${search.toLowerCase()}%`;
      params.push(searchPattern, searchPattern);
    }

    query += ' ORDER BY name';
    
    query += ' LIMIT ?';
    params.push(parseInt(limit));
    
    query += ' OFFSET ?';
    params.push(parseInt(offset));

    const result = await pool.query(query, params);

    const countQuery = 'SELECT COUNT(*) as count FROM products WHERE is_active = true';
    const countResult = await pool.query(countQuery);

    res.json({
      products: result.rows,
      total: parseInt(countResult.rows[0].count),
      limit: parseInt(limit),
      offset: parseInt(offset)
    });
  } catch (error) {
    console.error('Get products error:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

router.get('/categories', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT DISTINCT category FROM products WHERE is_active = true AND category IS NOT NULL ORDER BY category'
    );

    res.json({ categories: result.rows.map(row => row.category) });
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('SELECT * FROM products WHERE id = ? AND is_active = true', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get product error:', error);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

module.exports = router;
