const Stripe = require('stripe');

const stripe = process.env.STRIPE_SECRET_KEY 
  ? new Stripe(process.env.STRIPE_SECRET_KEY)
  : null;

const publishableKey = process.env.STRIPE_PUBLISHABLE_KEY || '';

if (!stripe) {
  console.warn('Stripe API key not configured. Payment functionality will be limited.');
}

module.exports = { stripe, publishableKey };
