const express = require('express');
const router = express.Router();
const { authenticateJWT } = require('./middleware/auth');
const { loadDatabase, saveDatabase } = require('./database');

// 獲取支援的語言模型列表
router.get('/ai-models/supported', authenticateJWT, (req, res) => {
    try {
        const supportedModels = {
            'gpt-3.5-turbo': {
                name: 'GPT-4o Mini',
                provider: 'OpenAI',
                description: '快速且經濟實惠的對話體驗',
                features: ['快速回應', '成本效益高', '支援多語言'],
                pricing: '經濟實惠',
                speed: '快速',
                max_tokens: 128000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'gpt-4-turbo': {
                name: 'GPT-4o',
                provider: 'OpenAI',
                description: '高級版本，提供更強大的理解和生成能力',
                features: ['高品質回應', '複雜任務處理', '創意內容生成', '深度理解'],
                pricing: '中等',
                speed: '中等',
                max_tokens: 128000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文', '義大利文', '葡萄牙文']
            },
            'gpt-4-turbo': {
                name: 'GPT-4 Turbo',
                provider: 'OpenAI',
                description: '平衡性能和成本的選擇',
                features: ['平衡性能', '廣泛應用', '穩定可靠'],
                pricing: '中等',
                speed: '中等',
                max_tokens: 128000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'gpt-3.5-turbo': {
                name: 'GPT-3.5 Turbo',
                provider: 'OpenAI',
                description: '經典模型，穩定可靠',
                features: ['穩定可靠', '成本低廉', '廣泛支援'],
                pricing: '經濟實惠',
                speed: '快速',
                max_tokens: 16385,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'claude-3-haiku': {
                name: 'Claude 3 Haiku',
                provider: 'Anthropic',
                description: '快速且經濟的Claude模型',
                features: ['快速回應', '成本效益高', '安全性高'],
                pricing: '經濟實惠',
                speed: '快速',
                max_tokens: 200000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'claude-3-sonnet': {
                name: 'Claude 3 Sonnet',
                provider: 'Anthropic',
                description: '平衡性能和成本的Claude模型',
                features: ['平衡性能', '安全性高', '創意能力強'],
                pricing: '中等',
                speed: '中等',
                max_tokens: 200000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文', '義大利文', '葡萄牙文']
            },
            'claude-3-opus': {
                name: 'Claude 3 Opus',
                provider: 'Anthropic',
                description: '最高性能的Claude模型',
                features: ['最高性能', '複雜任務處理', '創意能力強'],
                pricing: '高級',
                speed: '較慢',
                max_tokens: 200000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文', '義大利文', '葡萄牙文', '俄文']
            },
            'gemini-pro': {
                name: 'Gemini Pro',
                provider: 'Google',
                description: 'Google的通用AI模型',
                features: ['多模態支援', '創意能力強', '程式碼生成'],
                pricing: '經濟實惠',
                speed: '快速',
                max_tokens: 32768,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文', '義大利文', '葡萄牙文']
            },
            'gemini-pro-vision': {
                name: 'Gemini Pro Vision',
                provider: 'Google',
                description: '支援視覺理解的Gemini模型',
                features: ['視覺理解', '多模態支援', '圖像分析'],
                pricing: '中等',
                speed: '中等',
                max_tokens: 32768,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            }
        };

        res.json({
            success: true,
            models: supportedModels
        });
    } catch (error) {
        console.error('獲取支援模型錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取模型列表失敗'
        });
    }
});

// 知識庫綁定 API
router.post('/knowledge/bind', authenticateJWT, async (req, res) => {
    try {
        const { knowledgeIds, assistantId } = req.body;
        
        if (!knowledgeIds || !Array.isArray(knowledgeIds)) {
            return res.status(400).json({
                success: false,
                error: '請提供有效的知識庫ID列表'
            });
        }

        loadDatabase();
        
        // 檢查知識庫是否存在
        const existingKnowledge = database.knowledge || [];
        const validKnowledgeIds = knowledgeIds.filter(id => 
            existingKnowledge.some(k => k.id === id)
        );

        if (validKnowledgeIds.length === 0) {
            return res.status(400).json({
                success: false,
                error: '沒有找到有效的知識庫項目'
            });
        }

        // 更新或創建綁定關係
        if (!database.knowledge_bindings) {
            database.knowledge_bindings = [];
        }

        const binding = {
            id: `binding_${Date.now()}`,
            assistantId: assistantId || 'default',
            knowledgeIds: validKnowledgeIds,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        // 移除舊的綁定關係（如果存在）
        database.knowledge_bindings = database.knowledge_bindings.filter(
            b => b.assistantId !== binding.assistantId
        );

        database.knowledge_bindings.push(binding);
        saveDatabase();

        res.json({
            success: true,
            message: '知識庫綁定成功',
            binding: binding
        });
    } catch (error) {
        console.error('知識庫綁定錯誤:', error);
        res.status(500).json({
            success: false,
            error: '知識庫綁定失敗'
        });
    }
});

// 獲取知識庫綁定關係
router.get('/knowledge/bindings', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const bindings = database.knowledge_bindings || [];
        
        res.json({
            success: true,
            bindings: bindings
        });
    } catch (error) {
        console.error('獲取知識庫綁定錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取綁定關係失敗'
        });
    }
});

// 角色權限設定 API
router.post('/roles', authenticateJWT, async (req, res) => {
    try {
        const { name, permissions, description } = req.body;
        
        if (!name || !permissions) {
            return res.status(400).json({
                success: false,
                error: '請提供角色名稱和權限'
            });
        }

        loadDatabase();
        
        if (!database.roles) {
            database.roles = [];
        }

        const role = {
            id: `role_${Date.now()}`,
            name: name.trim(),
            permissions: permissions,
            description: description || '',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        database.roles.push(role);
        saveDatabase();

        res.json({
            success: true,
            message: '角色創建成功',
            role: role
        });
    } catch (error) {
        console.error('創建角色錯誤:', error);
        res.status(500).json({
            success: false,
            error: '創建角色失敗'
        });
    }
});

// 獲取所有角色
router.get('/roles', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const roles = database.roles || [];
        
        res.json({
            success: true,
            roles: roles
        });
    } catch (error) {
        console.error('獲取角色錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取角色失敗'
        });
    }
});

// 更新角色權限
router.put('/roles/:id', authenticateJWT, async (req, res) => {
    try {
        const { id } = req.params;
        const { name, permissions, description } = req.body;

        loadDatabase();
        
        if (!database.roles) {
            return res.status(404).json({
                success: false,
                error: '角色不存在'
            });
        }

        const roleIndex = database.roles.findIndex(r => r.id === id);
        if (roleIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '角色不存在'
            });
        }

        database.roles[roleIndex] = {
            ...database.roles[roleIndex],
            name: name || database.roles[roleIndex].name,
            permissions: permissions || database.roles[roleIndex].permissions,
            description: description || database.roles[roleIndex].description,
            updatedAt: new Date().toISOString()
        };

        saveDatabase();

        res.json({
            success: true,
            message: '角色更新成功',
            role: database.roles[roleIndex]
        });
    } catch (error) {
        console.error('更新角色錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新角色失敗'
        });
    }
});

// 刪除角色
router.delete('/roles/:id', authenticateJWT, async (req, res) => {
    try {
        const { id } = req.params;

        loadDatabase();
        
        if (!database.roles) {
            return res.status(404).json({
                success: false,
                error: '角色不存在'
            });
        }

        const roleIndex = database.roles.findIndex(r => r.id === id);
        if (roleIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '角色不存在'
            });
        }

        database.roles.splice(roleIndex, 1);
        saveDatabase();

        res.json({
            success: true,
            message: '角色刪除成功'
        });
    } catch (error) {
        console.error('刪除角色錯誤:', error);
        res.status(500).json({
            success: false,
            error: '刪除角色失敗'
        });
    }
});

module.exports = router; 