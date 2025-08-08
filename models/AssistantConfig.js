const db = require('../config/database');

class AssistantConfig {
  // 獲取租戶的助理配置
  static async getByTenantId(tenantId) {
    try {
      const query = `
        SELECT * FROM assistant_configs 
        WHERE tenant_id = $1 AND is_active = true
      `;
      const result = await db.query(query, [tenantId]);
      return result.rows[0] || null;
    } catch (error) {
      throw new Error(`獲取助理配置失敗: ${error.message}`);
    }
  }

  // 創建或更新助理配置
  static async upsert(tenantId, configData) {
    try {
      const query = `
        INSERT INTO assistant_configs (
          tenant_id, ai_model, system_prompt, ai_name, ai_personality,
          ai_specialties, ai_response_style, ai_language, max_tokens,
          temperature, max_context_length, enable_response_filtering,
          enable_sentiment_analysis, enable_auto_approval, approval_threshold,
          response_templates, ai_avatar
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
        ON CONFLICT (tenant_id) DO UPDATE SET
          ai_model = EXCLUDED.ai_model,
          system_prompt = EXCLUDED.system_prompt,
          ai_name = EXCLUDED.ai_name,
          ai_personality = EXCLUDED.ai_personality,
          ai_specialties = EXCLUDED.ai_specialties,
          ai_response_style = EXCLUDED.ai_response_style,
          ai_language = EXCLUDED.ai_language,
          max_tokens = EXCLUDED.max_tokens,
          temperature = EXCLUDED.temperature,
          max_context_length = EXCLUDED.max_context_length,
          enable_response_filtering = EXCLUDED.enable_response_filtering,
          enable_sentiment_analysis = EXCLUDED.enable_sentiment_analysis,
          enable_auto_approval = EXCLUDED.enable_auto_approval,
          approval_threshold = EXCLUDED.approval_threshold,
          response_templates = EXCLUDED.response_templates,
          ai_avatar = EXCLUDED.ai_avatar,
          updated_at = CURRENT_TIMESTAMP
        RETURNING *
      `;
      
      const values = [
        tenantId,
        configData.ai_model || 'gpt-3.5-turbo',
        configData.system_prompt || '你是一個友善的AI助理，請用簡潔明瞭的方式回答問題。',
        configData.ai_name || 'AI助理',
        configData.ai_personality || '友善、專業、樂於助人',
        configData.ai_specialties || '一般諮詢、問題解答',
        configData.ai_response_style || 'conversational',
        configData.ai_language || 'zh-TW',
        configData.max_tokens || 1000,
        configData.temperature || 0.7,
        configData.max_context_length || 4000,
        configData.enable_response_filtering !== undefined ? configData.enable_response_filtering : true,
        configData.enable_sentiment_analysis !== undefined ? configData.enable_sentiment_analysis : false,
        configData.enable_auto_approval !== undefined ? configData.enable_auto_approval : false,
        configData.approval_threshold || 0.8,
        JSON.stringify(configData.response_templates || []),
        configData.ai_avatar || ''
      ];

      const result = await db.query(query, values);
      return result.rows[0];
    } catch (error) {
      throw new Error(`更新助理配置失敗: ${error.message}`);
    }
  }

  // 重設為預設配置
  static async resetToDefault(tenantId) {
    try {
      const defaultConfig = {
        ai_model: 'gpt-3.5-turbo',
        system_prompt: '你是一個友善的AI助理，請用簡潔明瞭的方式回答問題。',
        ai_name: 'AI助理',
        ai_personality: '友善、專業、樂於助人',
        ai_specialties: '一般諮詢、問題解答',
        ai_response_style: 'conversational',
        ai_language: 'zh-TW',
        max_tokens: 1000,
        temperature: 0.7,
        max_context_length: 4000,
        enable_response_filtering: true,
        enable_sentiment_analysis: false,
        enable_auto_approval: false,
        approval_threshold: 0.8,
        response_templates: [],
        ai_avatar: ''
      };

      return await this.upsert(tenantId, defaultConfig);
    } catch (error) {
      throw new Error(`重設助理配置失敗: ${error.message}`);
    }
  }
}

module.exports = AssistantConfig; 