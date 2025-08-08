const express = require('express');
const router = express.Router();
const AssistantConfigController = require('../controllers/assistantConfigController');
const { validateToken } = require('../middleware/auth');

// 所有路由都需要 JWT 認證
router.use(validateToken);

// 獲取助理配置
router.get('/:tenantId', AssistantConfigController.getConfig);

// 更新助理配置
router.post('/:tenantId', AssistantConfigController.updateConfig);

// 重設助理配置
router.post('/:tenantId/reset', AssistantConfigController.resetConfig);

module.exports = router; 