const { initializeDatabase } = require('./database/init');

async function start() {
  try {
    console.log('Initializing database...');
    await initializeDatabase();
    console.log('Database initialized successfully');
    
    console.log('Starting server...');
    require('./server');
  } catch (error) {
    console.error('Failed to start application:', error);
    process.exit(1);
  }
}

start();
