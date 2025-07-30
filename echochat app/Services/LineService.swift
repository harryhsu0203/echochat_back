//
//  LineService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData

class LineService: ObservableObject {
    @Published var isConnected = false
    @Published var lastMessageTime: Date?
    
    // 模擬Line Webhook接收訊息
    func simulateIncomingMessage(customerId: String, customerName: String, message: String, conversationId: String) -> LineMessage {
        let lineMessage = LineMessage(
            customerId: customerId,
            customerName: customerName,
            messageContent: message,
            isFromCustomer: true,
            conversationId: conversationId
        )
        
        // 更新最後訊息時間
        lastMessageTime = Date()
        
        return lineMessage
    }
    
    // 發送訊息到Line
    func sendMessageToLine(message: String, customerId: String) async throws -> Bool {
        // 這裡應該整合實際的Line Messaging API
        // 目前模擬發送成功
        
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 模擬90%成功率
        let success = Double.random(in: 0...1) < 0.9
        
        if !success {
            throw LineError.sendFailed
        }
        
        return true
    }
    
    // 檢查Line連線狀態
    func checkConnection() async -> Bool {
        // 模擬檢查Line API連線
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 模擬連線狀態
        let connected = Double.random(in: 0...1) < 0.95
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.isConnected = connected
        }
        
        return connected
    }
    
    // 獲取客戶資訊
    func getCustomerProfile(customerId: String) async throws -> CustomerProfile {
        // 模擬從Line API獲取客戶資料
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        
        return CustomerProfile(
            id: customerId,
            name: "客戶 \(customerId.suffix(4))",
            pictureUrl: nil,
            statusMessage: "使用中"
        )
    }
}

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
    
    var errorDescription: String? {
        switch self {
        case .sendFailed:
            return "訊息發送失敗"
        case .connectionFailed:
            return "Line連線失敗"
        case .invalidCustomerId:
            return "無效的客戶ID"
        }
    }
} 