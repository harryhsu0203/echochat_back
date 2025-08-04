//
//  LineMessage.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData

@Model
final class LineMessage {
    var id: UUID
    var customerId: String
    var customerName: String
    var messageContent: String
    var timestamp: Date
    var isFromCustomer: Bool
    var isAIResponse: Bool
    var isApproved: Bool
    var isRejected: Bool
    var aiResponse: String?
    var manualResponse: String?
    var status: MessageStatus
    var conversationId: String
    
    init(customerId: String, customerName: String, messageContent: String, isFromCustomer: Bool, conversationId: String) {
        self.id = UUID()
        self.customerId = customerId
        self.customerName = customerName
        self.messageContent = messageContent
        self.timestamp = Date()
        self.isFromCustomer = isFromCustomer
        self.isAIResponse = !isFromCustomer
        self.isApproved = false
        self.isRejected = false
        self.aiResponse = nil
        self.manualResponse = nil
        self.status = isFromCustomer ? .pending : .sent
        self.conversationId = conversationId
    }
}

@Model
final class LineConversation {
    var id: String
    var customerId: String
    var customerName: String
    var lastMessage: String
    var lastMessageTime: Date
    var messageCount: Int
    var status: ConversationStatus
    var isActive: Bool
    var isUnread: Bool
    
    init(customerId: String, customerName: String) {
        self.id = UUID().uuidString
        self.customerId = customerId
        self.customerName = customerName
        self.lastMessage = ""
        self.lastMessageTime = Date()
        self.messageCount = 0
        self.status = .active
        self.isActive = true
        self.isUnread = false
    }
}

enum MessageStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case sent = "sent"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending:
            return "待審核"
        case .approved:
            return "已核准"
        case .rejected:
            return "已拒絕"
        case .sent:
            return "已發送"
        case .failed:
            return "發送失敗"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .approved:
            return "green"
        case .rejected:
            return "red"
        case .sent:
            return "blue"
        case .failed:
            return "gray"
        }
    }
}

enum ConversationStatus: String, CaseIterable, Codable {
    case active = "active"
    case resolved = "resolved"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .active:
            return "進行中"
        case .resolved:
            return "已解決"
        case .archived:
            return "已封存"
        }
    }
} 