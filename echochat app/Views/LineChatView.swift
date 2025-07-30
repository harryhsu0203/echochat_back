//
//  LineChatView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct LineChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [LineMessage]
    @StateObject private var aiService = AIService()
    @StateObject private var lineService = LineService()
    @State private var showingResponseSheet = false
    @State private var selectedMessage: LineMessage?
    @State private var manualResponse = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var chatInput = ""
    @State private var isHandlingConversation = false
    
    let conversationId: String
    
    init(conversationId: String) {
        self.conversationId = conversationId
        let predicate = #Predicate<LineMessage> { message in
            message.conversationId == conversationId
        }
        _messages = Query(filter: predicate, sort: \LineMessage.timestamp)
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
            
            VStack(spacing: 0) {
                // 訊息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                LineMessageBubble(
                                    message: message,
                                    onApprove: { approveMessage(message) },
                                    onReject: { rejectMessage(message) },
                                    onEdit: { showResponseSheet(for: message) }
                                )
                                .id(message.id)
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
                
                // 即時聊天輸入區域
                if isHandlingConversation {
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color(.systemGray4))
                        
                        HStack(spacing: 12) {
                            TextField("輸入訊息...", text: $chatInput)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            Button(action: sendDirectMessage) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                        Color(.systemGray3) : 
                                        Color.blue
                                    )
                                    .clipShape(Circle())
                            }
                            .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding()
                    }
                    .background(Color(.systemBackground))
                }
                
                // 快速回應按鈕（僅在未接管時顯示）
                if !isHandlingConversation && !messages.filter({ $0.status == .pending }).isEmpty {
                    QuickResponseView(
                        onAutoResponse: generateAutoResponse,
                        onManualResponse: { showResponseSheet(for: nil) }
                    )
                }
            }
        }
        .navigationTitle("Line對話管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("模擬新訊息") {
                    simulateNewMessage()
                }
                .foregroundColor(.blue)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isHandlingConversation ? "結束接管" : "接管對話") {
                    toggleHandling()
                }
                .foregroundColor(isHandlingConversation ? .red : .green)
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingResponseSheet) {
            ResponseSheetView(
                message: selectedMessage,
                response: $manualResponse,
                onSend: sendManualResponse
            )
        }
        .alert("錯誤", isPresented: $showingError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            markConversationAsRead()
        }
    }
    
    private func toggleHandling() {
        isHandlingConversation.toggle()
        if !isHandlingConversation {
            chatInput = ""
        }
    }
    
    private func sendDirectMessage() {
        guard !chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageContent = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 建立新的回應訊息
        let responseMessage = LineMessage(
            customerId: messages.first?.customerId ?? "",
            customerName: messages.first?.customerName ?? "",
            messageContent: messageContent,
            isFromCustomer: false,
            conversationId: conversationId
        )
        responseMessage.manualResponse = messageContent
        responseMessage.status = .approved
        responseMessage.isApproved = true
        
        modelContext.insert(responseMessage)
        
        // 發送到Line
        Task {
            await sendToLine(messageContent, for: responseMessage)
        }
        
        chatInput = ""
    }
    
    private func approveMessage(_ message: LineMessage) {
        message.status = .approved
        message.isApproved = true
        
        // 自動發送AI回應
        Task {
            await sendAIResponse(for: message)
        }
    }
    
    private func rejectMessage(_ message: LineMessage) {
        message.status = .rejected
        message.isRejected = true
    }
    
    private func showResponseSheet(for message: LineMessage?) {
        selectedMessage = message
        manualResponse = ""
        showingResponseSheet = true
    }
    
    private func generateAutoResponse() {
        guard let pendingMessage = messages.first(where: { $0.status == .pending }) else { return }
        
        Task {
            do {
                let aiResponse = try await aiService.generateResponse(
                    for: pendingMessage.messageContent,
                    conversationHistory: messages.map { ChatMessage(content: $0.messageContent, isFromUser: $0.isFromCustomer, conversationId: $0.conversationId) }
                )
                
                await MainActor.run {
                    pendingMessage.aiResponse = aiResponse
                    pendingMessage.status = .approved
                    pendingMessage.isApproved = true
                    
                    // 發送到Line
                    Task {
                        await sendToLine(aiResponse, for: pendingMessage)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func sendManualResponse() {
        guard !manualResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if let message = selectedMessage {
            message.manualResponse = manualResponse
            message.status = .approved
            message.isApproved = true
            
            Task {
                await sendToLine(manualResponse, for: message)
            }
        } else {
            // 建立新的回應訊息
            let responseMessage = LineMessage(
                customerId: messages.first?.customerId ?? "",
                customerName: messages.first?.customerName ?? "",
                messageContent: manualResponse,
                isFromCustomer: false,
                conversationId: conversationId
            )
            responseMessage.manualResponse = manualResponse
            responseMessage.status = .approved
            responseMessage.isApproved = true
            
            modelContext.insert(responseMessage)
            
            Task {
                await sendToLine(manualResponse, for: responseMessage)
            }
        }
        
        showingResponseSheet = false
        manualResponse = ""
    }
    
    private func sendAIResponse(for message: LineMessage) async {
        guard let aiResponse = message.aiResponse else { return }
        
        await sendToLine(aiResponse, for: message)
    }
    
    private func sendToLine(_ response: String, for message: LineMessage) async {
        do {
            let success = try await lineService.sendMessageToLine(
                message: response,
                customerId: message.customerId
            )
            
            await MainActor.run {
                if success {
                    message.status = .sent
                } else {
                    message.status = .failed
                }
            }
        } catch {
            await MainActor.run {
                message.status = .failed
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func simulateNewMessage() {
        let customerId = "CUST\(Int.random(in: 1000...9999))"
        let customerName = "客戶 \(customerId.suffix(4))"
        let messages = [
            "請問你們的營業時間是？",
            "我想詢問產品價格",
            "有現貨嗎？",
            "可以貨到付款嗎？",
            "謝謝您的協助"
        ]
        
        let randomMessage = messages.randomElement() ?? "您好"
        
        let newMessage = lineService.simulateIncomingMessage(
            customerId: customerId,
            customerName: customerName,
            message: randomMessage,
            conversationId: conversationId
        )
        
        modelContext.insert(newMessage)
    }
    
    private func markConversationAsRead() {
        // 查找並標記對話為已讀
        let conversations = try? modelContext.fetch(FetchDescriptor<LineConversation>())
        if let conversation = conversations?.first(where: { $0.id == conversationId }) {
            conversation.isUnread = false
        }
    }
}

struct LineMessageBubble: View {
    let message: LineMessage
    let onApprove: () -> Void
    let onReject: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 訊息內容
            HStack {
                if message.isFromCustomer {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(message.customerName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(message.messageContent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    Spacer()
                } else {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Text("客服")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "message.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Text(message.messageContent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            
            // 狀態和操作按鈕
            if message.isFromCustomer {
                HStack {
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if message.status == .pending {
                        HStack(spacing: 8) {
                            Button("核准") {
                                onApprove()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Button("拒絕") {
                                onReject()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Button("編輯") {
                                onEdit()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    } else {
                        MessageStatusBadge(status: message.status)
                    }
                }
            }
        }
    }
}

struct MessageStatusBadge: View {
    let status: MessageStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(statusColor.opacity(0.4), lineWidth: 1)
            )
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .approved:
            return .green
        case .rejected:
            return .red
        case .sent:
            return .blue
        case .failed:
            return .gray
        }
    }
}

struct QuickResponseView: View {
    let onAutoResponse: () -> Void
    let onManualResponse: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(.systemGray4))
            
            HStack(spacing: 15) {
                Button(action: onAutoResponse) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("AI自動回應")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: onManualResponse) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("手動回應")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct ResponseSheetView: View {
    let message: LineMessage?
    @Binding var response: String
    let onSend: () -> Void
    @Environment(\.dismiss) private var dismiss
    
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
            
            VStack(spacing: 20) {
                if let message = message {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("客戶訊息:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(message.messageContent)
                            .padding()
                            .background(Color(.systemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("回應內容:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $response)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("編輯回應")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("發送") {
                    onSend()
                }
                .foregroundColor(.blue)
                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

#Preview {
    NavigationView {
        LineChatView(conversationId: "preview")
    }
    .modelContainer(for: LineMessage.self, inMemory: true)
} 