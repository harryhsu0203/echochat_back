//
//  echochat_appTests.swift
//  echochat appTests
//
//  Created by 徐明漢 on 2025/7/28.
//

import XCTest
import SwiftData
@testable import echochat_app

final class echochat_appTests: XCTestCase {
    
    func testChatMessageCreation() throws {
        let message = ChatMessage(content: "測試訊息", isFromUser: true)
        
        XCTAssertEqual(message.content, "測試訊息")
        XCTAssertTrue(message.isFromUser)
        XCTAssertFalse(message.isAIResponse)
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }
    
    func testConversationCreation() throws {
        let conversation = Conversation(title: "測試對話")
        
        XCTAssertEqual(conversation.title, "測試對話")
        XCTAssertNotNil(conversation.id)
        XCTAssertNotNil(conversation.lastMessageTime)
        XCTAssertEqual(conversation.messageCount, 0)
    }
    
    func testAIServiceInitialization() throws {
        let aiService = AIService()
        
        XCTAssertNotNil(aiService)
        XCTAssertFalse(aiService.isLoading)
    }
    
    func testUserDefaultsSettings() throws {
        let testAPIKey = "test-api-key"
        UserDefaults.standard.set(testAPIKey, forKey: "apiKey")
        
        let retrievedKey = UserDefaults.standard.string(forKey: "apiKey")
        XCTAssertEqual(retrievedKey, testAPIKey)
    }
}
