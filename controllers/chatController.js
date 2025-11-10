const historyStore = new Map();
const db = require('../config/database');

const SYSTEM_PROMPT = `
You are SmartShop Assistant.
- Keep answers short (1-3 sentences).
- Cover SmartShop features only: products, categories, shopping lists, cart, orders, payments, notifications, profile, support.
- Never invent products, prices, or unavailable data. Ask for missing details (e.g. list name, order id).
- Decline unrelated requests politely.
- Give step-by-step instructions only when the user explicitly asks "how".
If the user asks about anything unrelated to SmartShop, respond with: "I can only help with SmartShop features like browsing products, shopping lists, orders, payments, notifications, or account support."`;

const DEFAULT_ENDPOINT =
  process.env.LM_STUDIO_URL || 'http://localhost:1234/v1/chat/completions';

const ensureFetch = () => {
  if (typeof fetch === 'function') {
    return fetch;
  }
  return (...args) => import('node-fetch').then(({ default: f }) => f(...args));
};

const httpClient = ensureFetch();

const domainKeywords = [
  'smartshop',
  'product',
  'products',
  'category',
  'categories',
  'cart',
  'order',
  'orders',
  'shopping list',
  'shopping lists',
  'list',
  'payment',
  'payments',
  'checkout',
  'notification',
  'notifications',
  'profile',
  'account',
  'support',
  'delivery',
  'promo',
  'coupon',
  'wishlist'
];

const greetingKeywords = [
  'hi',
  'hello',
  'hey',
  'good morning',
  'good afternoon',
  'good evening'
];

const isGreetingMessage = (text) => {
  const trimmed = text.trim().toLowerCase();
  return greetingKeywords.some(
    (keyword) =>
      trimmed === keyword ||
      trimmed.startsWith(`${keyword} `) ||
      trimmed.endsWith(` ${keyword}`) ||
      trimmed.includes(` ${keyword} `)
  );
};

const isSmartShopTopic = (message) => {
  const text = message.toLowerCase();
  if (isGreetingMessage(text)) {
    return true;
  }
  if (text.length <= 6) {
    return false;
  }
  return domainKeywords.some((keyword) => text.includes(keyword));
};

const outOfScopeReply =
  'I can only help with SmartShop features like browsing products, managing shopping lists, orders, payments, notifications, or account support.';

const greetingReply =
  'Hi there! I can help with SmartShop features like browsing products, managing shopping lists, orders, payments, notifications, or account support. What would you like to do?';

const capabilitiesReply =
  'I can help you browse SmartShop products, suggest categories, manage shopping lists, add or remove items, check order statuses, explain payment options, update profile details, and handle notifications or support requests. Let me know which of these you need!';

const capabilityPatterns = [
  /what can you do/i,
  /how can you help/i,
  /can you help/i,
  /help me/i,
  /what do you do/i
];

const isCapabilityQuestion = (text) =>
  capabilityPatterns.some((pattern) => pattern.test(text));

const containsForeignInstructions = (text) => {
  const lower = text.toLowerCase();
  return (
    lower.includes('you are a') ||
    lower.includes('welcome to') ||
    lower.includes('techgear') ||
    lower.includes('globetrott') ||
    lower.includes('eco drive') ||
    lower.includes('luxefashion')
  );
};

const categoryMappings = [
  {
    label: 'Dairy',
    keywords: ['dairy', 'milk', 'cheese', 'yogurt', 'butter', 'cream'],
    dbCategories: ['Dairy', 'Dairy Products']
  },
  {
    label: 'Produce',
    keywords: ['produce', 'fruit', 'fruits', 'vegetable', 'vegetables', 'veggies'],
    dbCategories: ['Produce', 'Fruits', 'Vegetables']
  },
  {
    label: 'Bakery',
    keywords: ['bakery', 'bread', 'pastry', 'pastries', 'bagel', 'donut'],
    dbCategories: ['Bakery']
  },
  {
    label: 'Snacks',
    keywords: ['snack', 'snacks', 'chips', 'crackers', 'cookies'],
    dbCategories: ['Snacks']
  },
  {
    label: 'Beverages',
    keywords: ['drink', 'drinks', 'beverage', 'beverages', 'juice', 'soda', 'water'],
    dbCategories: ['Beverages', 'Drinks']
  },
  {
    label: 'Meat & Seafood',
    keywords: ['meat', 'seafood', 'chicken', 'beef', 'fish', 'shrimp'],
    dbCategories: ['Meat', 'Seafood', 'Butcher']
  },
  {
    label: 'Household',
    keywords: ['household', 'cleaning', 'detergent', 'paper towel', 'toilet paper'],
    dbCategories: ['Household']
  },
  {
    label: 'Personal Care',
    keywords: ['personal care', 'shampoo', 'soap', 'toothpaste', 'skincare'],
    dbCategories: ['Personal Care']
  },
  {
    label: 'Baby Care',
    keywords: ['baby', 'diaper', 'formula', 'wipes'],
    dbCategories: ['Baby Care', 'Baby']
  },
  {
    label: 'Electronics',
    keywords: ['electronics', 'gadget', 'headphones', 'charger'],
    dbCategories: ['Electronics']
  }
];

const categoryActionRegex = /(show|browse|view|see|find|look for|where can i find)/i;

const matchCategoryIntent = (message) => {
  if (!categoryActionRegex.test(message)) {
    return null;
  }
  const lower = message.toLowerCase();
  for (const mapping of categoryMappings) {
    if (mapping.keywords.some((keyword) => lower.includes(keyword))) {
      return mapping;
    }
  }
  return null;
};

const buildCategoryReply = (categoryLabel, productLines) => {
  let reply = `To explore ${categoryLabel} items in SmartShop:\n1. Open the app and tap 'Categories'.\n2. Select '${categoryLabel}'.\n3. Use filters or the search bar to narrow things down.\n4. Tap a product to view details, add it to your cart, or add it to a shopping list.`;

  if (productLines?.length) {
    reply += `\n\nHere are a few ${categoryLabel.toLowerCase()} picks currently in SmartShop:\n${productLines.join('\n')}`;
  }

  reply += `\n\nLet me know if you want suggestions within ${categoryLabel} or help adding something!`;
  return reply;
};

const fetchSampleProducts = async (mapping) => {
  try {
    const categoriesRaw = mapping.dbCategories?.length ? mapping.dbCategories : [mapping.label];
    const categories = categoriesRaw.map((cat) => cat.toLowerCase());
    const placeholders = categories.map(() => '?').join(', ');
    const query = `
      SELECT name, price
      FROM products
      WHERE is_active = 1
        AND LOWER(category) IN (${placeholders})
      ORDER BY updated_at DESC
      LIMIT 5
    `;
    const { rows } = await db.query(query, categories);
    if (!rows?.length) {
      return [];
    }
    return rows.map((row) => {
      const price =
        row.price !== null && row.price !== undefined
          ? ` - $${Number(row.price).toFixed(2)}`
          : '';
      return `- ${row.name}${price}`;
    });
  } catch (error) {
    console.error('[ChatController] Failed to fetch sample products:', error);
    return [];
  }
};

const sanitizeModelReply = (reply) => {
  if (!reply) {
    return null;
  }

  let cleaned = reply.trim();
  const instructionMarkers = [
    '**instruction',
    'instruction 1',
    'you are bookbuddy',
    'you are a chatbot'
  ];

  const dashIndex = cleaned.indexOf('----');
  if (dashIndex !== -1) {
    cleaned = cleaned.slice(0, dashIndex).trim();
  }

  instructionMarkers.forEach((marker) => {
    const idx = cleaned.toLowerCase().indexOf(marker);
    if (idx !== -1) {
      cleaned = cleaned.slice(0, idx).trim();
    }
  });

  if (!cleaned) {
    return null;
  }

  if (!isSmartShopTopic(cleaned) || containsForeignInstructions(cleaned)) {
    return null;
  }

  return cleaned;
};

exports.handleChat = async (req, res) => {
  try {
    const { sessionId, userMessage } = req.body || {};

    if (!sessionId || !userMessage) {
      return res.status(400).json({ error: 'sessionId and userMessage are required.' });
    }

    const trimmedMessage = String(userMessage).trim();
    if (!trimmedMessage) {
      return res.status(400).json({ error: 'userMessage cannot be empty.' });
    }

    if (isGreetingMessage(trimmedMessage)) {
      const greetingHistory = [
        { role: 'user', content: trimmedMessage },
        { role: 'assistant', content: greetingReply }
      ];
      historyStore.set(sessionId, greetingHistory);
      return res.json({ reply: greetingReply });
    }

    if (isCapabilityQuestion(trimmedMessage)) {
      const capabilityHistory = historyStore.get(sessionId) || [];
      capabilityHistory.push({ role: 'user', content: trimmedMessage });
      capabilityHistory.push({ role: 'assistant', content: capabilitiesReply });
      historyStore.set(sessionId, capabilityHistory.slice(-12));
      return res.json({ reply: capabilitiesReply });
    }

    const categoryMapping = matchCategoryIntent(trimmedMessage);
    if (categoryMapping) {
      const sampleProducts = await fetchSampleProducts(categoryMapping);
      const categoryReply = buildCategoryReply(categoryMapping.label, sampleProducts);
      const categoryHistory = historyStore.get(sessionId) || [];
      categoryHistory.push({ role: 'user', content: trimmedMessage });
      categoryHistory.push({ role: 'assistant', content: categoryReply });
      historyStore.set(sessionId, categoryHistory.slice(-12));
      return res.json({ reply: categoryReply });
    }

    if (!isSmartShopTopic(trimmedMessage)) {
      return res.json({ reply: outOfScopeReply });
    }

    const history = historyStore.get(sessionId) || [];
    history.push({ role: 'user', content: trimmedMessage });

    const messages = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...history.map((entry) => ({
        role: entry.role,
        content: entry.content
      }))
    ];

    const response = await httpClient(DEFAULT_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'local-llm',
        messages,
        temperature: 0.3,
        max_tokens: 200
      })
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('[ChatController] LM Studio error:', response.status, errorBody);
      return res.status(502).json({ error: 'Chat service unavailable. Please try again later.' });
    }

    const data = await response.json();
    const cleanedReply = sanitizeModelReply(
      data?.choices?.[0]?.message?.content || ''
    );

    const botReply = cleanedReply ?? outOfScopeReply;

    if (!cleanedReply) {
      console.error('[ChatController] Missing reply from LM Studio:', data);
    }

    history.push({ role: 'assistant', content: botReply });
    historyStore.set(sessionId, history.slice(-12));

    return res.json({ reply: botReply });
  } catch (error) {
    console.error('[ChatController] Unexpected error:', error);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

exports.resetChat = (req, res) => {
  try {
    const { sessionId } = req.body || {};
    if (!sessionId) {
      return res.status(400).json({ error: 'sessionId is required.' });
    }
    historyStore.delete(sessionId);
    return res.json({ success: true });
  } catch (error) {
    console.error('[ChatController] Failed to reset chat session:', error);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};



