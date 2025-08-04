//
//  LineAPIService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import UserNotifications
import Combine
import SwiftData

// MARK: - 資料模型
struct LineIntegration: Codable {
    let tenantId: String
    let tenantName: String
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct LineAPIConversation: Codable {
    let id: String
    let sourceId: String
    let messageCount: Int
    let lastMessage: LineAPILastMessage?
    let createdAt: String
    let updatedAt: String
}

struct LineAPILastMessage: Codable {
    let content: String
    let role: String
    let timestamp: String
}

struct LineAPIMessage: Codable {
    let role: String
    let content: String
    let timestamp: String
}

struct LineAPIConversationDetail: Codable {
    let id: String
    let platform: String
    let tenantId: String
    let sourceId: String
    let messages: [LineAPIMessage]
    let createdAt: String
    let updatedAt: String
}

struct LineStats: Codable {
    let totalConversations: Int
    let totalMessages: Int
    let todayConversations: Int
    let averageMessagesPerConversation: Double
    let lastActivity: String?
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct LineAPIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

struct IntegrationsResponse: Codable {
    let integrations: [LineIntegration]
    let total: Int
}

struct ConversationsResponse: Codable {
    let conversations: [LineAPIConversation]
    let pagination: Pagination
}

struct ConversationResponse: Codable {
    let conversation: LineAPIConversationDetail
}

struct StatsResponse: Codable {
    let tenantId: String
    let stats: LineStats
}

struct SearchResponse: Codable {
    let query: String
    let results: [LineAPIConversation]
    let pagination: Pagination
}

// MARK: - LINE API 設定模型
struct LineAPISettings: Codable {
    let channelSecret: String
    let channelAccessToken: String
    let webhookUrl: String
}

struct LineAPISettingsResponse: Codable {
    let success: Bool
    let data: LineAPISettings?
    let error: String?
    let message: String?
}

// MARK: - Webhook 事件模型
struct WebhookEvent: Codable {
    let type: String
    let message: LineWebhookMessage?
    let replyToken: String?
    let source: LineSource
    let timestamp: Int64
}

struct LineWebhookMessage: Codable {
    let id: String
    let type: String
    let text: String?
    let imageUrl: String?
    let videoUrl: String?
    let audioUrl: String?
    let fileUrl: String?
    let location: LineLocation?
}

struct LineSource: Codable {
    let type: String
    let userId: String?
    let groupId: String?
    let roomId: String?
}

struct LineLocation: Codable {
    let title: String
    let address: String
    let latitude: Double
    let longitude: Double
}

// MARK: - 即時訊息模型
struct RealTimeMessage: Codable, Identifiable {
    var id: UUID
    let tenantId: String
    let sourceId: String
    let content: String
    let role: String
    let timestamp: String
    let messageType: String
    
    init(tenantId: String, sourceId: String, content: String, role: String, timestamp: String, messageType: String) {
        self.id = UUID()
        self.tenantId = tenantId
        self.sourceId = sourceId
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.messageType = messageType
    }
}

// MARK: - LINE API 服務
class LineAPIService: ObservableObject {
    static let shared = LineAPIService()
    
    // 基本設定
    @Published var isConnected = false
    @Published var isWebSocketConnected = false
    @Published var realTimeMessages: [RealTimeMessage] = []
    @Published var lastMessageTime: Date?
    
    // LINE API 設定
    private var channelAccessToken: String {
        UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
    }
    
    private var channelSecret: String {
        UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
    }
    
    private let lineAPIBaseURL = "https://api.line.me/v2"
    private let backendBaseURL = "http://localhost:3000" // 替換為您的實際 API 網址
    
    // WebSocket 相關
    private var webSocketTask: URLSessionWebSocketTask?
    private var timer: Timer?
    
    init() {
        setupNotifications()
        startRealTimeConnection()
    }
    
    // MARK: - 推送通知設定
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("推送通知權限已獲得")
            } else {
                print("推送通知權限被拒絕")
            }
        }
    }
    
    // MARK: - 即時連接
    private func startRealTimeConnection() {
        // 將 HTTP URL 轉換為 WebSocket URL
        let wsURL = backendBaseURL.replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(wsURL)/api/realtime/line") else { return }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        startPingTimer()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self?.handleRealTimeMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleRealTimeMessage(text)
                        }
                    @unknown default:
                        break
                    }
                case .failure(let error):
                    print("WebSocket 接收錯誤: \(error)")
                    self?.isWebSocketConnected = false
                }
                
                // 繼續接收下一個訊息
                self?.receiveMessage()
            }
        }
    }
    
    private func handleRealTimeMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(RealTimeMessage.self, from: data) else {
            return
        }
        
        realTimeMessages.append(message)
        lastMessageTime = Date()
        sendLocalNotification(for: message)
    }
    
    private func startPingTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { error in
            if let error = error {
                print("Ping 錯誤: \(error)")
            }
        }
    }
    
    private func sendLocalNotification(for message: RealTimeMessage) {
        let content = UNMutableNotificationContent()
        content.title = "新 LINE 訊息"
        content.body = message.content
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: message.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - 通用網路請求方法
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: "\(backendBaseURL)\(endpoint)") else {
            completion(.failure(LineAPIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(LineAPIError.noData))
                    return
                }
                
                do {
                    let apiResponse = try JSONDecoder().decode(LineAPIResponse<T>.self, from: data)
                    
                    if apiResponse.success, let responseData = apiResponse.data {
                        completion(.success(responseData))
                    } else {
                        completion(.failure(LineAPIError.serverError(apiResponse.error ?? "未知錯誤")))
                    }
                } catch {
                    completion(.failure(LineAPIError.decodingError))
                }
            }
        }.resume()
    }
    
    // MARK: - LINE 基本 API 功能
    
    /// 檢查 LINE API 連線
    func checkConnection() async -> Bool {
        guard !channelAccessToken.isEmpty else {
            await MainActor.run { [weak self] in
                self?.isConnected = false
            }
            return false
        }
        
        let url = URL(string: "\(lineAPIBaseURL)/bot/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(channelAccessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let connected = httpResponse.statusCode == 200
                await MainActor.run { [weak self] in
                    self?.isConnected = connected
                }
                return connected
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.isConnected = false
            }
        }
        
        return false
    }
    
    /// 發送訊息到 LINE
    func sendMessageToLine(message: String, customerId: String) async throws -> Bool {
        guard !channelAccessToken.isEmpty else {
            throw LineError.invalidCredentials
        }
        
        let url = URL(string: "\(lineAPIBaseURL)/bot/message/push")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(channelAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageBody: [String: Any] = [
            "to": customerId,
            "messages": [
                [
                    "type": "text",
                    "text": message
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: messageBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineError.networkError
            }
            
            if httpResponse.statusCode == 200 {
                return true
            } else {
                // 解析錯誤訊息
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorData["message"] as? String {
                    throw LineError.apiError(message)
                } else {
                    throw LineError.sendFailed
                }
            }
        } catch {
            throw LineError.networkError
        }
    }
    
    // MARK: - 後端 API 功能
    
    /// 獲取所有 LINE 整合
    func getLineIntegrations(completion: @escaping (Result<IntegrationsResponse, Error>) -> Void) {
        makeRequest(endpoint: "/api/mobile/line-integrations", completion: completion)
    }
    
    /// 獲取特定租戶的對話記錄
    func getConversations(
        tenantId: String,
        page: Int = 1,
        limit: Int = 20,
        completion: @escaping (Result<ConversationsResponse, Error>) -> Void
    ) {
        let endpoint = "/api/mobile/line-conversations/\(tenantId)?page=\(page)&limit=\(limit)"
        makeRequest(endpoint: endpoint, completion: completion)
    }
    
    /// 獲取特定對話的詳細訊息
    func getConversationDetail(
        conversationId: String,
        completion: @escaping (Result<ConversationResponse, Error>) -> Void
    ) {
        makeRequest(endpoint: "/api/mobile/conversation/\(conversationId)", completion: completion)
    }
    
    /// 發送測試訊息到 LINE
    func sendTestMessage(
        tenantId: String,
        message: String,
        userId: String,
        completion: @escaping (Result<LineAPIResponse<[String: String]>, Error>) -> Void
    ) {
        let body = ["message": message, "userId": userId]
        makeRequest(
            endpoint: "/api/mobile/line-test-message/\(tenantId)",
            method: "POST",
            body: body,
            completion: completion
        )
    }
    
    /// 獲取 LINE 整合統計資料
    func getLineStats(
        tenantId: String,
        completion: @escaping (Result<StatsResponse, Error>) -> Void
    ) {
        makeRequest(endpoint: "/api/mobile/line-stats/\(tenantId)", completion: completion)
    }
    
    /// 搜尋對話記錄
    func searchConversations(
        tenantId: String,
        query: String,
        page: Int = 1,
        limit: Int = 20,
        completion: @escaping (Result<SearchResponse, Error>) -> Void
    ) {
        let endpoint = "/api/mobile/search-conversations/\(tenantId)?query=\(query)&page=\(page)&limit=\(limit)"
        makeRequest(endpoint: endpoint, completion: completion)
    }
    
    /// 發送訊息到 LINE 用戶
    func sendMessage(
        tenantId: String,
        userId: String,
        message: String,
        completion: @escaping (Result<LineAPIResponse<[String: String]>, Error>) -> Void
    ) {
        let body = ["message": message, "userId": userId]
        makeRequest(
            endpoint: "/api/mobile/send-message/\(tenantId)",
            method: "POST",
            body: body,
            completion: completion
        )
    }
    
    /// 獲取 LINE 用戶資料
    func getUserProfile(
        tenantId: String,
        userId: String,
        completion: @escaping (Result<LineAPIResponse<UserProfileData>, Error>) -> Void
    ) {
        makeRequest(endpoint: "/api/mobile/user-profile/\(tenantId)/\(userId)", completion: completion)
    }
    
    // MARK: - Webhook URL 管理
    
    /// 自動生成 webhook URL
    func autoSetupWebhookURL() -> String {
        let currentConfig = ConfigurationManager.shared.currentConfig
        let userId = UserDefaults.standard.integer(forKey: "currentUserId")
        
        // 生成格式：https://domain.com/api/webhook/line/{userId}
        let webhookURL = "\(currentConfig.baseURL)/webhook/line/\(userId)"
        return webhookURL
    }
    
    /// 獲取當前的 webhook URL
    func getCurrentWebhookURL() -> String {
        let currentConfig = ConfigurationManager.shared.currentConfig
        let userId = UserDefaults.standard.integer(forKey: "currentUserId")
        return "\(currentConfig.baseURL)/webhook/line/\(userId)"
    }
    
    /// 驗證 webhook URL 格式
    func validateWebhookURL(_ url: String) -> Bool {
        guard let url = URL(string: url) else { return false }
        
        // 檢查是否為有效的 HTTPS URL
        guard url.scheme == "https" else { return false }
        
        // 檢查是否包含必要的路徑
        let path = url.path
        return path.contains("/webhook/line/")
    }
    
    /// 生成自定義 webhook URL
    func generateCustomWebhookURL(baseURL: String, userId: Int) -> String {
        let cleanBaseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(cleanBaseURL)/api/webhook/line/\(userId)"
    }
    
    /// 測試 webhook URL 是否可訪問
    func testWebhookURL(_ url: String) async -> Bool {
        guard let url = URL(string: url) else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200 || httpResponse.statusCode == 404
            }
        } catch {
            print("Webhook URL 測試失敗: \(error)")
        }
        return false
    }
    
    /// 獲取 webhook URL 建議列表
    func getWebhookURLSuggestions() -> [String] {
        let currentConfig = ConfigurationManager.shared.currentConfig
        let userId = UserDefaults.standard.integer(forKey: "currentUserId")
        
        return [
            "\(currentConfig.baseURL)/webhook/line/\(userId)",
            "\(currentConfig.baseURL)/webhook/line-simple",
            "https://ai-chatbot-umqm.onrender.com/api/webhook/line/\(userId)"
        ]
    }
    
    // MARK: - LINE API 設定管理
    
    /// 從後端獲取 LINE API 設定
    func fetchLineAPISettings() async throws -> LineAPISettings {
        guard let url = URL(string: "\(ConfigurationManager.shared.currentConfig.baseURL)/api/line-api/settings") else {
            throw LineAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineAPIError.serverError("無效的伺服器回應")
            }
            
            if httpResponse.statusCode == 200 {
                let settingsResponse = try JSONDecoder().decode(LineAPISettingsResponse.self, from: data)
                
                if settingsResponse.success, let settings = settingsResponse.data {
                    return settings
                } else {
                    throw LineAPIError.serverError(settingsResponse.error ?? "獲取設定失敗")
                }
            } else {
                throw LineAPIError.serverError("獲取設定失敗，狀態碼：\(httpResponse.statusCode)")
            }
        } catch {
            if error is DecodingError {
                throw LineAPIError.decodingError
            }
            throw LineAPIError.serverError(error.localizedDescription)
        }
    }
    
    /// 儲存 LINE API 設定到後端
    func saveLineAPISettings(channelSecret: String, channelAccessToken: String) async throws -> Bool {
        guard let url = URL(string: "\(ConfigurationManager.shared.currentConfig.baseURL)/api/line-api/settings") else {
            throw LineAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let settingsData = [
            "channelSecret": channelSecret,
            "channelAccessToken": channelAccessToken
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settingsData)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineAPIError.serverError("無效的伺服器回應")
            }
            
            if httpResponse.statusCode == 200 {
                let settingsResponse = try JSONDecoder().decode(LineAPISettingsResponse.self, from: data)
                return settingsResponse.success
            } else {
                throw LineAPIError.serverError("儲存設定失敗，狀態碼：\(httpResponse.statusCode)")
            }
        } catch {
            if error is DecodingError {
                throw LineAPIError.decodingError
            }
            throw LineAPIError.serverError(error.localizedDescription)
        }
    }
    
    /// 同步 webhook URL 到後端
    func syncWebhookURLToBackend() async throws -> Bool {
        let webhookURL = getCurrentWebhookURL()
        
        guard let url = URL(string: "\(ConfigurationManager.shared.currentConfig.baseURL)/api/line-token") else {
            throw LineAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let webhookData = ["webhookUrl": webhookURL]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: webhookData)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineAPIError.serverError("無效的伺服器回應")
            }
            
            if httpResponse.statusCode == 200 {
                return true
            } else {
                throw LineAPIError.serverError("同步失敗，狀態碼：\(httpResponse.statusCode)")
            }
        } catch {
            throw LineAPIError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - 用戶專屬 Webhook URL 管理
    
    /// 獲取用戶資料和 ID
    func getUserProfile() async throws -> UserProfileData {
        guard let url = URL(string: "\(ConfigurationManager.shared.currentConfig.baseURL)/api/user/profile") else {
            throw LineAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineAPIError.serverError("無效的伺服器回應")
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(LineAPIResponse<UserProfileData>.self, from: data)
                
                if apiResponse.success, let userData = apiResponse.data {
                    return userData
                } else {
                    throw LineAPIError.serverError(apiResponse.error ?? "獲取用戶資料失敗")
                }
            } else {
                throw LineAPIError.serverError("獲取用戶資料失敗，狀態碼：\(httpResponse.statusCode)")
            }
        } catch {
            if error is DecodingError {
                throw LineAPIError.decodingError
            }
            throw LineAPIError.serverError(error.localizedDescription)
        }
    }
    
    /// 生成用戶專屬的 webhook URL
    func generateUserSpecificWebhookURL(userId: String) -> String {
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        let cleanBaseURL = baseURL.replacingOccurrences(of: "/api", with: "")
        let webhookURL = "\(cleanBaseURL)/api/webhook/line/\(userId)"
        
        print("🔗 LineAPIService - 生成 webhook URL:")
        print("   - 原始 baseURL: \(baseURL)")
        print("   - 清理後 baseURL: \(cleanBaseURL)")
        print("   - 用戶 ID: \(userId)")
        print("   - 最終 URL: \(webhookURL)")
        
        return webhookURL
    }
    
    /// 同步用戶 webhook URL 到後端
    func syncUserWebhookURL(userId: String, webhookURL: String) async throws -> Bool {
        guard let url = URL(string: "\(ConfigurationManager.shared.currentConfig.baseURL)/api/user/webhook-url") else {
            throw LineAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let webhookData: [String: Any] = [
            "userId": userId,
            "webhookUrl": webhookURL,
            "platform": "line",
            "isActive": true,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: webhookData)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineAPIError.serverError("無效的伺服器回應")
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(LineAPIResponse<[String: String]>.self, from: data)
                return apiResponse.success
            } else {
                throw LineAPIError.serverError("同步失敗，狀態碼：\(httpResponse.statusCode)")
            }
        } catch {
            if error is DecodingError {
                throw LineAPIError.decodingError
            }
            throw LineAPIError.serverError(error.localizedDescription)
        }
    }
    
    /// 獲取用戶的 webhook URL 設定
    func getUserWebhookURL() async throws -> String {
        guard let url = URL(string: "\(ConfigurationManager.shared.currentConfig.baseURL)/api/user/webhook-url") else {
            throw LineAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LineAPIError.serverError("無效的伺服器回應")
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userData = json["data"] as? [String: Any],
                   let webhookUrl = userData["webhookUrl"] as? String {
                    return webhookUrl
                } else {
                    throw LineAPIError.serverError("無法解析 webhook URL")
                }
            } else {
                throw LineAPIError.serverError("獲取 webhook URL 失敗，狀態碼：\(httpResponse.statusCode)")
            }
        } catch {
            throw LineAPIError.serverError(error.localizedDescription)
        }
    }

    deinit {
        timer?.invalidate()
        webSocketTask?.cancel()
    }
}

// MARK: - 用戶資料模型
struct UserProfileData: Codable {
    let userId: String
    let displayName: String
    let pictureUrl: String?
    let statusMessage: String?
}

// MARK: - LINE API 錯誤處理
enum LineAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .noData:
            return "沒有收到資料"
        case .decodingError:
            return "資料解析錯誤"
        case .serverError(let message):
            return message
        }
    }
} 