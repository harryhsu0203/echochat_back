//
//  ChatView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData
import UIKit

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [ChatMessage]
    @StateObject private var aiService = AIService()
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingQuickReplies = false
    @State private var showingCustomerInfo = false
    @State private var selectedQuickReply = ""
    @State private var isTyping = false
    @State private var showingAIAssistant = false
    
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
            // 專業漸層背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 客戶資訊標題欄
                CustomerInfoHeader(
                    customerName: "測試客戶",
                    status: .active,
                    lastSeen: "2分鐘前",
                    onInfoTap: { showingCustomerInfo = true }
                )
                
                // 聊天訊息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 歡迎訊息
                            if messages.isEmpty {
                                WelcomeMessageView()
                            }
                            
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // AI 正在輸入指示器
                            if aiService.isLoading {
                                AIThinkingIndicator()
                            }
                            
                            // 用戶正在輸入指示器
                            if isTyping {
                                UserTypingIndicator()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 快速回覆區域
                if showingQuickReplies {
                    QuickRepliesView(
                        selectedReply: $selectedQuickReply,
                        onSend: { reply in
                            messageText = reply
                            sendMessage()
                            showingQuickReplies = false
                        }
                    )
                }
                
                // 輸入區域
                ChatInputArea(
                    messageText: $messageText,
                    isTyping: $isTyping,
                    isLoading: aiService.isLoading,
                    onSend: sendMessage,
                    onQuickReplies: { showingQuickReplies.toggle() },
                    onAIAssistant: { showingAIAssistant = true }
                )
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCustomerInfo) {
            CustomerInfoSheet()
        }
        .sheet(isPresented: $showingAIAssistant) {
            AIAssistantSheet(conversationHistory: messages)
        }
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

// MARK: - 客戶資訊標題欄
struct CustomerInfoHeader: View {
    let customerName: String
    let status: ConversationStatus
    let lastSeen: String
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 客戶頭像
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            // 客戶資訊
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(customerName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // 狀態指示器
                    Circle()
                        .fill(status == .active ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                
                Text("最後上線：\(lastSeen)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 操作按鈕
            HStack(spacing: 16) {
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Button(action: {}) {
                    Image(systemName: "phone")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                Button(action: {}) {
                    Image(systemName: "video")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
}

// MARK: - 歡迎訊息
struct WelcomeMessageView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.wave.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            Text("歡迎來到客服對話！")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("我是您的專屬客服助理，很高興為您服務。請告訴我您需要什麼幫助？")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - AI 思考指示器
struct AIThinkingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationOffset == CGFloat(index) ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            
            Text("AI 正在思考中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .onAppear {
            animationOffset = 1
        }
    }
}

// MARK: - 用戶輸入指示器
struct UserTypingIndicator: View {
    var body: some View {
        HStack {
            Text("客戶正在輸入...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - 快速回覆視圖
struct QuickRepliesView: View {
    @Binding var selectedReply: String
    let onSend: (String) -> Void
    
    private let quickReplies = [
        "您好！很高興為您服務",
        "請問您需要什麼幫助？",
        "我來為您查詢一下",
        "請稍等，我馬上處理",
        "感謝您的耐心等待",
        "還有其他問題嗎？",
        "祝您有美好的一天！"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(quickReplies, id: \.self) { reply in
                    Button(action: { onSend(reply) }) {
                        Text(reply)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
}

// MARK: - 聊天輸入區域
struct ChatInputArea: View {
    @Binding var messageText: String
    @Binding var isTyping: Bool
    let isLoading: Bool
    let onSend: () -> Void
    let onQuickReplies: () -> Void
    let onAIAssistant: () -> Void
    
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(.systemGray4))
            
            HStack(spacing: 12) {
                // 快速回覆按鈕
                Button(action: onQuickReplies) {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                // AI 助理按鈕
                Button(action: onAIAssistant) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
                
                // 輸入框
                TextField("輸入訊息...", text: $messageText, axis: .vertical)
                    .textFieldStyle(CustomTextFieldStyle())
                    .lineLimit(1...4)
                    .onChange(of: messageText) { _, _ in
                        isTyping = !messageText.isEmpty
                    }
                
                // 發送按鈕
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 
                            Color(.systemGray3) : 
                            Color.blue
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                keyboardHeight = 0
            }
        }
    }
}

// MARK: - 客戶資訊表單
struct CustomerInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 客戶基本資訊
                    CustomerInfoSection(
                        title: "基本資訊",
                        items: [
                            ("姓名", "測試客戶"),
                            ("電話", "+886 912-345-678"),
                            ("Email", "test@example.com"),
                            ("會員等級", "黃金會員")
                        ]
                    )
                    
                    // 對話統計
                    CustomerInfoSection(
                        title: "對話統計",
                        items: [
                            ("總對話數", "15"),
                            ("平均回應時間", "2.3分鐘"),
                            ("滿意度評分", "4.8/5.0"),
                            ("最後對話", "2分鐘前")
                        ]
                    )
                    
                    // 標籤
                    CustomerInfoSection(
                        title: "標籤",
                        items: [
                            ("興趣", "科技產品"),
                            ("偏好", "線上購物"),
                            ("關注", "新產品發布")
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("客戶資訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CustomerInfoSection: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(item.1)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - AI 助理表單
struct AIAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    let conversationHistory: [ChatMessage]
    @State private var selectedSuggestion = ""
    
    private let aiSuggestions = [
        "分析客戶情緒",
        "提供產品建議",
        "生成回覆草稿",
        "總結對話重點",
        "預測客戶需求"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // AI 建議
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI 智能建議")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(aiSuggestions, id: \.self) { suggestion in
                            Button(action: { selectedSuggestion = suggestion }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.title2)
                                        .foregroundColor(.yellow)
                                    
                                    Text(suggestion)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    selectedSuggestion == suggestion ?
                                    Color.blue.opacity(0.1) :
                                    Color(.systemGray6)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // 快速操作
                VStack(alignment: .leading, spacing: 16) {
                    Text("快速操作")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        QuickActionButton(
                            title: "轉接人工客服",
                            icon: "person.2.fill",
                            color: .orange
                        ) {
                            // 轉接人工客服邏輯
                        }
                        
                        QuickActionButton(
                            title: "標記為已解決",
                            icon: "checkmark.circle.fill",
                            color: .green
                        ) {
                            // 標記為已解決邏輯
                        }
                        
                        QuickActionButton(
                            title: "加入待辦事項",
                            icon: "list.bullet",
                            color: .blue
                        ) {
                            // 加入待辦事項邏輯
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI 助理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 快速操作按鈕
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 訊息氣泡
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .contextMenu {
                            Button("複製") {
                                UIPasteboard.general.string = message.content
                            }
                            Button("回覆") { }
                            Button("轉發") { }
                        }
                    
                    HStack(spacing: 4) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        // AI 頭像
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .contextMenu {
                                Button("複製") {
                                    UIPasteboard.general.string = message.content
                                }
                                Button("讚") { }
                                Button("踩") { }
                                Button("回覆") { }
                            }
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                }
                
                Spacer()
            }
        }
    }
}

// 自定義文字輸入框樣式

#Preview {
    ChatView(conversationId: "preview")
        .modelContainer(for: ChatMessage.self, inMemory: true)
} 