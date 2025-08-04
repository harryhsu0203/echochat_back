//
//  AIAssistantConfig.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - AI 助理配置模型
struct AIAssistantConfig: Codable, Equatable {
    // 基本服務設定
    var aiServiceEnabled: Bool = false
    var selectedAIModel: String = "客服專家"
    var maxTokens: Int = 1000
    var temperature: Double = 0.7
    var systemPrompt: String = "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
    
    // AI 助理個性化設定
    var aiName: String = "EchoChat 助理"
    var aiPersonality: String = "友善、專業、耐心"
    var aiSpecialties: String = "產品諮詢、技術支援、訂單處理"
    var aiResponseStyle: String = "正式"
    var aiLanguage: String = "繁體中文"
    var aiAvatar: String = "robot"
    
    // 進階設定
    var maxContextLength: Int = 10
    var enableResponseFiltering: Bool = true
    var enableSentimentAnalysis: Bool = false
    var enableAutoApproval: Bool = false
    var approvalThreshold: Double = 0.8
    
    // 回應模板設定
    var responseTemplates: [ResponseTemplate] = []
    
    // 時間戳記
    var lastUpdated: Date = Date()
    var lastSynced: Date?
    
    // MARK: - Equatable 實現
    static func == (lhs: AIAssistantConfig, rhs: AIAssistantConfig) -> Bool {
        return lhs.aiServiceEnabled == rhs.aiServiceEnabled &&
               lhs.selectedAIModel == rhs.selectedAIModel &&
               lhs.maxTokens == rhs.maxTokens &&
               lhs.temperature == rhs.temperature &&
               lhs.systemPrompt == rhs.systemPrompt &&
               lhs.aiName == rhs.aiName &&
               lhs.aiPersonality == rhs.aiPersonality &&
               lhs.aiSpecialties == rhs.aiSpecialties &&
               lhs.aiResponseStyle == rhs.aiResponseStyle &&
               lhs.aiLanguage == rhs.aiLanguage &&
               lhs.aiAvatar == rhs.aiAvatar &&
               lhs.maxContextLength == rhs.maxContextLength &&
               lhs.enableResponseFiltering == rhs.enableResponseFiltering &&
               lhs.enableSentimentAnalysis == rhs.enableSentimentAnalysis &&
               lhs.enableAutoApproval == rhs.enableAutoApproval &&
               lhs.approvalThreshold == rhs.approvalThreshold
    }
    
    // 同步狀態
    var isSynced: Bool = false
    var syncError: String?
    
    // MARK: - 初始化方法
    init() {}
    
    init(from userDefaults: UserDefaults) {
        self.aiServiceEnabled = userDefaults.bool(forKey: "aiServiceEnabled")
        self.selectedAIModel = userDefaults.string(forKey: "selectedAIModel") ?? "客服專家"
        self.maxTokens = userDefaults.integer(forKey: "maxTokens")
        self.temperature = userDefaults.double(forKey: "temperature")
        self.systemPrompt = userDefaults.string(forKey: "systemPrompt") ?? "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
        
        self.aiName = userDefaults.string(forKey: "aiName") ?? "EchoChat 助理"
        self.aiPersonality = userDefaults.string(forKey: "aiPersonality") ?? "友善、專業、耐心"
        self.aiSpecialties = userDefaults.string(forKey: "aiSpecialties") ?? "產品諮詢、技術支援、訂單處理"
        self.aiResponseStyle = userDefaults.string(forKey: "aiResponseStyle") ?? "正式"
        self.aiLanguage = userDefaults.string(forKey: "aiLanguage") ?? "繁體中文"
        self.aiAvatar = userDefaults.string(forKey: "aiAvatar") ?? "robot"
        
        self.maxContextLength = userDefaults.integer(forKey: "maxContextLength")
        self.enableResponseFiltering = userDefaults.bool(forKey: "enableResponseFiltering")
        self.enableSentimentAnalysis = userDefaults.bool(forKey: "enableSentimentAnalysis")
        self.enableAutoApproval = userDefaults.bool(forKey: "enableAutoApproval")
        self.approvalThreshold = userDefaults.double(forKey: "approvalThreshold")
        
        // 載入回應模板
        if let templatesData = userDefaults.data(forKey: "responseTemplates"),
           let templates = try? JSONDecoder().decode([ResponseTemplate].self, from: templatesData) {
            self.responseTemplates = templates
        }
        
        self.lastUpdated = userDefaults.object(forKey: "aiConfigLastUpdated") as? Date ?? Date()
        self.lastSynced = userDefaults.object(forKey: "aiConfigLastSynced") as? Date
        self.isSynced = userDefaults.bool(forKey: "aiConfigIsSynced")
    }
    
    // MARK: - 保存到 UserDefaults
    func saveToUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(aiServiceEnabled, forKey: "aiServiceEnabled")
        userDefaults.set(selectedAIModel, forKey: "selectedAIModel")
        userDefaults.set(maxTokens, forKey: "maxTokens")
        userDefaults.set(temperature, forKey: "temperature")
        userDefaults.set(systemPrompt, forKey: "systemPrompt")
        
        userDefaults.set(aiName, forKey: "aiName")
        userDefaults.set(aiPersonality, forKey: "aiPersonality")
        userDefaults.set(aiSpecialties, forKey: "aiSpecialties")
        userDefaults.set(aiResponseStyle, forKey: "aiResponseStyle")
        userDefaults.set(aiLanguage, forKey: "aiLanguage")
        userDefaults.set(aiAvatar, forKey: "aiAvatar")
        
        userDefaults.set(maxContextLength, forKey: "maxContextLength")
        userDefaults.set(enableResponseFiltering, forKey: "enableResponseFiltering")
        userDefaults.set(enableSentimentAnalysis, forKey: "enableSentimentAnalysis")
        userDefaults.set(enableAutoApproval, forKey: "enableAutoApproval")
        userDefaults.set(approvalThreshold, forKey: "approvalThreshold")
        
        // 保存回應模板
        if let templatesData = try? JSONEncoder().encode(responseTemplates) {
            userDefaults.set(templatesData, forKey: "responseTemplates")
        }
        
        userDefaults.set(lastUpdated, forKey: "aiConfigLastUpdated")
        userDefaults.set(lastSynced, forKey: "aiConfigLastSynced")
        userDefaults.set(isSynced, forKey: "aiConfigIsSynced")
    }
    
    // MARK: - 合併配置
    mutating func merge(with remoteConfig: AIAssistantConfig) {
        // 如果遠端配置更新，則使用遠端配置
        if remoteConfig.lastUpdated > self.lastUpdated {
            self = remoteConfig
            self.lastSynced = Date()
            self.isSynced = true
            self.syncError = nil
        }
    }
    
    // MARK: - 標記為已更新
    mutating func markAsUpdated() {
        self.lastUpdated = Date()
        self.isSynced = false
        self.syncError = nil
    }
    
    // MARK: - 標記同步錯誤
    mutating func markSyncError(_ error: String) {
        self.syncError = error
        self.isSynced = false
    }
}

// MARK: - AI 配置請求/回應模型
struct AIAssistantConfigRequest: Codable {
    let config: AIAssistantConfig
}

struct AIAssistantConfigResponse: Codable {
    let success: Bool
    let message: String?
    let data: AIAssistantConfig?
    let error: String?
}

// MARK: - AI 模型列表回應
struct AIModelsResponse: Codable {
    let success: Bool
    let message: String?
    let data: [AIModel]?
    let error: String?
}

struct AIModel: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let maxTokens: Int
    let isAvailable: Bool
    let category: String
} 