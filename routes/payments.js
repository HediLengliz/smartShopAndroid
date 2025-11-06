const express = require('express');
const { body, validationResult } = require('express-validator');
const stripe = require('../config/stripe');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken);

router.post('/create-payment-intent',
  [body('amount').isFloat({ min: 0.5 })],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    if (!stripe) {
      return res.status(503).json({ error: 'Payment service not configured' });
    }

    const { amount, currency = 'usd' } = req.body;

    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100),
        currency,
        metadata: {
          userId: req.user.userId.toString()
        }
      });

      res.json({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id
      });
    } catch (error) {
      console.error('Create payment intent error:', error);
      res.status(500).json({ error: 'Failed to create payment intent' });
    }
  }
);

router.post('/confirm-payment',
  [body('paymentIntentId').notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    if (!stripe) {
      return res.status(503).json({ error: 'Payment service not configured' });
    }

    const { paymentIntentId, orderId } = req.body;

    try {
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

      if (paymentIntent.status === 'succeeded') {
        if (orderId) {
          await pool.query(
            'UPDATE orders SET payment_status = ?, status = ?, stripe_charge_id = ?, updated_at = NOW() WHERE id = ? AND user_id = ?',
            ['completed', 'processing', paymentIntent.charges.data[0]?.id, orderId, req.user.userId]
          );
        }

        res.json({
          status: 'success',
          paymentIntent: {
            id: paymentIntent.id,
            status: paymentIntent.status,
            amount: paymentIntent.amount / 100
          }
        });
      } else {
        res.json({
          status: 'pending',
          paymentIntent: {
            id: paymentIntent.id,
            status: paymentIntent.status
          }
        });
      }
    } catch (error) {
      console.error('Confirm payment error:', error);
      res.status(500).json({ error: 'Failed to confirm payment' });
    }
  }
);

router.get('/methods', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM payment_methods WHERE user_id = ? ORDER BY is_default DESC, created_at DESC',
      [req.user.userId]
    );

    res.json({ paymentMethods: result.rows });
  } catch (error) {
    console.error('Get payment methods error:', error);
    res.status(500).json({ error: 'Failed to fetch payment methods' });
  }
});

router.post('/methods',
  [body('paymentMethodId').notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    if (!stripe) {
      return res.status(503).json({ error: 'Payment service not configured' });
    }

    const { paymentMethodId, isDefault = false } = req.body;

    try {
      const paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);

      if (paymentMethod.type === 'card') {
        if (isDefault) {
          await pool.query(
            'UPDATE payment_methods SET is_default = false WHERE user_id = ?',
            [req.user.userId]
          );
        }

        await pool.query(
          `INSERT INTO payment_methods (user_id, stripe_payment_method_id, card_brand, card_last4, card_exp_month, card_exp_year, is_default)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            req.user.userId,
            paymentMethodId,
            paymentMethod.card.brand,
            paymentMethod.card.last4,
            paymentMethod.card.exp_month,
            paymentMethod.card.exp_year,
            isDefault
          ]
        );

        const result = await pool.query(
          'SELECT * FROM payment_methods WHERE user_id = ? AND stripe_payment_method_id = ? ORDER BY id DESC LIMIT 1',
          [req.user.userId, paymentMethodId]
        );

        res.status(201).json({ paymentMethod: result.rows[0] });
      } else {
        res.status(400).json({ error: 'Only card payment methods are supported' });
      }
    } catch (error) {
      console.error('Save payment method error:', error);
      res.status(500).json({ error: 'Failed to save payment method' });
    }
  }
);

router.delete('/methods/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM payment_methods WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payment method not found' });
    }

    await pool.query(
      'DELETE FROM payment_methods WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    res.json({ message: 'Payment method deleted successfully' });
  } catch (error) {
    console.error('Delete payment method error:', error);
    res.status(500).json({ error: 'Failed to delete payment method' });
  }
});

module.exports = router;
