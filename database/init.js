const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

const initializeDatabase = async () => {
  let connection;
  let pool;
  
  try {
    // First, connect without database to create it if needed
    // XAMPP MySQL root user typically has EMPTY password by default
    const connectionConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 3306,
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD !== undefined ? process.env.DB_PASSWORD : '', // Empty password for XAMPP
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    };

    // Connect without specifying database
    connection = await mysql.createConnection(connectionConfig);
    
    // Get database name from .env or use default
    const dbName = process.env.DB_NAME || 'smartshop';
    
    // Create database if it doesn't exist
    await connection.execute(`CREATE DATABASE IF NOT EXISTS \`${dbName}\``);
    console.log(`Database '${dbName}' is ready`);
    
    // Close temporary connection
    await connection.end();
    
    // Now connect with database specified
    connectionConfig.database = dbName;
    pool = mysql.createPool(connectionConfig);
    
    // Read and execute schema
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    
    // Remove comments and split by semicolons
    let cleanedSchema = schema
      .split('\n')
      .filter(line => !line.trim().startsWith('--')) // Remove comment lines
      .join('\n');
    
    // Split by semicolon, but keep multi-line statements together
    const allStatements = cleanedSchema
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0);
    
    const tableStatements = [];
    const indexStatements = [];
    
    // Separate CREATE TABLE and CREATE INDEX statements
    for (const statement of allStatements) {
      const upperStatement = statement.toUpperCase().trim();
      if (upperStatement.startsWith('CREATE TABLE')) {
        tableStatements.push(statement);
      } else if (upperStatement.startsWith('CREATE INDEX')) {
        indexStatements.push(statement);
      }
    }
    
    console.log(`Found ${tableStatements.length} table statements and ${indexStatements.length} index statements`);
    
    // First, create all tables
    console.log('Creating tables...');
    for (let i = 0; i < tableStatements.length; i++) {
      const statement = tableStatements[i];
      if (statement.trim() && statement.length > 0) {
        try {
          // Extract table name for logging
          const tableMatch = statement.match(/CREATE TABLE\s+IF NOT EXISTS\s+`?(\w+)`?/i) || 
                             statement.match(/CREATE TABLE\s+`?(\w+)`?/i);
          const tableName = tableMatch ? tableMatch[1] : `table_${i + 1}`;
          
          await pool.execute(statement);
          console.log(`  ✓ Table '${tableName}' created`);
        } catch (err) {
          // Check if table already exists
          if (err.code === 'ER_TABLE_EXISTS_ERROR' || err.message.includes('already exists')) {
            const tableMatch = statement.match(/CREATE TABLE\s+IF NOT EXISTS\s+`?(\w+)`?/i) || 
                               statement.match(/CREATE TABLE\s+`?(\w+)`?/i);
            const tableName = tableMatch ? tableMatch[1] : `table_${i + 1}`;
            console.log(`  - Table '${tableName}' already exists`);
          } else {
            console.error(`  ✗ Error creating table:`, err.message);
            console.error(`    SQL: ${statement.substring(0, 100)}...`);
            throw err;
          }
        }
      }
    }
    
    // Verify tables were created
    console.log('Verifying tables...');
    const [tables] = await pool.execute(`SHOW TABLES`);
    console.log(`  Found ${tables.length} tables in database:`, tables.map(t => Object.values(t)[0]).join(', '));
    
    // Then, create all indexes (after tables exist)
    console.log('Creating indexes...');
    for (let i = 0; i < indexStatements.length; i++) {
      const statement = indexStatements[i];
      if (statement.trim() && statement.length > 0) {
        try {
          const indexMatch = statement.match(/CREATE INDEX\s+IF NOT EXISTS\s+`?(\w+)`?/i) || 
                             statement.match(/CREATE INDEX\s+`?(\w+)`?/i);
          const indexName = indexMatch ? indexMatch[1] : `index_${i + 1}`;
          
          await pool.execute(statement);
          console.log(`  ✓ Index '${indexName}' created`);
        } catch (err) {
          // Ignore "index already exists" and "table doesn't exist" errors
          if (err.code === 'ER_DUP_KEYNAME' || 
              err.message.includes('Duplicate key name') ||
              err.message.includes('already exists') ||
              err.code === 'ER_NO_SUCH_TABLE') {
            const indexMatch = statement.match(/CREATE INDEX\s+IF NOT EXISTS\s+`?(\w+)`?/i) || 
                               statement.match(/CREATE INDEX\s+`?(\w+)`?/i);
            const indexName = indexMatch ? indexMatch[1] : `index_${i + 1}`;
            console.log(`  - Index '${indexName}' skipped (already exists or table missing)`);
          } else {
            console.error(`  ✗ Error creating index:`, err.message);
            // Don't throw - indexes are optional
          }
        }
      }
    }
    
    console.log('Database schema initialized successfully');
    
    await seedInitialData(pool);
    
    // Export pool for use
    return pool;
  } catch (error) {
    console.error('Error initializing database:', error);
    if (connection) await connection.end().catch(() => {});
    throw error;
  }
};

const seedInitialData = async (pool) => {
  try {
    const [checkProducts] = await pool.execute('SELECT COUNT(*) as count FROM products');
    
    if (parseInt(checkProducts[0].count) === 0) {
      console.log('Seeding initial products...');
      
      const products = [
        { name: 'Organic Apples', description: 'Fresh organic apples from local farms', price: 3.99, category: 'Fruits', stock: 100, image: 'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=400' },
        { name: 'Whole Wheat Bread', description: 'Freshly baked whole wheat bread', price: 2.49, category: 'Bakery', stock: 50, image: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400' },
        { name: 'Organic Milk', description: 'Fresh organic whole milk (1 gallon)', price: 4.99, category: 'Dairy', stock: 75, image: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400' },
        { name: 'Free Range Eggs', description: 'Farm fresh free range eggs (dozen)', price: 5.49, category: 'Dairy', stock: 80, image: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400' },
        { name: 'Bananas', description: 'Ripe yellow bananas', price: 1.99, category: 'Fruits', stock: 150, image: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400' },
        { name: 'Ground Coffee', description: 'Premium arabica ground coffee (12 oz)', price: 8.99, category: 'Beverages', stock: 40, image: 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400' },
        { name: 'Greek Yogurt', description: 'Plain Greek yogurt (32 oz)', price: 4.49, category: 'Dairy', stock: 60, image: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400' },
        { name: 'Chicken Breast', description: 'Fresh boneless chicken breast (per lb)', price: 6.99, category: 'Meat', stock: 45, image: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400' },
        { name: 'Pasta', description: 'Italian pasta (1 lb box)', price: 2.99, category: 'Pantry', stock: 90, image: 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=400' },
        { name: 'Tomato Sauce', description: 'Organic tomato pasta sauce (24 oz)', price: 3.49, category: 'Pantry', stock: 70, image: 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=400' },
        { name: 'Orange Juice', description: 'Fresh squeezed orange juice (64 oz)', price: 5.99, category: 'Beverages', stock: 55, image: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=400' },
        { name: 'Spinach', description: 'Fresh organic spinach (bunch)', price: 2.79, category: 'Vegetables', stock: 65, image: 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=400' },
      ];
      
      for (const product of products) {
        await pool.execute(
          'INSERT INTO products (name, description, price, category, stock_quantity, image_url) VALUES (?, ?, ?, ?, ?, ?)',
          [product.name, product.description, product.price, product.category, product.stock, product.image]
        );
      }
      
      console.log('Initial products seeded successfully');
    } else {
      console.log('Products already exist, skipping seed');
    }
  } catch (error) {
    console.error('Error seeding data:', error);
    throw error;
  }
};

module.exports = { initializeDatabase };
