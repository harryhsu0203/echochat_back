//
//  AIService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

class AIService: ObservableObject {
    @Published var isLoading = false
    @Published var isConfigured = false
    
    // 從UserDefaults讀取設定
    private var apiURL: String {
        // 使用你的 Windows 後端 API 端點
        // 請將 YOUR_WINDOWS_IP 替換為你的 Windows 電腦 IP 地址
        "http://YOUR_WINDOWS_IP:3000/api/ai/chat"
    }
    
    private var apiKey: String {
        // 使用用戶的認證token，而不是OpenAI API key
        UserDefaults.standard.string(forKey: "userToken") ?? ""
    }
    
    private var modelName: String {
        UserDefaults.standard.string(forKey: "selectedAIModel") ?? "客服專家"
    }
    
    private var maxTokens: Int {
        let value = UserDefaults.standard.integer(forKey: "maxTokens")
        return value > 0 ? value : 1000
    }
    
    private var temperature: Double {
        let value = UserDefaults.standard.double(forKey: "temperature")
        return value > 0 ? value : 0.7
    }
    
    private var systemPrompt: String {
        UserDefaults.standard.string(forKey: "systemPrompt") ?? "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
    }
    
    // 新增：AI助理個性化設定
    private var aiName: String {
        UserDefaults.standard.string(forKey: "aiName") ?? "EchoChat 助理"
    }
    
    private var aiPersonality: String {
        UserDefaults.standard.string(forKey: "aiPersonality") ?? "友善、專業、耐心"
    }
    
    private var aiSpecialties: String {
        UserDefaults.standard.string(forKey: "aiSpecialties") ?? "產品諮詢、技術支援、訂單處理"
    }
    
    private var aiResponseStyle: String {
        UserDefaults.standard.string(forKey: "aiResponseStyle") ?? "正式"
    }
    
    private var aiLanguage: String {
        UserDefaults.standard.string(forKey: "aiLanguage") ?? "繁體中文"
    }
    
    // 新增：對話上下文管理
    private var maxContextLength: Int {
        let value = UserDefaults.standard.integer(forKey: "maxContextLength")
        return value > 0 ? value : 10
    }
    
    // 新增：回應品質控制
    private var enableResponseFiltering: Bool {
        UserDefaults.standard.bool(forKey: "enableResponseFiltering")
    }
    
    private var enableSentimentAnalysis: Bool {
        UserDefaults.standard.bool(forKey: "enableSentimentAnalysis")
    }
    
    init() {
        checkConfiguration()
    }
    
    private func checkConfiguration() {
        // 檢查用戶是否已啟用AI服務
        let aiServiceEnabled = UserDefaults.standard.bool(forKey: "aiServiceEnabled")
        isConfigured = aiServiceEnabled && !systemPrompt.isEmpty
    }
    
    func generateResponse(for message: String, conversationHistory: [ChatMessage]) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        // 檢查AI服務是否已啟用
        let aiServiceEnabled = UserDefaults.standard.bool(forKey: "aiServiceEnabled")
        guard aiServiceEnabled else {
            throw AIError.serviceNotEnabled
        }
        
        // 構建增強的系統提示詞
        let enhancedSystemPrompt = buildEnhancedSystemPrompt()
        
        // 構建對話歷史（限制上下文長度）
        let messages = buildMessages(from: conversationHistory, currentMessage: message, systemPrompt: enhancedSystemPrompt)
        
        let requestBody = ChatCompletionRequest(
            model: modelName,
            messages: messages,
            max_tokens: maxTokens > 0 ? maxTokens : 1000,
            temperature: temperature > 0 ? temperature : 0.7
        )
        
        guard let url = URL(string: apiURL) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }
        
        // 增強的錯誤處理
        switch httpResponse.statusCode {
        case 200:
            do {
                let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                let response = chatResponse.choices.first?.message.content ?? "抱歉，我無法回應您的訊息。"
                
                // 新增：回應品質檢查
                if enableResponseFiltering {
                    return filterResponse(response)
                }
                
                return response
            } catch {
                throw AIError.decodingError
            }
        case 401:
            throw AIError.invalidToken
        case 429:
            throw AIError.rateLimitExceeded
        case 500...599:
            throw AIError.serverError
        default:
            throw AIError.networkError
        }
    }
    
    // 新增：構建增強的系統提示詞
    private func buildEnhancedSystemPrompt() -> String {
        var prompt = systemPrompt
        
        // 添加AI助理個性化設定
        if !aiName.isEmpty {
            prompt += "\n\n你的名字是：\(aiName)"
        }
        
        if !aiPersonality.isEmpty {
            prompt += "\n你的個性特質：\(aiPersonality)"
        }
        
        if !aiSpecialties.isEmpty {
            prompt += "\n你的專業領域：\(aiSpecialties)"
        }
        
        if !aiResponseStyle.isEmpty {
            prompt += "\n回應風格：\(aiResponseStyle)"
        }
        
        if !aiLanguage.isEmpty {
            prompt += "\n請使用\(aiLanguage)回應。"
        }
        
        // 添加客服最佳實踐
        prompt += """
        
        客服最佳實踐：
        1. 始終保持友善和專業的態度
        2. 如果無法立即解決問題，請承諾跟進並提供時間表
        3. 使用客戶的名字（如果知道）
        4. 提供具體的解決方案，而不是模糊的承諾
        5. 在結束對話前確認問題是否已解決
        6. 如果問題需要人工處理，請明確說明並提供轉接流程
        """
        
        return prompt
    }
    
    private func buildMessages(from history: [ChatMessage], currentMessage: String, systemPrompt: String) -> [Message] {
        var messages: [Message] = []
        
        // 添加系統訊息
        messages.append(Message(role: "system", content: systemPrompt))
        
        // 限制對話歷史長度
        let limitedHistory = Array(history.suffix(maxContextLength))
        
        // 添加對話歷史
        for chatMessage in limitedHistory {
            let role = chatMessage.isFromUser ? "user" : "assistant"
            messages.append(Message(role: role, content: chatMessage.content))
        }
        
        // 添加當前訊息
        messages.append(Message(role: "user", content: currentMessage))
        
        return messages
    }
    
    // 新增：回應品質過濾
    private func filterResponse(_ response: String) -> String {
        var filteredResponse = response
        
        // 移除不當內容
        let inappropriateWords = ["不當", "違規", "敏感"]
        for word in inappropriateWords {
            if filteredResponse.contains(word) {
                filteredResponse = "抱歉，我無法提供該資訊。請聯繫人工客服。"
                break
            }
        }
        
        // 確保回應長度合理
        if filteredResponse.count > 500 {
            filteredResponse = String(filteredResponse.prefix(500)) + "..."
        }
        
        return filteredResponse
    }
    
    // 新增：測試API連線
    func testAPIConnection() async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw AIError.configurationError
        }
        
        let testMessage = "你好"
        let response = try await generateResponse(for: testMessage, conversationHistory: [])
        return !response.isEmpty
    }
    
    // 新增：獲取模型資訊
    func getAvailableModels() async throws -> [String] {
        guard !apiKey.isEmpty else {
            throw AIError.configurationError
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.networkError
        }
        
        do {
            let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
            return modelsResponse.data.map { $0.id }
        } catch {
            throw AIError.decodingError
        }
    }
}

// MARK: - 資料模型
struct Message: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

// 新增：模型回應結構
struct ModelsResponse: Codable {
    let data: [ModelData]
}

struct ModelData: Codable {
    let id: String
    let object: String
    let created: Int
    let owned_by: String
}

// MARK: - 增強的錯誤處理
enum AIError: Error, LocalizedError {
    case invalidURL
    case networkError
    case encodingError
    case decodingError
    case serviceNotEnabled
    case invalidToken
    case rateLimitExceeded
    case serverError
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的URL"
        case .networkError:
            return "網路連線錯誤"
        case .encodingError:
            return "資料編碼錯誤"
        case .decodingError:
            return "資料解碼錯誤"
        case .serviceNotEnabled:
            return "請先啟用AI服務"
        case .invalidToken:
            return "認證失敗，請重新登入"
        case .rateLimitExceeded:
            return "服務使用量已達上限，請稍後再試"
        case .serverError:
            return "伺服器錯誤，請稍後再試"
        case .configurationError:
            return "AI配置錯誤，請檢查設定"
        }
    }
} 