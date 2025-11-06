# Smart Shop Backend API

Node.js/Express backend API for Smart Shop mobile application.

## Prerequisites

- Node.js 20+ installed
- MySQL installed (XAMPP or standalone MySQL)
- MySQL database created

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Create a `.env` file in the `backend` directory (copy from `.env.example`):

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root
DB_NAME=smartshop
PORT=3000
JWT_SECRET=your-secret-key-here
```

### 3. Create MySQL Database

1. Open MySQL (via XAMPP or MySQL command line)
2. Create the database:

```sql
CREATE DATABASE smartshop;
```

Or use phpMyAdmin:
- Open XAMPP → Start MySQL
- Open phpMyAdmin (http://localhost/phpmyadmin)
- Click "New" → Database name: `smartshop` → Create

### 4. Start the Backend Server

```bash
npm start
```

Or use the start script:

```bash
node start.js
```

The server will:
- Initialize the database schema
- Seed initial products
- Start the API server on port 3000

### 5. Verify Backend is Running

Open your browser or use curl:

```bash
curl http://localhost:3000/health
```

You should see: `{"status":"ok","message":"Smart Shop API is running"}`

## API Endpoints

Base URL: `http://localhost:3000/api`

- `/auth/*` - Authentication endpoints
- `/products/*` - Product catalog
- `/orders/*` - Order management
- `/shopping-lists/*` - Shopping lists
- `/payments/*` - Payment processing
- `/profile/*` - User profile

## Development

The server auto-initializes the database schema on startup. If you need to reinitialize:

```bash
npm run init-db
```

