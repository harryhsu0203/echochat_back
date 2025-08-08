const AssistantConfig = require('../models/AssistantConfig');

class AssistantConfigController {
  // 獲取助理配置
  static async getConfig(req, res) {
    try {
      const { tenantId } = req.params;
      const userId = req.user.id;

      // 驗證權限
      if (userId.toString() !== tenantId) {
        return res.status(403).json({
          success: false,
          message: '無權限訪問此配置'
        });
      }

      const config = await AssistantConfig.getByTenantId(tenantId);
      
      if (!config) {
        // 如果沒有配置，創建預設配置
        const defaultConfig = await AssistantConfig.resetToDefault(tenantId);
        return res.json({
          success: true,
          data: defaultConfig
        });
      }

      res.json({
        success: true,
        data: config
      });
    } catch (error) {
      console.error('獲取助理配置錯誤:', error);
      res.status(500).json({
        success: false,
        message: '獲取助理配置失敗',
        error: error.message
      });
    }
  }

  // 更新助理配置
  static async updateConfig(req, res) {
    try {
      const { tenantId } = req.params;
      const userId = req.user.id;
      const configData = req.body;

      // 驗證權限
      if (userId.toString() !== tenantId) {
        return res.status(403).json({
          success: false,
          message: '無權限更新此配置'
        });
      }

      // 驗證輸入資料
      const validation = AssistantConfigController.validateConfigData(configData);
      if (!validation.isValid) {
        return res.status(400).json({
          success: false,
          message: '配置資料驗證失敗',
          errors: validation.errors
        });
      }

      const updatedConfig = await AssistantConfig.upsert(tenantId, configData);

      res.json({
        success: true,
        message: '助理配置更新成功',
        data: {
          id: updatedConfig.id,
          tenant_id: updatedConfig.tenant_id,
          updated_at: updatedConfig.updated_at
        }
      });
    } catch (error) {
      console.error('更新助理配置錯誤:', error);
      res.status(500).json({
        success: false,
        message: '更新助理配置失敗',
        error: error.message
      });
    }
  }

  // 重設配置
  static async resetConfig(req, res) {
    try {
      const { tenantId } = req.params;
      const userId = req.user.id;

      // 驗證權限
      if (userId.toString() !== tenantId) {
        return res.status(403).json({
          success: false,
          message: '無權限重設此配置'
        });
      }

      const resetConfig = await AssistantConfig.resetToDefault(tenantId);

      res.json({
        success: true,
        message: '助理配置已重設為預設值',
        data: resetConfig
      });
    } catch (error) {
      console.error('重設助理配置錯誤:', error);
      res.status(500).json({
        success: false,
        message: '重設助理配置失敗',
        error: error.message
      });
    }
  }

  // 驗證配置資料
  static validateConfigData(data) {
    const errors = [];

    // 驗證 AI 模型
    if (data.ai_model && !['gpt-3.5-turbo', 'gpt-4', 'gpt-4-turbo', 'gpt-4.1', 'gpt-4-mini', 'claude-3'].includes(data.ai_model)) {
      errors.push('不支援的 AI 模型');
    }

    // 驗證最大 token 數
    if (data.max_tokens && (data.max_tokens < 1 || data.max_tokens > 4000)) {
      errors.push('最大 token 數必須在 1-4000 之間');
    }

    // 驗證溫度值
    if (data.temperature && (data.temperature < 0 || data.temperature > 2)) {
      errors.push('溫度值必須在 0-2 之間');
    }

    // 驗證核准閾值
    if (data.approval_threshold && (data.approval_threshold < 0 || data.approval_threshold > 1)) {
      errors.push('核准閾值必須在 0-1 之間');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}

module.exports = AssistantConfigController; 