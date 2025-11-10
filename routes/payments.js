const express = require('express');
const { body, validationResult } = require('express-validator');
const { stripe, publishableKey } = require('../config/stripe');
const { sendEmail } = require('../config/email');
const pool = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken);

// Helper function to get or create Stripe customer
async function getOrCreateStripeCustomer(userId, email, firstName, lastName) {
  try {
    // Get user from database
    const userResult = await pool.query(
      'SELECT stripe_customer_id, email, first_name, last_name FROM users WHERE id = ?',
      [userId]
    );

    if (userResult.rows.length === 0) {
      throw new Error('User not found');
    }

    const user = userResult.rows[0];

    // If user already has a Stripe customer ID, return it
    if (user.stripe_customer_id) {
      try {
        const customer = await stripe.customers.retrieve(user.stripe_customer_id);
        if (customer && !customer.deleted) {
          return customer.id;
        }
      } catch (error) {
        // Customer doesn't exist in Stripe, create a new one
        console.log('Stripe customer not found, creating new one');
      }
    }

    // Create new Stripe customer
    const customer = await stripe.customers.create({
      email: email || user.email,
      name: `${user.first_name || firstName || ''} ${user.last_name || lastName || ''}`.trim(),
      metadata: {
        userId: userId.toString(),
      },
    });

    // Save Stripe customer ID to database
    await pool.query(
      'UPDATE users SET stripe_customer_id = ? WHERE id = ?',
      [customer.id, userId]
    );

    return customer.id;
  } catch (error) {
    console.error('Error getting/creating Stripe customer:', error);
    throw error;
  }
}

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

// Get Stripe publishable key for client-side use
router.get('/setup-intent', async (req, res) => {
  console.log('Setup intent request from user:', req.user?.userId);
  
  if (!stripe) {
    console.error('Stripe not configured');
    return res.status(503).json({ error: 'Payment service not configured' });
  }

  if (!publishableKey) {
    console.error('Stripe publishable key not configured');
    return res.status(503).json({ error: 'Stripe publishable key not configured' });
  }

  try {
    // Get or create Stripe customer
    const userResult = await pool.query(
      'SELECT email, first_name, last_name FROM users WHERE id = ?',
      [req.user.userId]
    );

    console.log('User query result:', userResult.rows.length, 'rows');

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];
    console.log('Creating customer for user:', user.email);
    
    const customerId = await getOrCreateStripeCustomer(
      req.user.userId,
      user.email,
      user.first_name,
      user.last_name
    );

    console.log('Customer ID:', customerId);

    // Create SetupIntent for saving payment method
    // Use automatic_payment_methods with allow_redirects: never to avoid redirect issues
    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
      automatic_payment_methods: {
        enabled: true,
        allow_redirects: 'never',
      },
    });

    console.log('SetupIntent created:', setupIntent.id);

    res.json({
      clientSecret: setupIntent.client_secret,
      publishableKey: publishableKey,
    });
  } catch (error) {
    console.error('Setup intent error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      error: 'Failed to create setup intent',
      message: error.message 
    });
  }
});

// Save payment method (created client-side using Stripe SDK)
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
      // Retrieve payment method from Stripe
      const paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);

      if (paymentMethod.type !== 'card') {
        return res.status(400).json({ error: 'Only card payment methods are supported' });
      }

      // Get or create Stripe customer
      const userResult = await pool.query(
        'SELECT email, first_name, last_name FROM users WHERE id = ?',
        [req.user.userId]
      );

      if (userResult.rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }

      const user = userResult.rows[0];
      const customerId = await getOrCreateStripeCustomer(
        req.user.userId,
        user.email,
        user.first_name,
        user.last_name
      );

      // Attach payment method to customer
      await stripe.paymentMethods.attach(paymentMethodId, {
        customer: customerId,
      });

      // Check if payment method already exists
      const existing = await pool.query(
        'SELECT * FROM payment_methods WHERE stripe_payment_method_id = ?',
        [paymentMethodId]
      );

      if (existing.rows.length > 0) {
        return res.status(400).json({ error: 'Payment method already exists' });
      }

      // Set as default if requested
      if (isDefault) {
        await pool.query(
          'UPDATE payment_methods SET is_default = false WHERE user_id = ?',
          [req.user.userId]
        );
      }

      // Save payment method to database
      await pool.query(
        `INSERT INTO payment_methods (user_id, stripe_payment_method_id, stripe_customer_id, card_brand, card_last4, card_exp_month, card_exp_year, card_holder_name, is_default)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          req.user.userId,
          paymentMethodId,
          customerId,
          paymentMethod.card.brand,
          paymentMethod.card.last4,
          paymentMethod.card.exp_month,
          paymentMethod.card.exp_year,
          paymentMethod.billing_details?.name || null,
          isDefault
        ]
      );

      const result = await pool.query(
        'SELECT * FROM payment_methods WHERE user_id = ? AND stripe_payment_method_id = ? ORDER BY id DESC LIMIT 1',
        [req.user.userId, paymentMethodId]
      );

      res.status(201).json({ paymentMethod: result.rows[0] });
    } catch (error) {
      console.error('Save payment method error:', error);
      res.status(500).json({ error: error.message || 'Failed to save payment method' });
    }
  }
);

router.patch('/methods/:id/default', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM payment_methods WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payment method not found' });
    }

    // Set all payment methods to not default
    await pool.query(
      'UPDATE payment_methods SET is_default = false WHERE user_id = ?',
      [req.user.userId]
    );

    // Set this payment method as default
    await pool.query(
      'UPDATE payment_methods SET is_default = true WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    const updated = await pool.query(
      'SELECT * FROM payment_methods WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    res.json({ paymentMethod: updated.rows[0] });
  } catch (error) {
    console.error('Set default payment method error:', error);
    res.status(500).json({ error: 'Failed to set default payment method' });
  }
});

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

router.post('/checkout',
  [
    body('paymentMethodId').notEmpty(),
    body('amount').isFloat({ min: 0.5 }),
    body('currency').optional().isString().isLength({ min: 3, max: 10 }),
    body('items').isArray({ min: 1 })
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('Checkout validation errors:', errors.array());
      return res.status(400).json({ errors: errors.array() });
    }

    if (!stripe) {
      return res.status(503).json({ error: 'Payment service not configured' });
    }

    const {
      paymentMethodId,
      amount,
      currency = 'usd',
      items = [],
      notes = '',
    } = req.body;

    console.log('Checkout request:', {
      paymentMethodId,
      amount,
      currency,
      itemsCount: items.length,
      userId: req.user.userId
    });

    try {
      const userResult = await pool.query(
        'SELECT id, email, first_name, last_name FROM users WHERE id = ?',
        [req.user.userId]
      );

      if (userResult.rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }

      const user = userResult.rows[0];
      const customerId = await getOrCreateStripeCustomer(
        req.user.userId,
        user.email,
        user.first_name,
        user.last_name
      );

      const numericAmount = parseFloat(amount);
      if (Number.isNaN(numericAmount) || numericAmount <= 0) {
        return res.status(400).json({ error: 'Invalid amount provided' });
      }

      const paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);

      // Create PaymentIntent without automatic_payment_methods to use specific payment method
      // and provide return_url for redirect-based payment methods
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(numericAmount * 100),
        currency,
        customer: customerId,
        payment_method: paymentMethodId,
        confirm: true,
        off_session: false,
        receipt_email: user.email,
        return_url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/payment-complete`,
        metadata: {
          userId: req.user.userId.toString(),
          email: user.email,
        },
      });

      const paymentStatus = paymentIntent.status;
      const charge = paymentIntent.charges?.data?.[0] || null;

      const orderStatus = paymentStatus === 'succeeded' ? 'completed' : 'pending';
      const paymentState = paymentStatus === 'succeeded' ? 'paid' : paymentStatus;

      const orderResult = await pool.query(
        `INSERT INTO orders (user_id, total_amount, status, payment_status, payment_intent_id, stripe_charge_id)
         VALUES (?, ?, ?, ?, ?, ?)` ,
        [
          req.user.userId,
          numericAmount,
          orderStatus,
          paymentState,
          paymentIntent.id,
          charge ? charge.id : null,
        ]
      );

      let orderId = orderResult.rows?.insertId;
      if (!orderId && Array.isArray(orderResult.rows) && orderResult.rows.length > 0) {
        orderId = orderResult.rows[0].insertId;
      }

      if (!orderId) {
        const lastInsert = await pool.query('SELECT LAST_INSERT_ID() AS id');
        orderId = lastInsert.rows?.[0]?.id;
      }

      if (!orderId) {
        throw new Error('Failed to determine order ID');
      }

      for (const item of items) {
        const quantity = parseInt(item.quantity, 10) || 1;
        const price = parseFloat(item.price) || 0;
        await pool.query(
          `INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
           VALUES (?, ?, ?, ?)` ,
          [orderId, item.productId || null, quantity, price]
        );
      }

      const orderDetailsResult = await pool.query(
        'SELECT id, total_amount, status, payment_status, created_at, updated_at FROM orders WHERE id = ? LIMIT 1',
        [orderId]
      );
      const orderDetails = orderDetailsResult.rows?.[0] || {};

      const orderTimestamp = orderDetails.created_at
        ? new Date(orderDetails.created_at).toISOString()
        : new Date().toISOString();

      const receiptData = {
        order: {
          id: orderId,
          totalAmount: numericAmount,
          currency,
          status: orderStatus,
          createdAt: orderTimestamp,
          updatedAt: orderDetails.updated_at || null,
          notes,
          balanceDue: Math.max(0, numericAmount - paymentIntent.amount_received / 100),
        },
        customer: {
          email: user.email,
          firstName: user.first_name,
          lastName: user.last_name,
        },
        payment: {
          intentId: paymentIntent.id,
          status: paymentStatus,
          amount: paymentIntent.amount / 100,
          currency: paymentIntent.currency,
          method: {
            brand: paymentMethod.card?.brand || 'card',
            last4: paymentMethod.card?.last4 || '****',
            expMonth: paymentMethod.card?.exp_month,
            expYear: paymentMethod.card?.exp_year,
          },
          receiptUrl: charge?.receipt_url || null,
        },
        items,
      };

      const currencyUpper = currency.toUpperCase();
      const formatMoney = (value) => {
        return new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: currencyUpper,
        }).format(value);
      };

      const itemsRows = items.map((item) => `
        <tr>
          <td style="padding:8px;border:1px solid #eee;">${item.name}</td>
          <td style="padding:8px;border:1px solid #eee;text-align:center;">${item.quantity}</td>
          <td style="padding:8px;border:1px solid #eee;text-align:right;">${formatMoney(item.price)}</td>
          <td style="padding:8px;border:1px solid #eee;text-align:right;">${formatMoney(item.price * item.quantity)}</td>
        </tr>
      `).join('');

      const emailHtml = `
        <div style="font-family: Arial, sans-serif; padding: 24px; color: #333;">
          <h2 style="color:#ff9800;">SmartShop Payment Receipt</h2>
          <p>Hi ${user.first_name || ''} ${user.last_name || ''},</p>
          <p>Thank you for your purchase! Here is your payment receipt.</p>
          <div style="margin:20px 0;">
            <strong>Order ID:</strong> #${orderId}<br />
            <strong>Date:</strong> ${new Date(orderTimestamp).toLocaleString()}<br />
            <strong>Status:</strong> ${orderStatus}<br />
          </div>
          <table style="width:100%;border-collapse:collapse;margin-bottom:20px;">
            <thead>
              <tr style="background:#f5f5f5;">
                <th style="padding:8px;border:1px solid #eee;text-align:left;">Item</th>
                <th style="padding:8px;border:1px solid #eee;">Qty</th>
                <th style="padding:8px;border:1px solid #eee;text-align:right;">Unit Price</th>
                <th style="padding:8px;border:1px solid #eee;text-align:right;">Total</th>
              </tr>
            </thead>
            <tbody>
              ${itemsRows}
            </tbody>
          </table>
          <div style="text-align:right;margin-bottom:24px;">
            <strong>Total Paid:</strong> ${formatMoney(numericAmount)}
          </div>
          <div style="margin-top:24px;">
            <p><strong>Payment Method:</strong> ${receiptData.payment.method.brand?.toUpperCase()} •••• ${receiptData.payment.method.last4}</p>
            <p><strong>Receipt URL:</strong> ${receiptData.payment.receiptUrl ? `<a href="${receiptData.payment.receiptUrl}">View Receipt</a>` : 'Not available'}</p>
          </div>
          <p style="margin-top:32px;">If you have any questions, please contact our support team.</p>
          <p>— SmartShop Team</p>
        </div>
      `;

      sendEmail(user.email, 'Your SmartShop Payment Receipt', emailHtml)
        .catch((err) => {
          console.error('Failed to send receipt email:', err);
        });

      res.json({
        success: true,
        receipt: receiptData,
      });
    } catch (error) {
      console.error('Checkout error:', error);
      console.error('Error details:', {
        message: error.message,
        type: error.type,
        code: error.code,
        stack: error.stack
      });
      res.status(500).json({ 
        error: error.message || 'Failed to process checkout',
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });
    }
  }
);

module.exports = router;
