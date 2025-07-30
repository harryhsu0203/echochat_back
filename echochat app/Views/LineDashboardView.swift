//
//  LineDashboardView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct LineDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @Query(sort: \LineConversation.lastMessageTime, order: .reverse) private var conversations: [LineConversation]
    @StateObject private var lineService = LineService()
    @State private var showingNewMessage = false
    @State private var selectedFilter: ConversationStatus = .active
    @State private var showingProfile = false
    @State private var showingNotifications = false
    @State private var unreadCount = 0
    @State private var showingSettings = false
    @State private var searchText = ""
    
    // 新增進階篩選狀態
    @State private var showingAdvancedFilter = false
    @State private var selectedTimeRange: TimeRange = .all
    @State private var selectedCustomerType: CustomerType = .all
    @State private var showingQuickActions = false
    @State private var selectedConversations: Set<String> = []
    @State private var showingQuickReply = false
    @State private var showingAnalytics = false
    @State private var showingThemeSettings = false
    
    var filteredConversations: [LineConversation] {
        var filtered = conversations
        
        // 基本狀態篩選
        filtered = filtered.filter { $0.status == selectedFilter }
        
        // 搜尋篩選
        if !searchText.isEmpty {
            filtered = filtered.filter { conversation in
                conversation.customerName.localizedCaseInsensitiveContains(searchText) ||
                conversation.lastMessage.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 時間範圍篩選
        filtered = filtered.filter { conversation in
            selectedTimeRange.filter(conversation.lastMessageTime)
        }
        
        // 客戶類型篩選
        if selectedCustomerType != .all {
            filtered = filtered.filter { conversation in
                selectedCustomerType.matches(conversation.customerName)
            }
        }
        
        return filtered
    }
    
    var pendingMessagesCount: Int {
        conversations.filter { $0.status == .active }.count
    }
    
    var body: some View {
        ZStack {
            // 柔和漸層背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.primaryBackground,
                    Color.cardBackground
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Line風格的頂部區域
                LineStyleHeaderView(
                    user: authService.currentUser,
                    searchText: $searchText,
                    showingNotifications: $showingNotifications,
                    showingSettings: $showingSettings,
                    unreadCount: unreadCount
                )
                
                // 主要內容區域
                ScrollView {
                    VStack(spacing: 20) {
                        // 連線狀態和統計
                        VStack(spacing: 16) {
                            // 連線狀態卡片
                            ConnectionStatusCard(lineService: lineService)
                            
                            // 統計卡片
                            DashboardStatsView(
                                totalConversations: conversations.count,
                                activeConversations: conversations.filter { $0.status == .active }.count,
                                pendingMessages: pendingMessagesCount
                            )
                        }
                        
                        // 快速操作按鈕
                        QuickActionsSection(
                            showingQuickActions: $showingQuickActions,
                            showingQuickReply: $showingQuickReply,
                            showingAnalytics: $showingAnalytics,
                            showingThemeSettings: $showingThemeSettings
                        )
                        
                        // 進階篩選器
                        AdvancedFilterSection(
                            selectedFilter: $selectedFilter,
                            selectedTimeRange: $selectedTimeRange,
                            selectedCustomerType: $selectedCustomerType,
                            showingAdvancedFilter: $showingAdvancedFilter
                        )
                        
                        // 對話列表
                        ConversationListSection(
                            conversations: filteredConversations,
                            showingNewMessage: $showingNewMessage,
                            selectedConversations: $selectedConversations
                        )
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewMessage) {
            NewMessageView(lineService: lineService)
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SystemSettingsView()
            }
        }
        
        .sheet(isPresented: $showingQuickReply) {
            QuickReplyView()
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(conversations: conversations)
        }
        .sheet(isPresented: $showingThemeSettings) {
            ThemeSettingsView()
        }
        .onAppear {
            createSampleConversations()
            updateUnreadCount()
        }
        .onChange(of: conversations.count) { _, _ in
            updateUnreadCount()
        }
    }
    
    private func createSampleConversations() {
        // 檢查是否已經有範例對話，如果沒有則創建
        if conversations.isEmpty {
            let sampleConversations: [(String, String, String, ConversationStatus, Bool)] = [
                ("customer_001", "張小明", "您好，我想詢問關於產品退貨的事項", .active, false),
                ("customer_002", "李小華", "請問你們的客服時間是幾點到幾點？", .active, true),
                ("customer_003", "王小美", "我想申請會員升級，需要什麼條件？", .resolved, false),
                ("customer_004", "陳小強", "昨天購買的商品什麼時候會到貨？", .active, true),
                ("customer_005", "林小芳", "謝謝你們的服務，問題已經解決了", .resolved, false)
            ]
            
            for (customerId, customerName, lastMessage, status, isUnread) in sampleConversations {
                let conversation = LineConversation(customerId: customerId, customerName: customerName)
                conversation.lastMessage = lastMessage
                conversation.lastMessageTime = Date().addingTimeInterval(-Double.random(in: 0...86400)) // 隨機時間
                conversation.messageCount = Int.random(in: 1...10)
                conversation.status = status
                conversation.isUnread = isUnread
                modelContext.insert(conversation)
            }
        }
    }
    
    private func updateUnreadCount() {
        unreadCount = conversations.filter { $0.isUnread }.count
    }
}

// 連線狀態卡片
struct ConnectionStatusCard: View {
    @ObservedObject var lineService: LineService
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(lineService.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(lineService.isConnected ? "Line已連線" : "Line未連線")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button("測試連線") {
                // 測試連線邏輯
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }
}

// 快速操作區域
struct QuickActionsSection: View {
    @Binding var showingQuickActions: Bool
    @Binding var showingQuickReply: Bool
    @Binding var showingAnalytics: Bool
    @Binding var showingThemeSettings: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("快速操作")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                QuickActionButton(
                    icon: "message.circle.fill",
                    title: "快速回覆",
                    color: .blue
                ) {
                    showingQuickReply = true
                }
                
                QuickActionButton(
                    icon: "chart.bar.fill",
                    title: "數據分析",
                    color: .green
                ) {
                    showingAnalytics = true
                }
                
                QuickActionButton(
                    icon: "paintbrush.fill",
                    title: "主題設定",
                    color: .purple
                ) {
                    showingThemeSettings = true
                }
                
                QuickActionButton(
                    icon: "checkmark.circle.fill",
                    title: "標記已讀",
                    color: .orange
                ) {
                    // 標記所有已讀
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// 進階篩選區域
struct AdvancedFilterSection: View {
    @Binding var selectedFilter: ConversationStatus
    @Binding var selectedTimeRange: TimeRange
    @Binding var selectedCustomerType: CustomerType
    @Binding var showingAdvancedFilter: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("篩選條件")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("進階篩選") {
                    showingAdvancedFilter.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            
            if showingAdvancedFilter {
                VStack(spacing: 16) {
                    // 狀態篩選
                    VStack(alignment: .leading, spacing: 8) {
                        Text("對話狀態")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ConversationStatus.allCases, id: \.self) { status in
                                    FilterButton(
                                        title: status.displayName,
                                        isSelected: selectedFilter == status,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedFilter = status
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // 時間範圍篩選
                    VStack(alignment: .leading, spacing: 8) {
                        Text("時間範圍")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(TimeRange.allCases, id: \.self) { timeRange in
                                    FilterButton(
                                        title: timeRange.displayName,
                                        isSelected: selectedTimeRange == timeRange,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedTimeRange = timeRange
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // 客戶類型篩選
                    VStack(alignment: .leading, spacing: 8) {
                        Text("客戶類型")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(CustomerType.allCases, id: \.self) { customerType in
                                    FilterButton(
                                        title: customerType.displayName,
                                        isSelected: selectedCustomerType == customerType,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedCustomerType = customerType
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .padding(.horizontal, 20)
            } else {
                // 簡化篩選器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ConversationStatus.allCases, id: \.self) { status in
                            FilterButton(
                                title: status.displayName,
                                isSelected: selectedFilter == status,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedFilter = status
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// 對話列表區域
struct ConversationListSection: View {
    let conversations: [LineConversation]
    @Binding var showingNewMessage: Bool
    @Binding var selectedConversations: Set<String>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Line對話")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !selectedConversations.isEmpty {
                    Button("批量操作") {
                        // 批量操作邏輯
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Button("模擬新訊息") {
                    showingNewMessage = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            
            LazyVStack(spacing: 8) {
                ForEach(conversations) { conversation in
                    SelectableConversationRow(
                        conversation: conversation,
                        isSelected: selectedConversations.contains(conversation.id),
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                selectedConversations.insert(conversation.id)
                            } else {
                                selectedConversations.remove(conversation.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// Line風格的頂部區域
struct LineStyleHeaderView: View {
    let user: User?
    @Binding var searchText: String
    @Binding var showingNotifications: Bool
    @Binding var showingSettings: Bool
    let unreadCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 頂部狀態欄區域
            HStack {
                // 左側用戶資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(user?.username ?? "聖凱")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 右側功能按鈕
                HStack(spacing: 16) {
                    Button(action: {
                        // 書籤功能
                    }) {
                        Image(systemName: "bookmark")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        showingNotifications = true
                    }) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.title3)
                                .foregroundColor(.primary)
                            
                            if unreadCount > 0 {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    Button(action: {
                        // 新增朋友功能
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // 用戶頭像
            HStack {
                Spacer()
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // 搜尋欄
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("搜尋", text: $searchText)
                        .font(.subheadline)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Button(action: {
                    // 篩選功能
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
}



struct DashboardStatsView: View {
    let totalConversations: Int
    let activeConversations: Int
    let pendingMessages: Int
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "總對話",
                value: "\(totalConversations)",
                icon: "message.circle.fill",
                color: .blue
            )
            
            StatCard(
                title: "進行中",
                value: "\(activeConversations)",
                icon: "clock.fill",
                color: .orange
            )
            
            StatCard(
                title: "待處理",
                value: "\(pendingMessages)",
                icon: "exclamationmark.circle.fill",
                color: .red
            )
        }
        .padding(.horizontal, 20)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isSelected ?
                    Color.blue :
                    Color(.systemBackground)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.blue : Color(.systemGray4),
                            lineWidth: 0.5
                        )
                )
        }
    }
}

struct LineConversationRow: View {
    let conversation: LineConversation
    
    var body: some View {
        HStack(spacing: 12) {
            // 頭像
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 45, height: 45)
                    .overlay(
                        Text(String(conversation.customerName.prefix(1)))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    )
                
                // 未讀指示器
                if conversation.isUnread {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 16, y: -16)
                }
            }
            
            // 對話資訊
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.customerName)
                        .font(.subheadline)
                        .fontWeight(conversation.isUnread ? .semibold : .medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusBadge(status: conversation.status)
                }
                
                Text(conversation.lastMessage)
                    .font(.caption)
                    .foregroundColor(conversation.isUnread ? .primary : .secondary)
                    .fontWeight(conversation.isUnread ? .medium : .regular)
                    .lineLimit(1)
                
                HStack {
                    Text(conversation.lastMessageTime, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(conversation.messageCount) 則訊息")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 箭頭
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(conversation.isUnread ? Color.blue.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(conversation.isUnread ? Color.blue.opacity(0.2) : Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}

struct StatusBadge: View {
    let status: ConversationStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .cornerRadius(6)
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

// 快速操作按鈕
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
        }
    }
}

// 可選擇的對話行
struct SelectableConversationRow: View {
    let conversation: LineConversation
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 選擇按鈕
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            // 頭像
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 45, height: 45)
                    .overlay(
                        Text(String(conversation.customerName.prefix(1)))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    )
                
                // 未讀指示器
                if conversation.isUnread {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 16, y: -16)
                }
            }
            
            // 對話資訊
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.customerName)
                        .font(.subheadline)
                        .fontWeight(conversation.isUnread ? .semibold : .medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusBadge(status: conversation.status)
                }
                
                Text(conversation.lastMessage)
                    .font(.caption)
                    .foregroundColor(conversation.isUnread ? .primary : .secondary)
                    .fontWeight(conversation.isUnread ? .medium : .regular)
                    .lineLimit(1)
                
                HStack {
                    Text(conversation.lastMessageTime, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(conversation.messageCount) 則訊息")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 箭頭
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? Color.blue.opacity(0.1) :
            conversation.isUnread ? Color.blue.opacity(0.05) : Color(.systemBackground)
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.blue.opacity(0.3) :
                    conversation.isUnread ? Color.blue.opacity(0.2) : Color(.systemGray4),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
        .onTapGesture {
            // 導航到聊天視圖
        }
    }
}

struct ProfileCardView: View {
    let user: User?
    
    var body: some View {
        HStack(spacing: 15) {
            // 頭像
            Circle()
                .fill(Color.blue)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.white)
                )
            
            // 用戶資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.username ?? "未登入")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(user?.role.displayName ?? "未知角色")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let companyName = user?.companyName {
                    Text(companyName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 箭頭
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 24)
    }
}

struct NewMessageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject var lineService: LineService
    @State private var customerName = ""
    @State private var message = ""
    
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
                    
                    Text("模擬新訊息")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("模擬客戶發送新訊息")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 輸入區域
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("客戶名稱")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("輸入客戶名稱", text: $customerName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("訊息內容")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("輸入訊息內容", text: $message, axis: .vertical)
                            .textFieldStyle(CustomTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    // 按鈕
                    VStack(spacing: 15) {
                        Button("模擬訊息") {
                            simulateMessage()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            Color(.systemGray3) :
                            Color.blue
                        )
                        .cornerRadius(12)
                        .disabled(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
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
        .navigationTitle("新訊息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    private func simulateMessage() {
        let customerId = "customer_\(Int.random(in: 1000...9999))"
        let finalCustomerName = customerName.isEmpty ? "客戶 \(Int.random(in: 1...100))" : customerName
        let finalMessage = message.isEmpty ? "您好，我想詢問關於產品的事項" : message
        
        let newMessage = lineService.simulateIncomingMessage(
            customerId: customerId,
            customerName: finalCustomerName,
            message: finalMessage,
            conversationId: UUID().uuidString
        )
        
        // 保存到資料庫
        modelContext.insert(newMessage)
        
        // 更新或創建對話
        let conversations = try? modelContext.fetch(FetchDescriptor<LineConversation>())
        if let existingConversation = conversations?.first(where: { $0.customerId == customerId }) {
            existingConversation.lastMessage = finalMessage
            existingConversation.lastMessageTime = Date()
            existingConversation.messageCount += 1
            existingConversation.isUnread = true
        } else {
            let newConversation = LineConversation(customerId: customerId, customerName: finalCustomerName)
            newConversation.lastMessage = finalMessage
            newConversation.lastMessageTime = Date()
            newConversation.messageCount = 1
            newConversation.isUnread = true
            modelContext.insert(newConversation)
        }
        
        dismiss()
    }
}

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LineConversation.lastMessageTime, order: .reverse) private var conversations: [LineConversation]
    
    var unreadConversations: [LineConversation] {
        conversations.filter { $0.isUnread }
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
            
            VStack(spacing: 20) {
                // 標題
                HStack {
                    Text("通知")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("全部標為已讀") {
                        markAllAsRead()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                if unreadConversations.isEmpty {
                    // 空狀態
                    VStack(spacing: 15) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("沒有未讀通知")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("所有對話都已讀取")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 通知列表
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(unreadConversations) { conversation in
                                NotificationRow(conversation: conversation) {
                                    markAsRead(conversation)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    private func markAsRead(_ conversation: LineConversation) {
        conversation.isUnread = false
    }
    
    private func markAllAsRead() {
        for conversation in unreadConversations {
            conversation.isUnread = false
        }
    }
}

struct NotificationRow: View {
    let conversation: LineConversation
    let onMarkAsRead: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // 頭像
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(conversation.customerName.prefix(1)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                )
            
            // 通知內容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.customerName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(conversation.lastMessageTime, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(conversation.lastMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 標記已讀按鈕
            Button(action: onMarkAsRead) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    LineDashboardView()
        .modelContainer(for: LineMessage.self, inMemory: true)
}

// MARK: - 新增支援類型

enum TimeRange: String, CaseIterable {
    case all = "all"
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "thisWeek"
    case lastWeek = "lastWeek"
    case thisMonth = "thisMonth"
    case lastMonth = "lastMonth"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部時間"
        case .today:
            return "今天"
        case .yesterday:
            return "昨天"
        case .thisWeek:
            return "本週"
        case .lastWeek:
            return "上週"
        case .thisMonth:
            return "本月"
        case .lastMonth:
            return "上月"
        }
    }
    
    func filter(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return calendar.isDate(date, inSameDayAs: yesterday)
        case .thisWeek:
            let weekOfYear = calendar.component(.weekOfYear, from: now)
            let dateWeekOfYear = calendar.component(.weekOfYear, from: date)
            return weekOfYear == dateWeekOfYear
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let lastWeekOfYear = calendar.component(.weekOfYear, from: lastWeek)
            let dateWeekOfYear = calendar.component(.weekOfYear, from: date)
            return lastWeekOfYear == dateWeekOfYear
        case .thisMonth:
            let month = calendar.component(.month, from: now)
            let dateMonth = calendar.component(.month, from: date)
            return month == dateMonth
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            let lastMonthComponent = calendar.component(.month, from: lastMonth)
            let dateMonth = calendar.component(.month, from: date)
            return lastMonthComponent == dateMonth
        }
    }
}

enum CustomerType: String, CaseIterable {
    case all = "all"
    case vip = "vip"
    case regular = "regular"
    case new = "new"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部客戶"
        case .vip:
            return "VIP客戶"
        case .regular:
            return "一般客戶"
        case .new:
            return "新客戶"
        }
    }
    
    func matches(_ customerName: String) -> Bool {
        switch self {
        case .all:
            return true
        case .vip:
            return customerName.contains("VIP") || customerName.contains("vip")
        case .regular:
            return !customerName.contains("VIP") && !customerName.contains("vip") && !customerName.contains("新")
        case .new:
            return customerName.contains("新") || customerName.contains("New")
        }
    }
} 

// MARK: - 新增視圖組件

// 快速回覆視圖
struct QuickReplyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: QuickReplyTemplate = .greeting
    @State private var customMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 模板選擇
                VStack(alignment: .leading, spacing: 12) {
                    Text("選擇回覆模板")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(QuickReplyTemplate.allCases, id: \.self) { template in
                            QuickReplyTemplateCard(
                                template: template,
                                isSelected: selectedTemplate == template
                            ) {
                                selectedTemplate = template
                                customMessage = template.message
                            }
                        }
                    }
                }
                
                // 自定義訊息
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定義訊息")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("輸入自定義訊息", text: $customMessage, axis: .vertical)
                        .textFieldStyle(CustomTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                // 操作按鈕
                VStack(spacing: 12) {
                    Button("發送回覆") {
                        sendQuickReply()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                        Color(.systemGray3) : Color.blue
                    )
                    .cornerRadius(12)
                    .disabled(customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("取消") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationTitle("快速回覆")
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
    
    private func sendQuickReply() {
        // 發送快速回覆邏輯
        print("發送快速回覆: \(customMessage)")
        dismiss()
    }
}

// 數據分析視圖
struct AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    let conversations: [LineConversation]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 統計卡片
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        AnalyticsCard(
                            title: "總對話數",
                            value: "\(conversations.count)",
                            icon: "message.circle.fill",
                            color: .blue
                        )
                        
                        AnalyticsCard(
                            title: "進行中",
                            value: "\(conversations.filter { $0.status == .active }.count)",
                            icon: "clock.fill",
                            color: .orange
                        )
                        
                        AnalyticsCard(
                            title: "已解決",
                            value: "\(conversations.filter { $0.status == .resolved }.count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        
                        AnalyticsCard(
                            title: "未讀訊息",
                            value: "\(conversations.filter { $0.isUnread }.count)",
                            icon: "exclamationmark.circle.fill",
                            color: .red
                        )
                    }
                    
                    // 效率分析
                    VStack(alignment: .leading, spacing: 16) {
                        Text("效率分析")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            EfficiencyRow(
                                title: "平均回應時間",
                                value: "2.5 分鐘",
                                color: .green
                            )
                            
                            EfficiencyRow(
                                title: "解決率",
                                value: "85%",
                                color: .blue
                            )
                            
                            EfficiencyRow(
                                title: "客戶滿意度",
                                value: "4.8/5.0",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                    
                    // 熱門問題
                    VStack(alignment: .leading, spacing: 16) {
                        Text("熱門問題類型")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            PopularQuestionRow(
                                question: "產品退貨",
                                count: 15,
                                percentage: 30
                            )
                            
                            PopularQuestionRow(
                                question: "運費查詢",
                                count: 12,
                                percentage: 24
                            )
                            
                            PopularQuestionRow(
                                question: "會員升級",
                                count: 8,
                                percentage: 16
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .navigationTitle("數據分析")
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

// 主題設定視圖
struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedTheme") private var selectedTheme: AppTheme = .system
    @AppStorage("accentColor") private var accentColor: AccentColor = .blue
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 主題選擇
                VStack(alignment: .leading, spacing: 16) {
                    Text("主題設定")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            ThemeOptionRow(
                                theme: theme,
                                isSelected: selectedTheme == theme
                            ) {
                                selectedTheme = theme
                            }
                        }
                    }
                }
                
                // 強調色選擇
                VStack(alignment: .leading, spacing: 16) {
                    Text("強調色")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(AccentColor.allCases, id: \.self) { color in
                            ColorOptionButton(
                                color: color,
                                isSelected: accentColor == color
                            ) {
                                accentColor = color
                            }
                        }
                    }
                }
                
                // 其他設定
                VStack(alignment: .leading, spacing: 16) {
                    Text("其他設定")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        SettingRow(
                            icon: "bell.fill",
                            title: "通知設定",
                            subtitle: "管理推送通知"
                        )
                        
                        SettingRow(
                            icon: "keyboard",
                            title: "快捷鍵",
                            subtitle: "自定義快捷鍵"
                        )
                        
                        SettingRow(
                            icon: "textformat.size",
                            title: "字體大小",
                            subtitle: "調整介面字體"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .navigationTitle("主題設定")
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

// MARK: - 支援類型

enum QuickReplyTemplate: String, CaseIterable {
    case greeting = "greeting"
    case thanks = "thanks"
    case inquiry = "inquiry"
    case apology = "apology"
    case followUp = "followUp"
    
    var title: String {
        switch self {
        case .greeting:
            return "問候語"
        case .thanks:
            return "感謝"
        case .inquiry:
            return "詢問"
        case .apology:
            return "道歉"
        case .followUp:
            return "跟進"
        }
    }
    
    var message: String {
        switch self {
        case .greeting:
            return "您好！很高興為您服務，請問有什麼可以幫助您的嗎？"
        case .thanks:
            return "非常感謝您的支持！如果還有任何問題，隨時歡迎詢問。"
        case .inquiry:
            return "請問您需要了解什麼具體資訊呢？我會盡快為您解答。"
        case .apology:
            return "非常抱歉造成您的不便，我們會立即處理這個問題。"
        case .followUp:
            return "請問您對我們的服務還滿意嗎？有任何建議都歡迎提出。"
        }
    }
}

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "淺色主題"
        case .dark:
            return "深色主題"
        case .system:
            return "跟隨系統"
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "gear"
        }
    }
}

enum AccentColor: String, CaseIterable {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case red = "red"
    case purple = "purple"
    case pink = "pink"
    
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .red:
            return .red
        case .purple:
            return .purple
        case .pink:
            return .pink
        }
    }
}

// MARK: - 支援組件

struct QuickReplyTemplateCard: View {
    let template: QuickReplyTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(template.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.blue : Color(.systemGray4),
                        lineWidth: 0.5
                    )
            )
        }
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}

struct EfficiencyRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct PopularQuestionRow: View {
    let question: String
    let count: Int
    let percentage: Int
    
    var body: some View {
        HStack {
            Text(question)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count) 次")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: theme.icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 24)
                
                Text(theme.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.blue : Color(.systemGray4),
                        lineWidth: 0.5
                    )
            )
        }
    }
}

struct ColorOptionButton: View {
    let color: AccentColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color.blue : Color.clear,
                            lineWidth: 3
                        )
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

 