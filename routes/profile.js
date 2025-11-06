const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken);

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

module.exports = router;
