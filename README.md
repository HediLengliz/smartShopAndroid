# Smart Shop Backend API

Node.js/Express backend API for the Smart Shop mobile application.

## Prerequisites
- Node.js 20+ installed
- MySQL installed (XAMPP or standalone MySQL)
- MySQL database created
- LM Studio (or another OpenAI-compatible chat completion server) if you want to run the chatbot locally

## Setup Instructions

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment Variables
Create an `.env` file in this directory (copy from `env.example`):
```powershell
copy env.example .env
```

Update `.env` with your credentials:
```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root
DB_NAME=smartshop
PORT=3000
JWT_SECRET=your-secret-key-here
LM_STUDIO_URL=http://localhost:1234/v1/chat/completions
```
Set any optional keys (SendGrid, Stripe, etc.) as needed.

### 3. Run a Local Chat Model (LM Studio)
1. Install [LM Studio](https://lmstudio.ai/) and download a lightweight instruct model (e.g. `Phi-3-mini-4k-instruct` in `Q4` format).
2. Open the **Server** tab, select the model, and start the server (defaults to `http://localhost:1234`).
3. Keep LM Studio running; the chatbot route forwards requests to `LM_STUDIO_URL`.

### 4. Create the MySQL Database
```sql
CREATE DATABASE smartshop;
```
Or use phpMyAdmin/XAMPP to create the database manually.

### 5. Start the Backend Server
```bash
npm start
```
The server initializes the schema (if required) and starts the API on port 3000.

### 6. Verify the API
```bash
curl http://localhost:3000/health
```
Expected response: `{"status":"ok","message":"Smart Shop API is running"}`

### 7. Test the Chatbot
With LM Studio running:
```bash
curl -X POST http://localhost:3000/api/chat ^
  -H "Content-Type: application/json" ^
  -d "{\"sessionId\":\"test\",\"userMessage\":\"Hi\"}"
```

## API Endpoints
Base URL: `http://localhost:3000/api`
- `/auth/*` – Authentication
- `/products/*` – Product catalog
- `/orders/*` – Order management
- `/shopping-lists/*` – Shopping lists
- `/payments/*` – Payments
- `/profile/*` – User profile
- `/chat` – AI assistant endpoint

## Development
Reinitialize the database if needed:
```bash
npm run init-db
```

