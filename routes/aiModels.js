const express = require('express');
const router = express.Router();
const AIModelsController = require('../controllers/aiModelsController');
const { validateToken } = require('../middleware/auth');

// AI 模型列表端點不需要認證，讓未登入用戶也能查看可用模型
router.get('/', AIModelsController.getModels);

// 如果需要其他需要認證的AI模型相關端點，可以在這裡添加
// router.use(validateToken);
// router.post('/test', AIModelsController.testModel);

module.exports = router; 