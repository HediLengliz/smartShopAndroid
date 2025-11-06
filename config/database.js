const mysql = require('mysql2/promise');

// Parse DATABASE_URL or use individual connection options
let connectionConfig = {};

if (process.env.DATABASE_URL) {
  // Parse connection string format: mysql://user:password@host:port/database
  const url = new URL(process.env.DATABASE_URL);
  connectionConfig = {
    host: url.hostname,
    port: url.port || 3306,
    user: url.username,
    password: url.password,
    database: url.pathname.slice(1), // Remove leading '/'
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  };
} else {
  // Use individual connection options
  // XAMPP MySQL root user typically has EMPTY password by default
  connectionConfig = {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD !== undefined ? process.env.DB_PASSWORD : '', // Empty password for XAMPP
    database: process.env.DB_NAME || 'smartshop',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  };
}

const pool = mysql.createPool(connectionConfig);

// Test connection
pool.getConnection()
  .then(connection => {
    console.log('Connected to MySQL database');
    connection.release();
  })
  .catch(err => {
    console.error('Error connecting to MySQL database:', err);
  });

// Override query method to match PostgreSQL interface (returns { rows })
pool.query = async (query, params = []) => {
  try {
    const [rows, fields] = await pool.execute(query, params);
    // Return format similar to PostgreSQL (with rows property)
    return { rows };
  } catch (error) {
    throw error;
  }
};

module.exports = pool;
