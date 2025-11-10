# SmartShop

SmartShop is a Flutter e-commerce app backed by a Node.js API. This repo now includes a lightweight AI assistant that runs through LM Studio.

## Project Structure
- `backendv2/` – Node.js/Express API with `/api/chat` for the assistant.
- `lib/` – Flutter application source.
- `backendv2/data/intents.json` – reference intents and example utterances for the chatbot.

## Prerequisites
- Flutter 3.16+ with the `http` package enabled.
- Node.js 18+.
- MySQL server running (for the core API).
- LM Studio (or another API compatible with OpenAI's chat completion format).

## 1. Start LM Studio
1. Install [LM Studio](https://lmstudio.ai/).
2. Download a chat-tuned model (e.g. `Phi-3-mini-4k-instruct` in `Q4` precision).
3. Go to the **Server** tab, select the model, and start the server (default: `http://localhost:1234`). Keep LM Studio running while you test.

## 2. Configure and Run the Backend
```powershell
cd backendv2
copy env.example .env   # update credentials + LM_STUDIO_URL if needed
npm install
npm start
```

Key endpoints:
- Health check: `GET http://localhost:3000/health`
- Chatbot: `POST http://localhost:3000/api/chat` with `{ "sessionId": "abc", "userMessage": "Hi" }`

## 3. Run the Flutter App
```powershell
flutter pub get
flutter run   # choose Android/iOS/Web target
```

The chatbot screen is available from the drawer entry **Help & Support** or via `Navigator.pushNamed(context, '/support/chat')`.

## 4. Testing the Chatbot Quickly
```powershell
curl -X POST http://localhost:3000/api/chat ^
  -H "Content-Type: application/json" ^
  -d "{\"sessionId\":\"test\",\"userMessage\":\"What can you do?\"}"
```

The assistant respects the rules defined in `backendv2/controllers/chatController.js` and keeps conversation history per `sessionId` in memory.
