//
//  ConversationListView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData
import UIKit

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Query(sort: \LineConversation.lastMessageTime, order: .reverse) private var lineConversations: [LineConversation]
    @State private var selectedFilter: ConversationFilter = .all
    @State private var searchText = ""
    
    // 整合所有對話
    var allConversations: [UnifiedConversation] {
        var unified: [UnifiedConversation] = []
        
        // 添加 Line 對話
        for conversation in lineConversations {
            unified.append(UnifiedConversation(
                id: conversation.id,
                title: conversation.customerName,
                lastMessage: conversation.lastMessage,
                lastMessageTime: conversation.lastMessageTime,
                messageCount: conversation.messageCount,
                platform: .line,
                status: conversation.status,
                isUnread: conversation.isUnread,
                customerName: conversation.customerName
            ))
        }
        
        return unified.sorted { $0.lastMessageTime > $1.lastMessageTime }
    }
    
    var filteredConversations: [UnifiedConversation] {
        var filtered = allConversations
        
        // 平台篩選
        if selectedFilter != .all {
            filtered = filtered.filter { $0.platform == selectedFilter.platform }
        }
        
        // 搜尋篩選
        if !searchText.isEmpty {
            filtered = filtered.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                conversation.lastMessage.localizedCaseInsensitiveContains(searchText) ||
                (conversation.customerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
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
                // 標題和搜尋區域
                VStack(spacing: 15) {
                    HStack {
                        Text("對話")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    // 搜尋欄
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("搜尋對話...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button("清除") {
                                searchText = ""
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 篩選器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ConversationFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
                
                // 對話列表
                if filteredConversations.isEmpty {
                    EmptyStateView()
                        .padding(.bottom, 80)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredConversations) { conversation in
                                UnifiedConversationRow(conversation: conversation)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationTitle("對話")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            cleanupSampleConversations()
        }
    }
    
    private func cleanupSampleConversations() {
        do {
            // 移除本機測試對話
            let testConversations = try modelContext.fetch(FetchDescriptor<Conversation>())
            for conversation in testConversations {
                modelContext.delete(conversation)
            }

            // 移除示例 Line 對話（僅移除明顯測試 ID）
            let sampleIds = ["line_001", "line_002", "line_003"]
            let lineList = try modelContext.fetch(FetchDescriptor<LineConversation>())
            for conversation in lineList {
                if sampleIds.contains(conversation.customerId) || conversation.customerId.hasPrefix("CUST") {
                    modelContext.delete(conversation)
                }
            }
            try modelContext.save()
        } catch {
            // 忽略清理失敗
        }
    }
    
}

// 統一對話模型
struct UnifiedConversation: Identifiable {
    let id: String
    let title: String
    let lastMessage: String
    let lastMessageTime: Date
    let messageCount: Int
    let platform: ConversationPlatform
    let status: ConversationStatus
    let isUnread: Bool
    let customerName: String?
}

enum ConversationPlatform: String, CaseIterable {
    case test = "test"
    case line = "line"
    case whatsapp = "whatsapp"
    case facebook = "facebook"
    case instagram = "instagram"
    
    var displayName: String {
        switch self {
        case .test:
            return "測試"
        case .line:
            return "Line"
        case .whatsapp:
            return "WhatsApp"
        case .facebook:
            return "Facebook"
        case .instagram:
            return "Instagram"
        }
    }
    
    var icon: String {
        switch self {
        case .test:
            return "message.circle.fill"
        case .line:
            return "message.circle.fill"
        case .whatsapp:
            return "message.circle.fill"
        case .facebook:
            return "person.2.circle.fill"
        case .instagram:
            return "camera.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .test:
            return .blue
        case .line:
            return .green
        case .whatsapp:
            return .green
        case .facebook:
            return .blue
        case .instagram:
            return .purple
        }
    }
}

enum ConversationFilter: CaseIterable {
    case all
    case line
    case whatsapp
    case facebook
    case instagram
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .line:
            return "Line"
        case .whatsapp:
            return "WhatsApp"
        case .facebook:
            return "Facebook"
        case .instagram:
            return "Instagram"
        }
    }
    
    var platform: ConversationPlatform? {
        switch self {
        case .all:
            return nil
        case .line:
            return .line
        case .whatsapp:
            return .whatsapp
        case .facebook:
            return .facebook
        case .instagram:
            return .instagram
        }
    }
}

struct UnifiedConversationRow: View {
    let conversation: UnifiedConversation
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 15) {
                // 平台圖示
                ZStack {
                    Circle()
                        .fill(conversation.platform.color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: conversation.platform.icon)
                        .font(.title2)
                        .foregroundColor(conversation.platform.color)
                    
                    // 未讀指示器
                    if conversation.isUnread {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .offset(x: 18, y: -18)
                    }
                }
                
                // 對話資訊
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .fontWeight(conversation.isUnread ? .bold : .regular)
                        
                        Spacer()
                        
                        // 狀態標籤
                        if conversation.status != .active {
                            StatusBadge(status: conversation.status)
                        }
                        
                        Text(conversation.lastMessageTime, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !conversation.lastMessage.isEmpty {
                        Text(conversation.lastMessage)
                            .font(.subheadline)
                            .foregroundColor(conversation.isUnread ? .primary : .secondary)
                            .fontWeight(conversation.isUnread ? .medium : .regular)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("\(conversation.messageCount) 則訊息")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 平台標籤
                        Text(conversation.platform.displayName)
                            .font(.caption2)
                            .foregroundColor(conversation.platform.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(conversation.platform.color.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                // 箭頭
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(conversation.isUnread ? Color.blue.opacity(0.05) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(conversation.isUnread ? Color.blue.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var destinationView: some View {
        switch conversation.platform {
        case .test:
            ChatView(conversationId: conversation.id)
        case .line:
            LineChatView(conversationId: conversation.id)
        case .whatsapp, .facebook, .instagram:
            // 暫時使用測試對話視圖
            ChatView(conversationId: conversation.id)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
                )
        }
    }
}



struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("沒有對話記錄")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("開始與客戶對話來查看記錄")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - StatusBadge 組件
struct StatusBadge: View {
    let status: ConversationStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .resolved:
            return .blue
        case .archived:
            return .gray
        }
    }
}

struct NewConversationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    
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
            
            VStack(spacing: 30) {
                // 標題
                VStack(spacing: 10) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("建立新對話")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("為您的客服對話建立一個新的標題")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 輸入區域
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("對話標題")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("輸入標題", text: $title)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 按鈕
                    VStack(spacing: 15) {
                        Button("建立對話") {
                            createConversation()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            Color(.systemGray3) :
                            Color.blue
                        )
                        .cornerRadius(12)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button("取消") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
        }
        .navigationTitle("新對話")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    private func createConversation() {
        let newConversation = Conversation(title: title.isEmpty ? "新對話" : title)
        modelContext.insert(newConversation)
        dismiss()
    }
}

#Preview {
    NavigationView {
        ConversationListView()
    }
    .modelContainer(for: Conversation.self, inMemory: true)
} 