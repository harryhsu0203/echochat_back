const OpenAI = require('openai');

class AIModelsController {
  // 獲取可用的 AI 模型列表
  static async getModels(req, res) {
    try {
      // 檢查是否有 OpenAI API 金鑰
      const openaiApiKey = process.env.OPENAI_API_KEY;
      
      if (!openaiApiKey) {
        console.warn('OpenAI API 金鑰未設定，使用預設模型列表');
        return res.json({
          success: true,
          message: 'AI 模型列表獲取成功（預設列表）',
          data: getDefaultModels()
        });
      }

      // 嘗試從 OpenAI API 獲取模型列表
      try {
        const openai = new OpenAI({
          apiKey: openaiApiKey
        });

        const models = await openai.models.list();
        
        // 過濾和格式化模型列表
        const availableModels = models.data
          .filter(model => 
            model.id.includes('gpt-') || 
            model.id.includes('claude-') ||
            model.id.includes('gemini-')
          )
          .map(model => ({
            id: model.id,
            name: getModelDisplayName(model.id),
            description: getModelDescription(model.id),
            maxTokens: getModelMaxTokens(model.id),
            isAvailable: true,
            category: getModelCategory(model.id)
          }))
          .slice(0, 10); // 限制返回數量

        res.json({
          success: true,
          message: 'AI 模型列表獲取成功',
          data: availableModels
        });
      } catch (openaiError) {
        console.error('OpenAI API 錯誤:', openaiError);
        
        // 如果 OpenAI API 失敗，回退到預設列表
        res.json({
          success: true,
          message: 'AI 模型列表獲取成功（預設列表）',
          data: getDefaultModels()
        });
      }
    } catch (error) {
      console.error('獲取 AI 模型列表錯誤:', error);
      res.status(500).json({
        success: false,
        message: '獲取 AI 模型列表失敗',
        error: error.message
      });
    }
  }
}

// 輔助函數：獲取預設模型列表
function getDefaultModels() {
  return [
    {
      id: 'gpt-4o',
      name: 'GPT-4o',
      description: '最新最強大的AI模型，理解力和創造力最佳',
      maxTokens: 4000,
      isAvailable: true,
      category: 'premium'
    },
    {
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      description: '輕量級GPT-4模型，速度快且成本較低',
      maxTokens: 2000,
      isAvailable: true,
      category: 'standard'
    },
    {
      id: 'gpt-4-turbo',
      name: 'GPT-4 Turbo',
      description: '高級AI模型，適合複雜任務和創意工作',
      maxTokens: 4000,
      isAvailable: true,
      category: 'premium'
    },
    {
      id: 'gpt-3.5-turbo',
      name: 'GPT-3.5 Turbo',
      description: '平衡性能和速度的經典模型',
      maxTokens: 2000,
      isAvailable: true,
      category: 'standard'
    },
    {
      id: 'claude-3-5-sonnet',
      name: 'Claude 3.5 Sonnet',
      description: '擅長分析和寫作的AI模型',
      maxTokens: 4000,
      isAvailable: true,
      category: 'premium'
    }
  ];
}

// 輔助函數：獲取模型顯示名稱
function getModelDisplayName(modelId) {
  const nameMap = {
    'gpt-4o': 'GPT-4o',
    'gpt-4o-mini': 'GPT-4o Mini',
    'gpt-4-turbo': 'GPT-4 Turbo',
    'gpt-3.5-turbo': 'GPT-3.5 Turbo',
    'claude-3-5-sonnet': 'Claude 3.5 Sonnet',
    'claude-3-opus': 'Claude 3 Opus',
    'claude-3-sonnet': 'Claude 3 Sonnet',
    'claude-3-haiku': 'Claude 3 Haiku'
  };
  
  return nameMap[modelId] || modelId;
}

// 輔助函數：獲取模型描述
function getModelDescription(modelId) {
  const descriptionMap = {
    'gpt-4o': '最新最強大的AI模型，理解力和創造力最佳',
    'gpt-4o-mini': '輕量級GPT-4模型，速度快且成本較低',
    'gpt-4-turbo': '高級AI模型，適合複雜任務和創意工作',
    'gpt-3.5-turbo': '平衡性能和速度的經典模型',
    'claude-3-5-sonnet': '擅長分析和寫作的AI模型',
    'claude-3-opus': '最強大的Claude模型，適合複雜推理',
    'claude-3-sonnet': '平衡性能和速度的Claude模型',
    'claude-3-haiku': '快速且經濟的Claude模型'
  };
  
  return descriptionMap[modelId] || 'AI語言模型';
}

// 輔助函數：獲取模型最大token數
function getModelMaxTokens(modelId) {
  const tokenMap = {
    'gpt-4o': 4000,
    'gpt-4o-mini': 2000,
    'gpt-4-turbo': 4000,
    'gpt-3.5-turbo': 2000,
    'claude-3-5-sonnet': 4000,
    'claude-3-opus': 4000,
    'claude-3-sonnet': 4000,
    'claude-3-haiku': 2000
  };
  
  return tokenMap[modelId] || 2000;
}

// 輔助函數：獲取模型類別
function getModelCategory(modelId) {
  if (modelId.includes('gpt-4') || modelId.includes('claude-3-opus') || modelId.includes('claude-3-5-sonnet')) {
    return 'premium';
  }
  return 'standard';
}

module.exports = AIModelsController; 