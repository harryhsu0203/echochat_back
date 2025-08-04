import Foundation

// MARK: - API 錯誤類型
enum EchoChatAPIError: Error, LocalizedError {
    case noAuthToken
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case notFound
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAuthToken:
            return "未提供認證 Token"
        case .invalidResponse:
            return "無效的伺服器回應"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .decodingError(let error):
            return "資料解析錯誤: \(error.localizedDescription)"
        case .serverError(let message):
            return "伺服器錯誤: \(message)"
        case .unauthorized:
            return "認證失敗，請重新登入"
        case .notFound:
            return "找不到請求的資源"
        case .validationError(let message):
            return "驗證錯誤: \(message)"
        }
    }
}

// MARK: - API 回應模型
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let error: String?
    let data: T?
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String
    let user: User
    let error: String?
}

struct User: Codable {
    let id: Int
    let username: String
    let name: String
    let role: String
    let email: String?
    let picture: String?
    let loginMethod: String?
}

struct ChatResponse: Codable {
    let success: Bool
    let response: String
    let conversationId: String
    let timestamp: String
    let error: String?
}

struct Conversation: Codable {
    let id: String
    let platform: String
    let messages: [Message]
    let createdAt: String
    let updatedAt: String
}

struct Message: Codable {
    let role: String
    let content: String
    let timestamp: String
}

struct AIAssistantConfig: Codable {
    let assistant_name: String
    let llm: String
    let use_case: String
    let description: String
}

struct AIModel: Codable {
    let id: String
    let name: String
    let description: String
}

struct LineConfig: Codable {
    let channelAccessToken: String
    let channelSecret: String
}

// MARK: - EchoChat API 客戶端
class EchoChatAPIClient {
    static let shared = EchoChatAPIClient()
    
    private let baseURL: String
    private var authToken: String?
    
    init(baseURL: String = "https://your-api-url.onrender.com/api") {
        self.baseURL = baseURL
    }
    
    // MARK: - 認證相關
    
    /// 用戶登入
    func login(username: String, password: String, completion: @escaping (Result<LoginResponse, EchoChatAPIError>) -> Void) {
        let endpoint = "/login"
        let body = ["username": username, "password": password]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false) { (result: Result<LoginResponse, EchoChatAPIError>) in
            switch result {
            case .success(let response):
                self.authToken = response.token
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Google 登入
    func loginWithGoogle(idToken: String, completion: @escaping (Result<LoginResponse, EchoChatAPIError>) -> Void) {
        let endpoint = "/auth/google"
        let body = ["idToken": idToken]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false) { (result: Result<LoginResponse, EchoChatAPIError>) in
            switch result {
            case .success(let response):
                self.authToken = response.token
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 發送電子郵件驗證碼
    func sendVerificationCode(email: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/send-verification-code"
        let body = ["email": email]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false, completion: completion)
    }
    
    /// 驗證電子郵件驗證碼
    func verifyCode(email: String, code: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/verify-code"
        let body = ["email": email, "code": code]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false, completion: completion)
    }
    
    /// 用戶註冊
    func register(username: String, email: String, password: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/register"
        let body = ["username": username, "email": email, "password": password]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false, completion: completion)
    }
    
    /// 忘記密碼
    func forgotPassword(email: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/forgot-password"
        let body = ["email": email]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false, completion: completion)
    }
    
    /// 重設密碼
    func resetPassword(email: String, code: String, newPassword: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/reset-password"
        let body = ["email": email, "code": code, "newPassword": newPassword]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: false, completion: completion)
    }
    
    // MARK: - 用戶管理
    
    /// 獲取當前用戶資訊
    func getCurrentUser(completion: @escaping (Result<APIResponse<User>, EchoChatAPIError>) -> Void) {
        let endpoint = "/me"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    /// 獲取個人資料
    func getProfile(completion: @escaping (Result<APIResponse<User>, EchoChatAPIError>) -> Void) {
        let endpoint = "/profile"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    /// 更新個人資料
    func updateProfile(name: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/profile"
        let body = ["name": name]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true, completion: completion)
    }
    
    /// 更改密碼
    func changePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/change-password"
        let body = ["currentPassword": currentPassword, "newPassword": newPassword]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true, completion: completion)
    }
    
    /// 刪除帳號
    func deleteAccount(password: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/delete-account"
        let body = ["password": password]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true, completion: completion)
    }
    
    // MARK: - AI 聊天功能
    
    /// 發送聊天訊息
    func sendMessage(_ message: String, conversationId: String? = nil, completion: @escaping (Result<ChatResponse, EchoChatAPIError>) -> Void) {
        let endpoint = "/chat"
        var body: [String: Any] = ["message": message]
        if let conversationId = conversationId {
            body["conversationId"] = conversationId
        }
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true, completion: completion)
    }
    
    /// 獲取對話歷史
    func getConversations(completion: @escaping (Result<APIResponse<[Conversation]>, EchoChatAPIError>) -> Void) {
        let endpoint = "/conversations"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    /// 獲取特定對話
    func getConversation(id: String, completion: @escaping (Result<APIResponse<Conversation>, EchoChatAPIError>) -> Void) {
        let endpoint = "/conversations/\(id)"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    /// 刪除對話
    func deleteConversation(id: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/conversations/\(id)"
        makeRequest(endpoint: endpoint, method: "DELETE", requiresAuth: true, completion: completion)
    }
    
    // MARK: - AI 助理配置
    
    /// 獲取 AI 助理配置
    func getAIAssistantConfig(completion: @escaping (Result<APIResponse<AIAssistantConfig>, EchoChatAPIError>) -> Void) {
        let endpoint = "/ai-assistant-config"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    /// 更新 AI 助理配置
    func updateAIAssistantConfig(config: AIAssistantConfig, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/ai-assistant-config"
        let body = [
            "assistant_name": config.assistant_name,
            "llm": config.llm,
            "use_case": config.use_case,
            "description": config.description
        ]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true, completion: completion)
    }
    
    /// 重設 AI 助理配置
    func resetAIAssistantConfig(completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/ai-assistant-config/reset"
        makeRequest(endpoint: endpoint, method: "POST", requiresAuth: true, completion: completion)
    }
    
    /// 獲取可用的 AI 模型
    func getAIModels(completion: @escaping (Result<APIResponse<[AIModel]>, EchoChatAPIError>) -> Void) {
        let endpoint = "/ai-models"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    // MARK: - LINE 機器人整合
    
    /// 獲取 LINE Token
    func getLineToken(completion: @escaping (Result<APIResponse<LineConfig>, EchoChatAPIError>) -> Void) {
        let endpoint = "/line-token"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: true, completion: completion)
    }
    
    /// 更新 LINE Token
    func updateLineToken(channelAccessToken: String, channelSecret: String, completion: @escaping (Result<APIResponse<String>, EchoChatAPIError>) -> Void) {
        let endpoint = "/line-token"
        let body = ["channelAccessToken": channelAccessToken, "channelSecret": channelSecret]
        
        makeRequest(endpoint: endpoint, method: "POST", body: body, requiresAuth: true, completion: completion)
    }
    
    // MARK: - 系統功能
    
    /// 健康檢查
    func healthCheck(completion: @escaping (Result<APIResponse<[String: String]>, EchoChatAPIError>) -> Void) {
        let endpoint = "/health"
        makeRequest(endpoint: endpoint, method: "GET", requiresAuth: false, completion: completion)
    }
    
    // MARK: - 工具方法
    
    /// 登出
    func logout() {
        authToken = nil
    }
    
    /// 檢查是否已登入
    var isLoggedIn: Bool {
        return authToken != nil
    }
    
    /// 獲取當前 Token
    var currentToken: String? {
        return authToken
    }
    
    // MARK: - 私有方法
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool = false,
        completion: @escaping (Result<T, EchoChatAPIError>) -> Void
    ) {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            guard let token = authToken else {
                completion(.failure(.noAuthToken))
                return
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                // 檢查 HTTP 狀態碼
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 401:
                        completion(.failure(.unauthorized))
                        return
                    case 404:
                        completion(.failure(.notFound))
                        return
                    case 400...499:
                        // 嘗試解析錯誤訊息
                        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                            completion(.failure(.validationError(errorResponse.error ?? "驗證錯誤")))
                        } else {
                            completion(.failure(.validationError("請求錯誤")))
                        }
                        return
                    case 500...599:
                        completion(.failure(.serverError("伺服器錯誤")))
                        return
                    default:
                        break
                    }
                }
                
                // 解析回應
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }.resume()
    }
}

// MARK: - 使用範例擴展
extension EchoChatAPIClient {
    
    /// 完整的登入流程範例
    func loginFlow(username: String, password: String, completion: @escaping (Result<User, EchoChatAPIError>) -> Void) {
        login(username: username, password: password) { result in
            switch result {
            case .success(let response):
                completion(.success(response.user))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 完整的註冊流程範例
    func registerFlow(username: String, email: String, password: String, completion: @escaping (Result<Bool, EchoChatAPIError>) -> Void) {
        // 1. 發送驗證碼
        sendVerificationCode(email: email) { [weak self] result in
            switch result {
            case .success(let response):
                // 2. 驗證碼會直接返回在 response.data 中（如果郵件服務不可用）
                if let code = response.data {
                    // 3. 驗證驗證碼
                    self?.verifyCode(email: email, code: code) { verifyResult in
                        switch verifyResult {
                        case .success(_):
                            // 4. 註冊用戶
                            self?.register(username: username, email: email, password: password) { registerResult in
                                switch registerResult {
                                case .success(_):
                                    completion(.success(true))
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.failure(.validationError("無法獲取驗證碼")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 完整的忘記密碼流程範例
    func forgotPasswordFlow(email: String, completion: @escaping (Result<Bool, EchoChatAPIError>) -> Void) {
        // 1. 發送重設密碼驗證碼
        forgotPassword(email: email) { [weak self] result in
            switch result {
            case .success(let response):
                // 2. 驗證碼會直接返回在 response.data 中（如果郵件服務不可用）
                if let code = response.data {
                    // 3. 這裡通常會讓用戶輸入新密碼，然後調用 resetPassword
                    // 為了示範，我們假設新密碼是 "newpassword123"
                    self?.resetPassword(email: email, code: code, newPassword: "newpassword123") { resetResult in
                        switch resetResult {
                        case .success(_):
                            completion(.success(true))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.failure(.validationError("無法獲取驗證碼")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
} 