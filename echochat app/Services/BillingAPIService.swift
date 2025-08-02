//
//  BillingAPIService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftUI

// MARK: - 帳務 API 模型
struct BillingOverview: Codable {
    let currentPlan: String
    let nextBillingDate: String
    let totalUsage: UsageData
    let limits: UsageData
    let usage: UsagePercentage
}

struct UsageData: Codable {
    let conversations: Int
    let messages: Int
    let apiCalls: Int
}

struct UsagePercentage: Codable {
    let conversations: Double
    let messages: Double
    let apiCalls: Double
}

struct UsageRecord: Codable {
    let date: String
    let conversations: Int
    let messages: Int
    let apiCalls: Int
}

struct CustomerUsage: Codable, Identifiable {
    let id: String
    let name: String
    let conversations: Int
    let messages: Int
    let apiCalls: Int
    let lastActivity: String
}

struct BillingPlan: Codable, Identifiable {
    let id: String
    let name: String
    let price: Int
    let currency: String
    let period: String
    let features: [String]
    let limits: UsageData
}

// MARK: - 帳務 API 回應
struct BillingOverviewResponse: Codable {
    let success: Bool
    let overview: BillingOverview
    let error: String?
}

struct UsageResponse: Codable {
    let success: Bool
    let usage: [UsageRecord]
    let timeRange: String
    let error: String?
}

struct CustomersResponse: Codable {
    let success: Bool
    let customers: [CustomerUsage]
    let error: String?
}

struct PlansResponse: Codable {
    let success: Bool
    let plans: [BillingPlan]
    let error: String?
}

// MARK: - 帳務 API 服務
class BillingAPIService: ObservableObject {
    static let shared = BillingAPIService()
    
    private init() {}
    
    // 獲取帳務總覽
    func getBillingOverview() async throws -> BillingOverview {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)/billing/overview") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(BillingOverviewResponse.self, from: data)
                if apiResponse.success {
                    return apiResponse.overview
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
    
    // 獲取使用量統計
    func getUsageStatistics(timeRange: String) async throws -> [UsageRecord] {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)/billing/usage?timeRange=\(timeRange)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(UsageResponse.self, from: data)
                if apiResponse.success {
                    return apiResponse.usage
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
    
    // 獲取客戶使用量列表
    func getCustomerUsage(timeRange: String) async throws -> [CustomerUsage] {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)/billing/customers?timeRange=\(timeRange)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(CustomersResponse.self, from: data)
                if apiResponse.success {
                    return apiResponse.customers
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
    
    // 獲取方案列表
    func getBillingPlans() async throws -> [BillingPlan] {
        let currentConfig = ConfigurationManager.shared.currentConfig
        guard let url = URL(string: "\(currentConfig.baseURL)/billing/plans") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let apiResponse = try JSONDecoder().decode(PlansResponse.self, from: data)
                if apiResponse.success {
                    return apiResponse.plans
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