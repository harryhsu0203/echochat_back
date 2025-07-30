//
//  ChatView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [ChatMessage]
    @StateObject private var aiService = AIService()
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let conversationId: String
    
    init(conversationId: String) {
        self.conversationId = conversationId
        let predicate = #Predicate<ChatMessage> { message in
            message.conversationId == conversationId
        }
        _messages = Query(filter: predicate, sort: \ChatMessage.timestamp)
    }
    
    var body: some View {
        ZStack {
            // 柔和漸層背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // 聊天訊息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if aiService.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.secondary)
                                    Text("AI正在思考中...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 輸入區域
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(.systemGray4))
                    
                    HStack(spacing: 12) {
                        TextField("輸入訊息...", text: $messageText, axis: .vertical)
                            .textFieldStyle(CustomTextFieldStyle())
                            .lineLimit(1...4)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                    Color(.systemGray3) : 
                                    Color.blue
                                )
                                .clipShape(Circle())
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("客服聊天")
        .navigationBarTitleDisplayMode(.inline)
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // 保存用戶訊息
        let userMessage = ChatMessage(content: trimmedMessage, isFromUser: true, conversationId: conversationId)
        modelContext.insert(userMessage)
        
        // 清空輸入框
        messageText = ""
        
        // 獲取AI回應
        Task {
            do {
                let aiResponse = try await aiService.generateResponse(for: trimmedMessage, conversationHistory: messages)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(content: aiResponse, isFromUser: false, conversationId: conversationId)
                    modelContext.insert(aiMessage)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatView(conversationId: "preview")
    }
    .modelContainer(for: ChatMessage.self, inMemory: true)
} 