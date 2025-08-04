//
//  APIService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - API 配置
// 使用 ConfigurationManager 來管理 API 配置

// MARK: - API 錯誤
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case decodingError
    case unauthorized
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .invalidResponse:
            return "無效的伺服器回應"
        case .serverError(let code):
            return "伺服器錯誤 (HTTP \(code))"
        case .decodingError:
            return "資料解析錯誤"
        case .unauthorized:
            return "未授權，請重新登入"
        case .unknown:
            return "未知錯誤"
        }
    }
}

// MARK: - API 回應模型
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
    let error: String?
}

// MARK: - 用戶相關 API 模型
struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
}

struct SendVerificationCodeRequest: Codable {
    let email: String
}

struct VerifyCodeRequest: Codable {
    let email: String
    let code: String
}

struct ChangePasswordRequest: Codable {
    let oldPassword: String
    let newPassword: String
}

struct DeleteAccountRequest: Codable {
    let password: String
}

struct UserResponse: Codable {
    let id: Int  // 修改為 Int 來匹配後端回應
    let username: String
    let name: String  // 後端返回 name 而不是 email
    let role: String
    
    func toUser() -> User {
        let user = User(
            username: username,
            email: "\(username)@echochat.com", // 使用 username 生成 email
            passwordHash: "", // 不從 API 獲取密碼
            role: UserRole(rawValue: role) ?? .operator_role
        )
        user.id = UUID() // 生成新的 UUID
        user.isActive = true
        user.lastLoginTime = Date()
        user.createdAt = Date()
        user.companyName = name // 使用 name 作為公司名稱
        
        return user
    }
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String
    let user: UserResponse
}

// MARK: - API 服務
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let session: URLSession
    private var authToken: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        let currentConfig = ConfigurationManager.shared.currentConfig
        config.timeoutIntervalForRequest = currentConfig.timeout
        config.timeoutIntervalForResource = currentConfig.timeout
        self.session = URLSession(configuration: config)
        
        // 從 UserDefaults 讀取 token
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
    }
    
    // MARK: - 通用請求方法
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    // 直接解碼為目標類型（你的後端直接返回 JSON 物件）
                    let result = try decoder.decode(T.self, from: data)
                    return result
                } catch {
                    print("Decoding error: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    print("HTTP Status: \(httpResponse.statusCode)")
                    print("URL: \(url)")
                    throw APIError.decodingError
                }
                
            case 401:
                // 清除無效的 token
                UserDefaults.standard.removeObject(forKey: "authToken")
                self.authToken = nil
                
                // 嘗試解析錯誤訊息
                if let errorData = String(data: data, encoding: .utf8) {
                    print("401 Error Response: \(errorData)")
                }
                throw APIError.unauthorized
                
            case 400...499:
                // 嘗試解析錯誤訊息
                if let errorData = String(data: data, encoding: .utf8) {
                    print("\(httpResponse.statusCode) Error Response: \(errorData)")
                }
                throw APIError.serverError(httpResponse.statusCode)
                
            case 500...599:
                throw APIError.serverError(httpResponse.statusCode)
                
            default:
                throw APIError.unknown
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // MARK: - 認證相關 API
    func login(username: String, password: String) async throws -> (user: User, token: String) {
        let loginRequest = LoginRequest(username: username, password: password)
        let jsonData = try JSONEncoder().encode(loginRequest)
        
        let response: LoginResponse = try await makeRequest(
            endpoint: APIEndpoints.login,
            method: .POST,
            body: jsonData,
            requiresAuth: false
        )
        
        guard response.success else {
            throw APIError.serverError(400)
        }
        
        // 保存 token
        UserDefaults.standard.set(response.token, forKey: "authToken")
        self.authToken = response.token
        
        return (response.user.toUser(), response.token)
    }
    
    func register(username: String, email: String, password: String) async throws -> Bool {
        let registerRequest = RegisterRequest(
            username: username,
            email: email,
            password: password
        )
        let jsonData = try JSONEncoder().encode(registerRequest)
        
        let response: RegisterResponse = try await makeRequest(
            endpoint: APIEndpoints.register,
            method: .POST,
            body: jsonData,
            requiresAuth: false
        )
        
        return response.success
    }
    
    func sendVerificationCode(email: String) async throws -> Bool {
        let request = SendVerificationCodeRequest(email: email)
        let jsonData = try JSONEncoder().encode(request)
        
        let response: VerificationCodeResponse = try await makeRequest(
            endpoint: APIEndpoints.sendVerificationCode,
            method: .POST,
            body: jsonData,
            requiresAuth: false
        )
        
        return response.success
    }
    
    func verifyCode(email: String, code: String) async throws -> String {
        let request = VerifyCodeRequest(email: email, code: code)
        let jsonData = try JSONEncoder().encode(request)
        
        let response: VerifyCodeResponse = try await makeRequest(
            endpoint: APIEndpoints.verifyCode,
            method: .POST,
            body: jsonData,
            requiresAuth: false
        )
        
        guard response.success, let token = response.token else {
            throw APIError.serverError(400)
        }
        
        // 保存 token
        UserDefaults.standard.set(token, forKey: "authToken")
        self.authToken = token
        
        return token
    }
    
    func logout() async throws {
        // 清除本地 token
        UserDefaults.standard.removeObject(forKey: "authToken")
        self.authToken = nil
    }
    
    func changePassword(oldPassword: String, newPassword: String) async throws -> Bool {
        let request = ChangePasswordRequest(oldPassword: oldPassword, newPassword: newPassword)
        let jsonData = try JSONEncoder().encode(request)
        
        let response: MessageResponse = try await makeRequest(
            endpoint: APIEndpoints.changePassword,
            method: .POST,
            body: jsonData,
            requiresAuth: true
        )
        
        return response.success
    }
    
    func deleteAccount(password: String) async throws -> Bool {
        let request = DeleteAccountRequest(password: password)
        let jsonData = try JSONEncoder().encode(request)
        
        let response: MessageResponse = try await makeRequest(
            endpoint: APIEndpoints.deleteAccount,
            method: .POST,
            body: jsonData,
            requiresAuth: true
        )
        
        if response.success {
            // 清除本地 token
            UserDefaults.standard.removeObject(forKey: "authToken")
            self.authToken = nil
        }
        
        return response.success
    }
    
    // MARK: - 用戶資料同步
    func syncUserProfile() async throws -> User {
        let response: UserProfileResponse = try await makeRequest(endpoint: APIEndpoints.userProfile)
        
        guard response.success else {
            throw APIError.serverError(400)
        }
        
        return response.user.toUser()
    }
    
    func updateUserProfile(name: String?, email: String?) async throws -> Bool {
        let updateRequest = UpdateUserRequest(name: name, email: email)
        let jsonData = try JSONEncoder().encode(updateRequest)
        
        let response: MessageResponse = try await makeRequest(
            endpoint: APIEndpoints.updateProfile,
            method: .POST,
            body: jsonData,
            requiresAuth: true
        )
        
        return response.success
    }
    
    // MARK: - 檢查網路連接
    func checkNetworkConnection() async -> Bool {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(APIEndpoints.health)") else {
            return false
        }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - 輔助類型
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}



struct RegisterResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

struct VerificationCodeResponse: Codable {
    let success: Bool
    let message: String?
    let code: String? // 開發模式會直接返回
    let error: String?
}

struct VerifyCodeResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
    let error: String?
}

struct UserProfileResponse: Codable {
    let success: Bool
    let user: UserResponse
    let error: String?
}

struct MessageResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

struct EmptyResponse: Codable {}

struct UpdateUserRequest: Codable {
    let name: String?
    let email: String?
} 