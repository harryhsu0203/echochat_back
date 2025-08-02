//
//  LineService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData
import CommonCrypto

class LineService: ObservableObject {
    @Published var isConnected = false
    @Published var lastMessageTime: Date?
    
    // LINE API 設定
    private var channelAccessToken: String {
        UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
    }
    
    private var channelSecret: String {
        UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
    }
    
    private let lineAPIBaseURL = "https://api.line.me/v2"
    
    // 實際發送訊息到 LINE
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
    
    // 實際檢查 LINE API 連線
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
    
    // 實際獲取客戶資料
    func getCustomerProfile(customerId: String) async throws -> CustomerProfile {
        guard !channelAccessToken.isEmpty else {
            throw LineError.invalidCredentials
        }
        
        let url = URL(string: "\(lineAPIBaseURL)/bot/profile/\(customerId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(channelAccessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw LineError.invalidCustomerId
            }
            
            if let profileData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return CustomerProfile(
                    id: profileData["userId"] as? String ?? customerId,
                    name: profileData["displayName"] as? String ?? "未知用戶",
                    pictureUrl: profileData["pictureUrl"] as? String,
                    statusMessage: profileData["statusMessage"] as? String ?? ""
                )
            } else {
                throw LineError.invalidCustomerId
            }
        } catch {
            throw LineError.networkError
        }
    }
    
    // 處理 Webhook 事件
    func handleWebhookEvent(_ eventData: Data, signature: String) throws -> [LineMessage] {
        // 驗證簽名
        guard verifySignature(eventData, signature: signature) else {
            throw LineError.invalidSignature
        }
        
        guard let events = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
              let eventsArray = events["events"] as? [[String: Any]] else {
            throw LineError.invalidWebhookData
        }
        
        var messages: [LineMessage] = []
        
        for event in eventsArray {
            if let eventType = event["type"] as? String,
               eventType == "message",
               let message = event["message"] as? [String: Any],
               let messageType = message["type"] as? String,
               messageType == "text",
               let text = message["text"] as? String,
               let source = event["source"] as? [String: Any],
               let userId = source["userId"] as? String {
                
                let lineMessage = LineMessage(
                    customerId: userId,
                    customerName: "客戶 \(userId.suffix(4))", // 可以後續更新為實際名稱
                    messageContent: text,
                    isFromCustomer: true,
                    conversationId: userId // 使用 userId 作為對話 ID
                )
                
                messages.append(lineMessage)
            }
        }
        
        return messages
    }
    
    // 驗證 Webhook 簽名
    private func verifySignature(_ data: Data, signature: String) -> Bool {
        guard !channelSecret.isEmpty else { return false }
        
        let key = channelSecret.data(using: .utf8)!
        let hmac = data.hmac(algorithm: .sha256, key: key)
        let expectedSignature = hmac.base64EncodedString()
        
        return signature == expectedSignature
    }
    
    // 模擬功能（保留用於測試）
    func simulateIncomingMessage(customerId: String, customerName: String, message: String, conversationId: String) -> LineMessage {
        let lineMessage = LineMessage(
            customerId: customerId,
            customerName: customerName,
            messageContent: message,
            isFromCustomer: true,
            conversationId: conversationId
        )
        
        lastMessageTime = Date()
        return lineMessage
    }
}

// MARK: - 支援類型

struct CustomerProfile {
    let id: String
    let name: String
    let pictureUrl: String?
    let statusMessage: String
}

enum LineError: Error, LocalizedError {
    case sendFailed
    case connectionFailed
    case invalidCustomerId
    case invalidCredentials
    case networkError
    case invalidSignature
    case invalidWebhookData
    
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .sendFailed:
            return "訊息發送失敗"
        case .connectionFailed:
            return "Line連線失敗"
        case .invalidCustomerId:
            return "無效的客戶ID"
        case .invalidCredentials:
            return "無效的認證資訊"
        case .networkError:
            return "網路連線錯誤"
        case .invalidSignature:
            return "Webhook簽名驗證失敗"
        case .invalidWebhookData:
            return "無效的Webhook資料"
        case .apiError(let message):
            return "API錯誤：\(message)"
        }
    }
}

// MARK: - HMAC 擴展
extension Data {
    func hmac(algorithm: HMACAlgorithm, key: Data) -> Data {
        let digestLen = algorithm.digestLength
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLen)
        defer { result.deallocate() }
        
        self.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(algorithm.algorithm, keyBytes.baseAddress, key.count, dataBytes.baseAddress, self.count, result)
            }
        }
        
        return Data(bytes: result, count: digestLen)
    }
}

enum HMACAlgorithm {
    case sha256
    
    var algorithm: CCHmacAlgorithm {
        switch self {
        case .sha256:
            return CCHmacAlgorithm(kCCHmacAlgSHA256)
        }
    }
    
    var digestLength: Int {
        switch self {
        case .sha256:
            return Int(CC_SHA256_DIGEST_LENGTH)
        }
    }
} 