//

//  AIConfiguration.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData

@Model
final class AIConfiguration {
    var id: UUID
    var name: String
    var configDescription: String
    var systemPrompt: String
    var modelName: String
    var maxTokens: Int
    var temperature: Double
    var personality: String
    var specialties: String
    var responseStyle: String
    var language: String
    var avatar: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var userId: String
    
    // 新增：進階設定
    var maxContextLength: Int
    var enableResponseFiltering: Bool
    var enableSentimentAnalysis: Bool
    var enableAutoApproval: Bool
    var approvalThreshold: Double
    var customInstructions: String
    var knowledgeBase: String
    var responseTemplates: [String]
    
    // 新增：使用統計
    var totalConversations: Int
    var totalMessages: Int
    var averageResponseTime: Double
    var satisfactionScore: Double
    
    init(name: String, userId: String) {
        self.id = UUID()
        self.name = name
        self.configDescription = "專業的AI客服助理"
        self.systemPrompt = "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
        self.modelName = "gpt-3.5-turbo"
        self.maxTokens = 1000
        self.temperature = 0.7
        self.personality = "友善、專業、耐心"
        self.specialties = "產品諮詢、技術支援、訂單處理"
        self.responseStyle = "正式"
        self.language = "繁體中文"
        self.avatar = "robot"
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = userId
        
        // 進階設定預設值
        self.maxContextLength = 10
        self.enableResponseFiltering = true
        self.enableSentimentAnalysis = false
        self.enableAutoApproval = false
        self.approvalThreshold = 0.8
        self.customInstructions = ""
        self.knowledgeBase = ""
        self.responseTemplates = []
        
        // 統計預設值
        self.totalConversations = 0
        self.totalMessages = 0
        self.averageResponseTime = 0.0
        self.satisfactionScore = 0.0
    }
}

// AI配置模板
struct AIConfigurationTemplate {
    let name: String
    let description: String
    let systemPrompt: String
    let personality: String
    let specialties: String
    let responseStyle: String
    let modelName: String
    let maxTokens: Int
    let temperature: Double
    
    static let templates = [
        AIConfigurationTemplate(
            name: "客服專家",
            description: "專業的客戶服務代表，擅長解決各種客戶問題",
            systemPrompt: "你是一個經驗豐富的客服專家，能夠快速理解客戶需求並提供準確的解決方案。請保持友善、專業的態度，並確保客戶滿意度。",
            personality: "專業、友善、耐心、細心",
            specialties: "產品諮詢、技術支援、訂單處理、退貨換貨、會員服務",
            responseStyle: "正式",
            modelName: "gpt-3.5-turbo",
            maxTokens: 1000,
            temperature: 0.7
        ),
        AIConfigurationTemplate(
            name: "銷售顧問",
            description: "專業的銷售顧問，協助客戶選擇合適的產品",
            systemPrompt: "你是一個專業的銷售顧問，了解客戶需求並推薦最適合的產品。請提供詳細的產品資訊和購買建議，但不要過於推銷。",
            personality: "熱情、專業、誠實、耐心",
            specialties: "產品推薦、價格諮詢、購買流程、優惠活動",
            responseStyle: "友善",
            modelName: "gpt-3.5-turbo",
            maxTokens: 1200,
            temperature: 0.8
        ),
        AIConfigurationTemplate(
            name: "技術支援",
            description: "專業的技術支援工程師，解決技術問題",
            systemPrompt: "你是一個技術支援工程師，擅長解決各種技術問題。請提供詳細的技術說明和解決步驟，確保客戶能夠自行解決問題。",
            personality: "專業、準確、耐心、詳細",
            specialties: "技術問題、故障排除、使用教學、系統設定",
            responseStyle: "專業",
            modelName: "gpt-4",
            maxTokens: 1500,
            temperature: 0.5
        ),
        AIConfigurationTemplate(
            name: "創意助手",
            description: "富有創意的內容創作者，協助創作和設計",
            systemPrompt: "你是一個富有創意的助手，能夠協助客戶進行內容創作、設計建議和創意發想。請提供新穎、有趣且實用的建議。",
            personality: "創意、活潑、有趣、啟發",
            specialties: "內容創作、設計建議、創意發想、文案撰寫",
            responseStyle: "輕鬆",
            modelName: "gpt-4",
            maxTokens: 1500,
            temperature: 0.9
        )
    ]
}

// AI回應模板
struct ResponseTemplate {
    let name: String
    let content: String
    let category: TemplateCategory
    
    static let templates = [
        ResponseTemplate(
            name: "歡迎訊息",
            content: "您好！我是{aiName}，很高興為您服務。請問有什麼我可以幫助您的嗎？",
            category: .greeting
        ),
        ResponseTemplate(
            name: "問題確認",
            content: "我理解您的問題是關於{issue}，讓我為您詳細說明一下解決方案。",
            category: .confirmation
        ),
        ResponseTemplate(
            name: "轉接人工",
            content: "這個問題需要更專業的處理，我將為您轉接人工客服。請稍候，我們的專員會很快為您服務。",
            category: .escalation
        ),
        ResponseTemplate(
            name: "結束對話",
            content: "很高興能幫助您解決問題！如果還有其他需要協助的地方，隨時歡迎聯繫我們。祝您有愉快的一天！",
            category: .farewell
        ),
        ResponseTemplate(
            name: "無法處理",
            content: "抱歉，這個問題超出了我的處理範圍。建議您聯繫人工客服獲得更好的協助。",
            category: .unable
        )
    ]
}

enum TemplateCategory: String, CaseIterable {
    case greeting = "問候"
    case confirmation = "確認"
    case escalation = "轉接"
    case farewell = "告別"
    case unable = "無法處理"
    
    var displayName: String {
        return self.rawValue
    }
}

// AI配置統計
struct AIConfigurationStats {
    let totalConversations: Int
    let totalMessages: Int
    let averageResponseTime: Double
    let satisfactionScore: Double
    let successRate: Double
    let escalationRate: Double
    
    var formattedResponseTime: String {
        return String(format: "%.1fs", averageResponseTime)
    }
    
    var formattedSatisfactionScore: String {
        return String(format: "%.1f", satisfactionScore)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedEscalationRate: String {
        return String(format: "%.1f%%", escalationRate * 100)
    }
} 