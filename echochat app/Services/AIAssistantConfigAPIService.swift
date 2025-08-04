//
//  AIAssistantConfigAPIService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import Network

// MARK: - AI 助理配置 API 服務
class AIAssistantConfigAPIService: ObservableObject {
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "AIConfigNetworkMonitor")
    
    // 配置同步狀態
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - 網路監控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                // 如果重新連線且之前是離線狀態，嘗試同步配置
                if path.status == .satisfied && wasOffline {
                    self?.syncConfigIfNeeded()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - 獲取 AI 助理配置
    func getAIAssistantConfig() async throws -> AIAssistantConfig {
        guard isOnline else {
            throw AIConfigError.offline
        }
        
        await MainActor.run {
            self.isLoading = true
            self.syncStatus = .syncing
        }
        
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.aiAssistantConfig)") else {
            await MainActor.run {
                self.syncStatus = .error("無效的 URL")
                self.syncError = "無效的 URL"
            }
            throw AIConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.syncStatus = .error("網路錯誤")
                    self.syncError = "網路錯誤"
                }
                throw AIConfigError.networkError
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let configResponse = try JSONDecoder().decode(AIAssistantConfigResponse.self, from: data)
                    
                    if configResponse.success, let config = configResponse.data {
                        await MainActor.run {
                            self.lastSyncTime = Date()
                            self.syncStatus = .success
                            self.syncError = nil
                        }
                        return config
                    } else {
                        let errorMessage = configResponse.error ?? "未知錯誤"
                        await MainActor.run {
                            self.syncStatus = .error(errorMessage)
                            self.syncError = errorMessage
                        }
                        throw AIConfigError.serverError(errorMessage)
                    }
                } catch {
                    await MainActor.run {
                        self.syncStatus = .error("資料解析錯誤")
                        self.syncError = "資料解析錯誤"
                    }
                    throw AIConfigError.decodingError
                }
                
            case 401:
                await MainActor.run {
                    self.syncStatus = .error("未授權，請重新登入")
                    self.syncError = "未授權，請重新登入"
                }
                throw AIConfigError.unauthorized
            case 404:
                await MainActor.run {
                    self.syncStatus = .error("配置不存在")
                    self.syncError = "配置不存在"
                }
                throw AIConfigError.notFound
            case 500...599:
                await MainActor.run {
                    self.syncStatus = .error("伺服器錯誤")
                    self.syncError = "伺服器錯誤"
                }
                throw AIConfigError.serverError("伺服器錯誤")
            default:
                await MainActor.run {
                    self.syncStatus = .error("網路連線錯誤")
                    self.syncError = "網路連線錯誤"
                }
                throw AIConfigError.networkError
            }
        } catch {
            if error is AIConfigError {
                throw error
            } else {
                await MainActor.run {
                    self.syncStatus = .error(error.localizedDescription)
                    self.syncError = error.localizedDescription
                }
                throw AIConfigError.networkError
            }
        }
    }
    
    // MARK: - 更新 AI 助理配置
    func updateAIAssistantConfig(_ config: AIAssistantConfig) async throws {
        guard isOnline else {
            throw AIConfigError.offline
        }
        
        await MainActor.run {
            self.isLoading = true
            self.syncStatus = .syncing
        }
        
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.aiAssistantConfig)") else {
            await MainActor.run {
                self.syncStatus = .error("無效的 URL")
                self.syncError = "無效的 URL"
            }
            throw AIConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 準備請求資料
        let requestBody = AIAssistantConfigRequest(config: config)
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            await MainActor.run {
                self.syncStatus = .error("資料編碼錯誤")
                self.syncError = "資料編碼錯誤"
            }
            throw AIConfigError.invalidData
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.syncStatus = .error("網路錯誤")
                    self.syncError = "網路錯誤"
                }
                throw AIConfigError.networkError
            }
            
            switch httpResponse.statusCode {
            case 200, 201:
                do {
                    let configResponse = try JSONDecoder().decode(AIAssistantConfigResponse.self, from: data)
                    
                    if configResponse.success {
                        await MainActor.run {
                            self.lastSyncTime = Date()
                            self.syncStatus = .success
                            self.syncError = nil
                        }
                    } else {
                        let errorMessage = configResponse.error ?? "更新失敗"
                        await MainActor.run {
                            self.syncStatus = .error(errorMessage)
                            self.syncError = errorMessage
                        }
                        throw AIConfigError.serverError(errorMessage)
                    }
                } catch {
                    await MainActor.run {
                        self.syncStatus = .error("資料解析錯誤")
                        self.syncError = "資料解析錯誤"
                    }
                    throw AIConfigError.decodingError
                }
                
            case 401:
                await MainActor.run {
                    self.syncStatus = .error("未授權，請重新登入")
                    self.syncError = "未授權，請重新登入"
                }
                throw AIConfigError.unauthorized
            case 400:
                await MainActor.run {
                    self.syncStatus = .error("無效的配置資料")
                    self.syncError = "無效的配置資料"
                }
                throw AIConfigError.invalidData
            case 500...599:
                await MainActor.run {
                    self.syncStatus = .error("伺服器錯誤")
                    self.syncError = "伺服器錯誤"
                }
                throw AIConfigError.serverError("伺服器錯誤")
            default:
                await MainActor.run {
                    self.syncStatus = .error("網路連線錯誤")
                    self.syncError = "網路連線錯誤"
                }
                throw AIConfigError.networkError
            }
        } catch {
            if error is AIConfigError {
                throw error
            } else {
                await MainActor.run {
                    self.syncStatus = .error(error.localizedDescription)
                    self.syncError = error.localizedDescription
                }
                throw AIConfigError.networkError
            }
        }
    }
    
    // MARK: - 重設 AI 助理配置
    func resetAIAssistantConfig() async throws {
        guard isOnline else {
            throw AIConfigError.offline
        }
        
        await MainActor.run {
            self.isLoading = true
            self.syncStatus = .syncing
        }
        
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.aiAssistantConfigReset)") else {
            await MainActor.run {
                self.syncStatus = .error("無效的 URL")
                self.syncError = "無效的 URL"
            }
            throw AIConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
        
        // 添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.syncStatus = .error("網路錯誤")
                    self.syncError = "網路錯誤"
                }
                throw AIConfigError.networkError
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let configResponse = try JSONDecoder().decode(AIAssistantConfigResponse.self, from: data)
                    
                    if configResponse.success {
                        await MainActor.run {
                            self.lastSyncTime = Date()
                            self.syncStatus = .success
                            self.syncError = nil
                        }
                    } else {
                        let errorMessage = configResponse.error ?? "重設失敗"
                        await MainActor.run {
                            self.syncStatus = .error(errorMessage)
                            self.syncError = errorMessage
                        }
                        throw AIConfigError.serverError(errorMessage)
                    }
                } catch {
                    await MainActor.run {
                        self.syncStatus = .error("資料解析錯誤")
                        self.syncError = "資料解析錯誤"
                    }
                    throw AIConfigError.decodingError
                }
                
            case 401:
                await MainActor.run {
                    self.syncStatus = .error("未授權，請重新登入")
                    self.syncError = "未授權，請重新登入"
                }
                throw AIConfigError.unauthorized
            case 500...599:
                await MainActor.run {
                    self.syncStatus = .error("伺服器錯誤")
                    self.syncError = "伺服器錯誤"
                }
                throw AIConfigError.serverError("伺服器錯誤")
            default:
                await MainActor.run {
                    self.syncStatus = .error("網路連線錯誤")
                    self.syncError = "網路連線錯誤"
                }
                throw AIConfigError.networkError
            }
        } catch {
            if error is AIConfigError {
                throw error
            } else {
                await MainActor.run {
                    self.syncStatus = .error(error.localizedDescription)
                    self.syncError = error.localizedDescription
                }
                throw AIConfigError.networkError
            }
        }
    }
    
    // MARK: - 獲取 AI 模型列表
    func getAIModels() async throws -> [AIModel] {
        guard isOnline else {
            throw AIConfigError.offline
        }
        
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.aiModels)") else {
            throw AIConfigError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
        
        // 移除認證要求，讓模型列表可以在未登入狀態下載入
        // 只有在用戶已登入時才添加認證標頭
        if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIConfigError.networkError
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let modelsResponse = try JSONDecoder().decode(AIModelsResponse.self, from: data)
                    
                    if modelsResponse.success, let models = modelsResponse.data {
                        return models
                    } else {
                        throw AIConfigError.serverError(modelsResponse.error ?? "獲取模型列表失敗")
                    }
                } catch {
                    throw AIConfigError.decodingError
                }
                
            case 401:
                // 如果認證失敗，嘗試不使用認證重新請求
                if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
                    // 清除無效的token
                    UserDefaults.standard.removeObject(forKey: "userToken")
                    
                    // 重新嘗試請求（不帶認證）
                    var retryRequest = URLRequest(url: url)
                    retryRequest.httpMethod = "GET"
                    retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                    retryRequest.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
                    
                    let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                    
                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                          retryHttpResponse.statusCode == 200 else {
                        throw AIConfigError.networkError
                    }
                    
                    do {
                        let retryModelsResponse = try JSONDecoder().decode(AIModelsResponse.self, from: retryData)
                        
                        if retryModelsResponse.success, let models = retryModelsResponse.data {
                            return models
                        } else {
                            throw AIConfigError.serverError(retryModelsResponse.error ?? "獲取模型列表失敗")
                        }
                    } catch {
                        throw AIConfigError.decodingError
                    }
                } else {
                    throw AIConfigError.unauthorized
                }
                
            case 500...599:
                throw AIConfigError.serverError("伺服器錯誤")
            default:
                throw AIConfigError.networkError
            }
        } catch {
            if error is AIConfigError {
                throw error
            } else {
                throw AIConfigError.networkError
            }
        }
    }
    
    // MARK: - 同步配置（如果需要）
    func syncConfigIfNeeded() {
        Task {
            await syncConfigIfNeededAsync()
        }
    }
    
    private func syncConfigIfNeededAsync() async {
        // 檢查是否需要同步
        let lastSync = UserDefaults.standard.object(forKey: "aiConfigLastSynced") as? Date
        let shouldSync = lastSync == nil || Date().timeIntervalSince(lastSync!) > 300 // 5分鐘
        
        if shouldSync && isOnline {
            await MainActor.run {
                self.syncStatus = .syncing
            }
            
            do {
                let remoteConfig = try await getAIAssistantConfig()
                var localConfig = AIAssistantConfig(from: UserDefaults.standard)
                
                // 合併配置
                localConfig.merge(with: remoteConfig)
                localConfig.saveToUserDefaults()
                
                await MainActor.run {
                    self.syncStatus = .success
                    self.lastSyncTime = Date()
                    self.syncError = nil
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .error(error.localizedDescription)
                    self.syncError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - 強制同步配置
    func forceSyncConfig() async {
        await MainActor.run {
            self.syncStatus = .syncing
        }
        
        do {
            let remoteConfig = try await getAIAssistantConfig()
            var localConfig = AIAssistantConfig(from: UserDefaults.standard)
            
            // 合併配置
            localConfig.merge(with: remoteConfig)
            localConfig.saveToUserDefaults()
            
            await MainActor.run {
                self.syncStatus = .success
                self.lastSyncTime = Date()
                self.syncError = nil
            }
        } catch {
            await MainActor.run {
                self.syncStatus = .error(error.localizedDescription)
                self.syncError = error.localizedDescription
            }
        }
    }
    
    // MARK: - 清除錯誤狀態
    func clearError() {
        Task { @MainActor in
            self.syncError = nil
            if case .error = self.syncStatus {
                self.syncStatus = .idle
            }
        }
    }
}

// MARK: - AI 配置錯誤
enum AIConfigError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError(String)
    case unauthorized
    case notFound
    case invalidData
    case offline
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .networkError:
            return "網路連線錯誤"
        case .serverError(let message):
            return "伺服器錯誤: \(message)"
        case .unauthorized:
            return "未授權，請重新登入"
        case .notFound:
            return "配置不存在"
        case .invalidData:
            return "無效的配置資料"
        case .offline:
            return "離線模式，無法同步配置"
        case .decodingError:
            return "資料解析錯誤"
        }
    }
} 