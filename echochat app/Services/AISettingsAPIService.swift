//
//  AISettingsAPIService.swift
//  echochat app
//
//  Created by AI Assistant on 2026/1/22.
//

import Foundation

final class AISettingsAPIService: ObservableObject {
    @Published var lastError: String?

    func fetchSettings() async throws -> AISettings {
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.aiSettings)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
        if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(AISettingsResponse.self, from: data)
            throw NSError(domain: "AISettings", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorResponse?.error ?? "伺服器錯誤"
            ])
        }
        let decoded = try JSONDecoder().decode(AISettingsResponse.self, from: data)
        guard decoded.success, let settings = decoded.settings else {
            throw NSError(domain: "AISettings", code: -1, userInfo: [
                NSLocalizedDescriptionKey: decoded.error ?? "讀取設定失敗"
            ])
        }
        return settings
    }

    func updateSettings(_ settings: AISettings) async throws {
        let baseURL = ConfigurationManager.shared.currentConfig.baseURL
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.aiSettings)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = ConfigurationManager.shared.currentConfig.timeout
        if let token = UserDefaults.standard.string(forKey: "userToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let payload = ["settings": settings]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(AISettingsResponse.self, from: data)
            throw NSError(domain: "AISettings", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorResponse?.error ?? "更新設定失敗"
            ])
        }
    }
}


