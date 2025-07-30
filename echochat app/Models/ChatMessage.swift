//
//  ChatMessage.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var timestamp: Date
    var isFromUser: Bool
    var isAIResponse: Bool
    var conversationId: String
    
    init(content: String, isFromUser: Bool, conversationId: String = UUID().uuidString) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFromUser = isFromUser
        self.isAIResponse = !isFromUser
        self.conversationId = conversationId
    }
}

@Model
final class Conversation {
    var id: String
    var title: String
    var lastMessage: String
    var lastMessageTime: Date
    var messageCount: Int
    
    init(title: String = "新對話") {
        self.id = UUID().uuidString
        self.title = title
        self.lastMessage = ""
        self.lastMessageTime = Date()
        self.messageCount = 0
    }
} 