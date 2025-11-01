const sgMail = require('@sendgrid/mail');

sgMail.setApiKey(process.env.SENDGRID_API_KEY || '');

const sendEmail = async (to, subject, html) => {
  if (!process.env.SENDGRID_API_KEY) {
    console.log('SendGrid API key not configured. Email not sent.');
    console.log(`To: ${to}, Subject: ${subject}`);
    return { success: false, message: 'Email service not configured' };
  }

  const msg = {
    to,
    from: process.env.SENDGRID_FROM_EMAIL || 'noreply@smartshop.com',
    subject,
    html,
  };

  try {
    await sgMail.send(msg);
    console.log(`Email sent successfully to ${to}`);
    return { success: true };
  } catch (error) {
    console.error('Error sending email:', error);
    return { success: false, error: error.message };
  }
};

module.exports = { sendEmail };
