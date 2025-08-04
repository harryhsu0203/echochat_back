//
//  ChannelAPIService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - 頻道 API 模型
struct ChannelAPIRequest: Codable {
    let name: String
    let platform: String
    let apiKey: String
    let channelSecret: String
    let webhookUrl: String?
    let isActive: Bool
    let userId: String
}

struct ChannelAPIResponse: Codable {
    let id: String
    let name: String
    let platform: String
    let apiKey: String
    let channelSecret: String
    let webhookUrl: String?
    let isActive: Bool
    let userId: String
    let createdAt: String
    let updatedAt: String
}

struct ChannelListResponse: Codable {
    let channels: [ChannelAPIResponse]
}

// MARK: - 頻道 API 服務
class ChannelAPIService: ObservableObject {
    static let shared = ChannelAPIService()
    
    private init() {}
    
    // 建立新頻道
    func createChannel(_ channel: ChannelAPIRequest) async throws -> ChannelAPIResponse {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(APIEndpoints.createChannel)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證標頭（如果需要）
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(channel)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(APIResponse<ChannelAPIResponse>.self, from: data)
                if apiResponse.success, let channelData = apiResponse.data {
                    return channelData
                } else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // 更新頻道
    func updateChannel(id: String, _ channel: ChannelAPIRequest) async throws -> ChannelAPIResponse {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(APIEndpoints.updateChannel)/\(id)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(channel)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(APIResponse<ChannelAPIResponse>.self, from: data)
                if apiResponse.success, let channelData = apiResponse.data {
                    return channelData
                } else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // 獲取用戶的所有頻道
    func getUserChannels() async throws -> [ChannelAPIResponse] {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(APIEndpoints.getUserChannels)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(APIResponse<ChannelListResponse>.self, from: data)
                if apiResponse.success, let listData = apiResponse.data {
                    return listData.channels
                } else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // 刪除頻道
    func deleteChannel(id: String) async throws -> Bool {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(APIEndpoints.deleteChannel)/\(id)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                return true
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // 測試頻道連線
    func testChannelConnection(platform: String, apiKey: String, channelSecret: String) async throws -> Bool {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)\(APIEndpoints.testChannelConnection)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let testRequest = [
            "platform": platform,
            "apiKey": apiKey,
            "channelSecret": channelSecret
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(APIResponse<[String: Bool]>.self, from: data)
                if apiResponse.success, let result = apiResponse.data, let isConnected = result["connected"] {
                    return isConnected
                } else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
} 