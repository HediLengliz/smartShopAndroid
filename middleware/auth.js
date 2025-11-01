const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

const generateToken = (userId, email) => {
  return jwt.sign(
    { userId, email },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
};

const generateVerificationToken = () => {
  return jwt.sign(
    { purpose: 'email-verification', timestamp: Date.now() },
    JWT_SECRET,
    { expiresIn: '24h' }
  );
};

const generatePasswordResetToken = () => {
  return jwt.sign(
    { purpose: 'password-reset', timestamp: Date.now() },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
};

module.exports = {
  authenticateToken,
  generateToken,
  generateVerificationToken,
  generatePasswordResetToken,
  JWT_SECRET
};
