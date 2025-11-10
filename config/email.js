// This module sends emails via SMTP (Gmail with App Password or other SMTP servers)
// It exposes sendEmail(to, subject, html) and returns an object { success: boolean, ... }

const provider = 'smtp';

// Send using SMTP via nodemailer (Gmail with App Password or other SMTP)
const sendWithSmtp = async (to, subject, html) => {
  let nodemailer;
  try {
    nodemailer = require('nodemailer');
  } catch (err) {
    return { success: false, error: 'nodemailer package not installed' };
  }

  const host = process.env.SMTP_HOST;
  const port = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : undefined;
  const secure = (process.env.SMTP_SECURE || 'false').toLowerCase() === 'true';
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM || process.env.MAIL_FROM_EMAIL || process.env.SENDGRID_FROM_EMAIL || 'noreply@smartshop.com';

  if (!host || !port) {
    return { success: false, error: 'SMTP_HOST and SMTP_PORT must be configured for SMTP provider' };
  }

  const transportOptions = {
    host,
    port,
    secure,
  };

  if (user || pass) {
    transportOptions.auth = { user, pass };
  }

  const transporter = nodemailer.createTransport(transportOptions);

  const mailOptions = {
    from,
    to,
    subject,
    html,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`Email sent (SMTP) to ${to}, messageId=${info.messageId}`);
    return { success: true, info };
  } catch (error) {
    console.error('Error sending email (SMTP):', error);
    return { success: false, error: error.message || String(error) };
  }
};

const sendEmail = async (to, subject, html) => {
  if (!to) return { success: false, error: 'Missing "to" address' };
  return sendWithSmtp(to, subject, html);
};

module.exports = { sendEmail };
