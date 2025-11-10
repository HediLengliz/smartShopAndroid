const express = require('express');
const { handleChat, resetChat } = require('../controllers/chatController');

const router = express.Router();

router.post('/', handleChat);
router.post('/reset', resetChat);

module.exports = router;



