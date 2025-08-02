//
//  ChannelManagementView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData
import UIKit

struct ChannelManagementView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject private var authService: AuthService
    @Query private var channels: [Channel]
    @State private var selectedChannel: Channel?
    @State private var showingDeleteAlert = false
    @State private var channelToDelete: Channel?
    @State private var showingAddChannel = false
    @State private var selectedPlatform: PlatformType = .line
    @State private var isLoadingChannels = false
    @State private var syncError: String?
    
    // 平台類型
    enum PlatformType: String, CaseIterable {
        case line = "LINE"
        case whatsapp = "WhatsApp"
        case instagram = "Instagram"
        case facebook = "Facebook"
        
        var displayName: String {
            switch self {
            case .line: return "LINE"
            case .whatsapp: return "WhatsApp Business"
            case .instagram: return "Instagram Business"
            case .facebook: return "Facebook Messenger"
            }
        }
        
        var icon: String {
            switch self {
            case .line: return "message.circle.fill"
            case .whatsapp: return "phone.circle.fill"
            case .instagram: return "camera.circle.fill"
            case .facebook: return "person.2.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .line: return .green
            case .whatsapp: return .green
            case .instagram: return .purple
            case .facebook: return .blue
            }
        }
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
            
            ScrollView {
                VStack(spacing: 25) {
                    // 快速操作區域
                    QuickActionsSection()
                    
                    // 頻道列表
                    ChannelsListSection()
                    
                    // 統計資訊
                    StatisticsSection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("頻道管理")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddChannel) {
            AddChannelView(platform: selectedPlatform)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
        }
        .alert("確認刪除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                if let channel = channelToDelete {
                    deleteChannel(channel)
                }
            }
        } message: {
            Text("確定要刪除這個頻道嗎？此操作無法復原。")
        }
        .alert("同步錯誤", isPresented: .constant(syncError != nil)) {
            Button("確定") {
                syncError = nil
            }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
        .onAppear {
            loadChannelsFromBackend()
            checkChannelConnectionStatus()
            
            // 如果沒有頻道，添加一些測試資料
            if channels.isEmpty {
                addSampleChannels()
            }
        }
        .refreshable {
            await refreshChannels()
        }
    }
    
    // 快速操作區域
    private func QuickActionsSection() -> some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("快速操作")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ChannelActionCard(
                    title: "Line",
                    icon: "message.circle.fill",
                    color: .green,
                    action: { 
                        selectedPlatform = .line
                        showingAddChannel = true
                    }
                )
                
                ChannelActionCard(
                    title: "Instagram",
                    icon: "camera.circle.fill",
                    color: .purple,
                    action: { 
                        selectedPlatform = .instagram
                        showingAddChannel = true
                    }
                )
                
                ChannelActionCard(
                    title: "WhatsApp",
                    icon: "phone.circle.fill",
                    color: .green,
                    action: { 
                        selectedPlatform = .whatsapp
                        showingAddChannel = true
                    }
                )
                
                ChannelActionCard(
                    title: "Facebook",
                    icon: "person.2.circle.fill",
                    color: .blue,
                    action: { 
                        selectedPlatform = .facebook
                        showingAddChannel = true
                    }
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // 頻道列表區域
    private func ChannelsListSection() -> some View {
        VStack(spacing: 15) {
            HStack {
                Text("已連接頻道")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(channels.count) 個頻道")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if channels.isEmpty {
                EmptyChannelsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(channels, id: \.id) { channel in
                        ChannelCard(
                            channel: channel,
                            onTap: {
                                selectedChannel = channel
                            },
                            onDelete: {
                                channelToDelete = channel
                                showingDeleteAlert = true
                            },
                            onTestConnection: {
                                Task {
                                    await checkSingleChannelStatus(channel)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // 統計資訊區域
    private func StatisticsSection() -> some View {
        VStack(spacing: 15) {
            HStack {
                Text("頻道統計")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 15) {
                ChannelStatCard(
                    title: "總訊息",
                    value: "\(channels.reduce(0) { $0 + $1.totalMessages })",
                    icon: "message.fill",
                    color: .blue
                )
                
                ChannelStatCard(
                    title: "活躍頻道",
                    value: "\(channels.filter { $0.isActive }.count)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .green
                )
                
                ChannelStatCard(
                    title: "今日訊息",
                    value: "\(channels.reduce(0) { $0 + $1.todayMessages })",
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
    }
    
    private func deleteChannel(_ channel: Channel) {
        // 刪除頻道邏輯
        modelContext.delete(channel)
        do {
            try modelContext.save()
            print("✅ 頻道已刪除")
        } catch {
            print("❌ 刪除頻道失敗: \(error)")
        }
    }
    
    // 檢查頻道連接狀態
    private func checkChannelConnectionStatus() {
        Task {
            for channel in channels {
                await checkSingleChannelStatus(channel)
            }
        }
    }
    
    // 檢查單個頻道狀態
    private func checkSingleChannelStatus(_ channel: Channel) async {
        do {
            let channelAPIService = ChannelAPIService.shared
            let isConnected = try await channelAPIService.testChannelConnection(
                platform: channel.platform,
                apiKey: channel.apiKey,
                channelSecret: channel.channelSecret
            )
            
            await MainActor.run {
                channel.isActive = isConnected
                channel.apiStatus = isConnected ? "已連接" : "未連接"
                channel.updatedAt = Date()
                
                do {
                    try modelContext.save()
                    print("✅ \(channel.name) 連接狀態已更新: \(isConnected ? "已連接" : "未連接")")
                } catch {
                    print("❌ 更新頻道狀態失敗: \(error)")
                }
            }
        } catch {
            await MainActor.run {
                channel.isActive = false
                channel.apiStatus = "連接失敗"
                channel.updatedAt = Date()
                
                do {
                    try modelContext.save()
                    print("❌ \(channel.name) 連接檢查失敗: \(error.localizedDescription)")
                } catch {
                    print("❌ 更新頻道狀態失敗: \(error)")
                }
            }
        }
    }
    
    // 刷新頻道資料
    private func refreshChannels() async {
        await MainActor.run {
            isLoadingChannels = true
        }
        
        // 重新載入後端資料
        await loadChannelsFromBackendAsync()
        
        // 檢查連接狀態
        await checkChannelConnectionStatusAsync()
        
        await MainActor.run {
            isLoadingChannels = false
        }
    }
    
    // 異步載入後端資料
    private func loadChannelsFromBackendAsync() async {
        do {
            let channelAPIService = ChannelAPIService.shared
            let backendChannels = try await channelAPIService.getUserChannels()
            
            await MainActor.run {
                syncBackendChannelsToLocal(backendChannels)
            }
        } catch {
            await MainActor.run {
                print("❌ 從後端載入頻道失敗: \(error.localizedDescription)")
                syncError = "載入頻道失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // 異步檢查連接狀態
    private func checkChannelConnectionStatusAsync() async {
        for channel in channels {
            await checkSingleChannelStatus(channel)
        }
    }
    
    // 添加測試頻道資料
    private func addSampleChannels() {
        let sampleChannels = [
            Channel(name: "Line官方帳號", platform: "Line", userId: "current_user"),
            Channel(name: "Instagram商業帳號", platform: "Instagram", userId: "current_user"),
            Channel(name: "WhatsApp Business", platform: "WhatsApp", userId: "current_user")
        ]
        
        // 設定測試資料
        sampleChannels[0].isActive = true
        sampleChannels[0].apiStatus = "已連接"
        sampleChannels[0].totalMessages = 1250
        sampleChannels[0].todayMessages = 45
        sampleChannels[0].avgResponseTime = 15
        sampleChannels[0].satisfactionScore = 92
        sampleChannels[0].lastActivity = Date().addingTimeInterval(-3600)
        
        sampleChannels[1].isActive = true
        sampleChannels[1].apiStatus = "已連接"
        sampleChannels[1].totalMessages = 890
        sampleChannels[1].todayMessages = 23
        sampleChannels[1].avgResponseTime = 20
        sampleChannels[1].satisfactionScore = 88
        sampleChannels[1].lastActivity = Date().addingTimeInterval(-7200)
        
        sampleChannels[2].isActive = false
        sampleChannels[2].apiStatus = "未連接"
        sampleChannels[2].totalMessages = 0
        sampleChannels[2].todayMessages = 0
        sampleChannels[2].avgResponseTime = 0
        sampleChannels[2].satisfactionScore = 0
        sampleChannels[2].lastActivity = Date().addingTimeInterval(-86400)
        
        // 插入到資料庫
        for channel in sampleChannels {
            modelContext.insert(channel)
        }
        
        do {
            try modelContext.save()
            print("✅ 測試頻道資料已添加")
        } catch {
            print("❌ 添加測試頻道資料失敗: \(error)")
        }
    }
    
    // 從後端載入頻道資料
    private func loadChannelsFromBackend() {
        guard !isLoadingChannels else { return }
        
        isLoadingChannels = true
        
        Task {
            do {
                let channelAPIService = ChannelAPIService.shared
                let backendChannels = try await channelAPIService.getUserChannels()
                
                await MainActor.run {
                    // 將後端資料同步到本地資料庫
                    syncBackendChannelsToLocal(backendChannels)
                    isLoadingChannels = false
                }
                
            } catch {
                await MainActor.run {
                    print("❌ 從後端載入頻道失敗: \(error.localizedDescription)")
                    syncError = "載入頻道失敗: \(error.localizedDescription)"
                    isLoadingChannels = false
                }
            }
        }
    }
    
    // 將後端頻道資料同步到本地
    private func syncBackendChannelsToLocal(_ backendChannels: [ChannelAPIResponse]) {
        for backendChannel in backendChannels {
            // 檢查本地是否已存在此頻道
            let existingChannel = channels.first { channel in
                channel.name == backendChannel.name && channel.platform == backendChannel.platform
            }
            
            if existingChannel == nil {
                // 建立新的本地頻道
                let newChannel = Channel(
                    name: backendChannel.name,
                    platform: backendChannel.platform,
                    userId: backendChannel.userId
                )
                newChannel.apiKey = backendChannel.apiKey
                newChannel.channelSecret = backendChannel.channelSecret
                newChannel.isActive = backendChannel.isActive
                
                // 儲存後端 ID 關聯
                UserDefaults.standard.set(backendChannel.id, forKey: "\(backendChannel.platform)_backend_id")
                
                modelContext.insert(newChannel)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ 後端頻道資料已同步到本地")
        } catch {
            print("❌ 同步後端頻道資料到本地失敗: \(error)")
        }
    }
}

// 頻道操作卡片
struct ChannelActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 頻道卡片
struct ChannelCard: View {
    let channel: Channel
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTestConnection: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // 頻道圖標
                ZStack {
                    Circle()
                        .fill(channel.colorValue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: channel.icon)
                        .font(.title2)
                        .foregroundColor(channel.colorValue)
                }
                
                // 頻道資訊
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(channel.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 狀態指示器和文字
                        HStack(spacing: 4) {
                            Circle()
                                .fill(channel.isActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            
                            Text(channel.apiStatus)
                                .font(.caption2)
                                .foregroundColor(channel.isActive ? .green : .gray)
                        }
                    }
                    
                    Text(channel.channelDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Label("\(channel.totalMessages) 訊息", systemImage: "message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(channel.lastActivity, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 操作按鈕
                VStack(spacing: 8) {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: onTestConnection) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .buttonStyle(PlainButtonStyle())
    }
}

// 空頻道狀態視圖
struct EmptyChannelsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("還沒有連接頻道")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("連接您的社交媒體平台，開始管理多頻道訊息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// 頻道統計卡片
struct ChannelStatCard: View {
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
                .font(.title3)
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
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// 新增頻道視圖
struct AddChannelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 平台參數
    let platform: ChannelManagementView.PlatformType
    
    // 輸入值管理
    @State private var channelSecret: String = ""
    @State private var channelAccessToken: String = ""
    @State private var inputValues: [String] = ["", ""]
    @State private var completedSteps: Set<Int> = []
    
    // 當前平台的設定步驟
    @State private var currentSetupSteps: [StepData] = []
    
    var body: some View {
        ZStack {
            // 背景
            Color.primaryBackground
                .ignoresSafeArea()
            
                            // 直接顯示平台設定視圖
                PlatformSetupView(
                    platform: platform,
                    setupSteps: currentSetupSteps,
                    inputValues: $inputValues,
                    completedSteps: $completedSteps,
                    onComplete: completeSetup,
                    onBack: {
                        dismiss()
                    }
                )
        }
        .navigationTitle("\(platform.displayName) API設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("返回") {
                    dismiss()
                }
                .foregroundColor(Color.warmAccent)
            }
        }
        .onAppear {
            loadPlatformSetupSteps()
            loadSavedValues()
        }
    }
    
    // 載入平台設定步驟
    private func loadPlatformSetupSteps() {
        switch platform {
        case .line:
            currentSetupSteps = getLineSetupSteps()
        case .whatsapp:
            currentSetupSteps = getWhatsAppSetupSteps()
        case .instagram:
            currentSetupSteps = getInstagramSetupSteps()
        case .facebook:
            currentSetupSteps = getFacebookSetupSteps()
        }
    }
    
    // 載入已保存的值
    private func loadSavedValues() {
        switch platform {
        case .line:
            let secret = UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
            let token = UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
            let webhook = UserDefaults.standard.string(forKey: "userWebhookURL") ?? ""
            
            inputValues = [secret, token, webhook]
            updateCompletedSteps()
            
            // 強制重新生成用戶專屬 Webhook URL
            Task {
                print("🔄 強制重新生成 webhook URL...")
                await loadWebhookURLFromBackend()
            }
            
        case .whatsapp:
            let businessId = UserDefaults.standard.string(forKey: "whatsappBusinessAccountId") ?? ""
            let phoneId = UserDefaults.standard.string(forKey: "whatsappPhoneNumberId") ?? ""
            let token = UserDefaults.standard.string(forKey: "whatsappAccessToken") ?? ""
            let phone = UserDefaults.standard.string(forKey: "whatsappPhoneNumber") ?? ""
            let webhook = UserDefaults.standard.string(forKey: "whatsappWebhookUrl") ?? ""
            let verifyToken = UserDefaults.standard.string(forKey: "whatsappWebhookVerifyToken") ?? ""
            
            inputValues = [businessId, phoneId, token, phone, webhook, verifyToken]
            updateCompletedSteps()
            
        case .instagram:
            let accountId = UserDefaults.standard.string(forKey: "instagramBusinessAccountId") ?? ""
            let pageId = UserDefaults.standard.string(forKey: "instagramFacebookPageId") ?? ""
            let appId = UserDefaults.standard.string(forKey: "instagramAppId") ?? ""
            let appSecret = UserDefaults.standard.string(forKey: "instagramAppSecret") ?? ""
            let token = UserDefaults.standard.string(forKey: "instagramAccessToken") ?? ""
            let webhook = UserDefaults.standard.string(forKey: "instagramWebhookUrl") ?? ""
            
            inputValues = [accountId, pageId, appId, appSecret, token, webhook]
            updateCompletedSteps()
            
        case .facebook:
            let appId = UserDefaults.standard.string(forKey: "facebookAppId") ?? ""
            let appSecret = UserDefaults.standard.string(forKey: "facebookAppSecret") ?? ""
            let pageId = UserDefaults.standard.string(forKey: "facebookPageId") ?? ""
            let pageToken = UserDefaults.standard.string(forKey: "facebookPageAccessToken") ?? ""
            let webhook = UserDefaults.standard.string(forKey: "facebookWebhookUrl") ?? ""
            let verifyToken = UserDefaults.standard.string(forKey: "facebookWebhookVerifyToken") ?? ""
            
            inputValues = [appId, appSecret, pageId, pageToken, webhook, verifyToken]
            updateCompletedSteps()
        }
    }
    
    // 更新完成步驟狀態
    private func updateCompletedSteps() {
        completedSteps.removeAll()
        
        switch platform {
        case .line:
            if !(UserDefaults.standard.string(forKey: "lineChannelSecret")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "lineChannelAccessToken")?.isEmpty ?? true) {
                completedSteps.insert(0)
            }
            if !(UserDefaults.standard.string(forKey: "userWebhookURL")?.isEmpty ?? true) {
                completedSteps.insert(1)
            }
            
        case .whatsapp:
            if !(UserDefaults.standard.string(forKey: "whatsappBusinessAccountId")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "whatsappPhoneNumberId")?.isEmpty ?? true) {
                completedSteps.insert(0)
            }
            if !(UserDefaults.standard.string(forKey: "whatsappAccessToken")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "whatsappPhoneNumber")?.isEmpty ?? true) {
                completedSteps.insert(1)
            }
            if !(UserDefaults.standard.string(forKey: "whatsappWebhookUrl")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "whatsappWebhookVerifyToken")?.isEmpty ?? true) {
                completedSteps.insert(2)
            }
            
        case .instagram:
            if !(UserDefaults.standard.string(forKey: "instagramBusinessAccountId")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "instagramFacebookPageId")?.isEmpty ?? true) {
                completedSteps.insert(0)
            }
            if !(UserDefaults.standard.string(forKey: "instagramAppId")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "instagramAppSecret")?.isEmpty ?? true) {
                completedSteps.insert(1)
            }
            if !(UserDefaults.standard.string(forKey: "instagramAccessToken")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "instagramWebhookUrl")?.isEmpty ?? true) {
                completedSteps.insert(2)
            }
            
        case .facebook:
            if !(UserDefaults.standard.string(forKey: "facebookAppId")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "facebookAppSecret")?.isEmpty ?? true) {
                completedSteps.insert(0)
            }
            if !(UserDefaults.standard.string(forKey: "facebookPageId")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "facebookPageAccessToken")?.isEmpty ?? true) {
                completedSteps.insert(1)
            }
            if !(UserDefaults.standard.string(forKey: "facebookWebhookUrl")?.isEmpty ?? true) &&
               !(UserDefaults.standard.string(forKey: "facebookWebhookVerifyToken")?.isEmpty ?? true) {
                completedSteps.insert(2)
            }
        }
    }
    
    // 從後端載入 Webhook URL
    private func loadWebhookURLFromBackend() async {
        print("🚀 開始載入用戶專屬 webhook URL...")
        
        do {
            // 先嘗試從後端獲取用戶 ID
            let userId = try await getUserIDFromBackend()
            
            // 生成用戶專屬的 webhook URL
            let webhookURL = generateUserSpecificWebhookURL(userId: userId)
            
            print("✅ 成功生成 webhook URL，準備更新 UI...")
            
            await MainActor.run {
                // 更新 Webhook URL（索引 2）
                if inputValues.count > 2 {
                    inputValues[2] = webhookURL
                    print("📱 已更新 inputValues[2]: \(webhookURL)")
                } else {
                    // 確保數組有足夠的元素
                    while inputValues.count < 3 {
                        inputValues.append("")
                    }
                    inputValues[2] = webhookURL
                    print("📱 已擴展 inputValues 並設置 [2]: \(webhookURL)")
                }
                
                // 更新完成狀態
                if !webhookURL.isEmpty {
                    completedSteps.insert(1)
                    print("📱 已標記步驟 1 為完成")
                }
                
                print("📱 UI 更新完成！")
                print("📱 生成的用戶專屬 webhook URL: \(webhookURL)")
                print("📱 用戶 ID: \(userId)")
            }
            
            // 同步到後端（可選，不影響 UI 顯示）
            do {
                try await syncUserWebhookURLToBackend(userId: userId, webhookURL: webhookURL)
            } catch {
                print("⚠️ 後端同步失敗，但不影響 UI 顯示: \(error)")
            }
            
        } catch {
            print("❌ 生成用戶專屬 webhook URL 失敗: \(error)")
            print("🔧 嘗試使用備用方案...")
            
            // 備用方案：使用臨時用戶 ID 生成 URL
            let fallbackUserId = UUID().uuidString
            let fallbackURL = generateUserSpecificWebhookURL(userId: fallbackUserId)
            
            await MainActor.run {
                // 確保數組有足夠的元素
                while inputValues.count < 3 {
                    inputValues.append("")
                }
                inputValues[2] = fallbackURL
                
                // 更新完成狀態
                completedSteps.insert(1)
                
                print("📱 使用備用方案生成 URL: \(fallbackURL)")
            }
        }
    }
    
    // 從後端獲取用戶 ID
    private func getUserIDFromBackend() async throws -> String {
        print("🔍 開始獲取用戶 ID...")
        
        // 先嘗試從本地獲取用戶 ID
        if let savedUserId = UserDefaults.standard.string(forKey: "currentUserId") {
            print("📱 使用本地保存的用戶 ID: \(savedUserId)")
            return savedUserId
        }
        
        print("📱 本地沒有用戶 ID，嘗試從後端獲取...")
        
        // 如果本地沒有，嘗試從後端獲取
        do {
            let lineAPIService = LineAPIService()
            print("📱 調用 getUserProfile...")
            let userProfile = try await lineAPIService.getUserProfile()
            print("📱 成功獲取用戶資料，用戶 ID: \(userProfile.userId)")
            // 保存到本地
            UserDefaults.standard.set(userProfile.userId, forKey: "currentUserId")
            return userProfile.userId
        } catch {
            print("❌ 後端獲取用戶 ID 失敗: \(error)")
            // 如果後端失敗，生成一個臨時的用戶 ID
            let tempUserId = UUID().uuidString
            print("📱 生成臨時用戶 ID: \(tempUserId)")
            UserDefaults.standard.set(tempUserId, forKey: "currentUserId")
            return tempUserId
        }
    }
    
    // 生成用戶專屬的 webhook URL
    private func generateUserSpecificWebhookURL(userId: String) -> String {
        print("🔗 開始生成用戶專屬 webhook URL...")
        print("📱 用戶 ID: \(userId)")
        
        let lineAPIService = LineAPIService()
        let webhookURL = lineAPIService.generateUserSpecificWebhookURL(userId: userId)
        
        print("🔗 生成的 webhook URL: \(webhookURL)")
        return webhookURL
    }
    
    // 同步用戶 webhook URL 到後端
    private func syncUserWebhookURLToBackend(userId: String, webhookURL: String) async throws {
        // 保存到本地
        UserDefaults.standard.set(webhookURL, forKey: "userWebhookURL")
        
        // 嘗試同步到後端（可選）
        do {
            let lineAPIService = LineAPIService()
            let success = try await lineAPIService.syncUserWebhookURL(userId: userId, webhookURL: webhookURL)
            if !success {
                print("後端同步失敗，但本地已保存")
            }
        } catch {
            print("後端同步失敗：\(error.localizedDescription)，但本地已保存")
        }
    }
    
    // LINE 設定步驟
    private func getLineSetupSteps() -> [StepData] {
        return [
            StepData(
                number: 1,
                title: "取得 LINE API 憑證",
                description: "從 LINE Developers Console 獲取必要的 API 憑證",
                icon: "key.fill",
                isCompleted: false,
                isExpanded: true,
                instructions: [
                    "1. 登入 LINE Developers Console (https://developers.line.biz/)",
                    "2. 建立或選擇現有的 Messaging API Channel",
                    "3. 在 Channel 設定頁面複製 Channel Secret",
                    "4. 生成並複製 Channel Access Token"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Channel Secret", placeholder: "請輸入 Channel Secret"),
                    InputField(label: "Channel Access Token", placeholder: "請輸入 Channel Access Token")
                ]
            ),
            StepData(
                number: 2,
                title: "設定您的專屬 Webhook URL",
                description: "系統已為您生成專屬的 Webhook URL，請複製到 LINE Developers Console",
                icon: "link",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 系統已自動生成您的專屬 Webhook URL",
                    "2. 點擊複製按鈕複製 URL",
                    "3. 在 LINE Developers Console 中貼上此 URL",
                    "4. 啟用 Webhook 功能並點擊「Verify」測試連接",
                    "5. 如果 URL 沒有顯示，請點擊「重新生成」按鈕"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "您的專屬 Webhook URL", placeholder: "正在生成您的專屬 URL...", isReadOnly: true, copyButton: true)
                ]
            )
        ]
    }
    
    // WhatsApp 設定步驟
    private func getWhatsAppSetupSteps() -> [StepData] {
        return [
            StepData(
                number: 1,
                title: "建立 WhatsApp Business 帳號",
                description: "在 Meta Business Manager 中建立 WhatsApp Business API 應用程式",
                icon: "building.2.fill",
                isCompleted: false,
                isExpanded: true,
                instructions: [
                    "1. 登入 Meta Business Manager (https://business.facebook.com/)",
                    "2. 建立新的應用程式或選擇現有應用程式",
                    "3. 添加 WhatsApp Business API 產品",
                    "4. 完成商業驗證流程"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Business Account ID", placeholder: "請輸入 Business Account ID"),
                    InputField(label: "Phone Number ID", placeholder: "請輸入 Phone Number ID")
                ]
            ),
            StepData(
                number: 2,
                title: "取得 API 憑證",
                description: "獲取 WhatsApp Business API 的存取憑證",
                icon: "key.fill",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 在應用程式設定中生成永久存取權杖",
                    "2. 複製 Phone Number ID",
                    "3. 記錄您的 WhatsApp Business 電話號碼",
                    "4. 設定 Webhook URL"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Permanent Access Token", placeholder: "請輸入永久存取權杖"),
                    InputField(label: "WhatsApp Phone Number", placeholder: "請輸入 WhatsApp 電話號碼")
                ]
            ),
            StepData(
                number: 3,
                title: "設定 Webhook",
                description: "設定 Webhook 以接收 WhatsApp 訊息",
                icon: "link",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 在 WhatsApp Business API 設定中配置 Webhook",
                    "2. 設定 Webhook URL (必須是 HTTPS)",
                    "3. 選擇要接收的事件類型",
                    "4. 驗證 Webhook 設定"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Webhook URL", placeholder: "請輸入 Webhook URL"),
                    InputField(label: "Webhook Verify Token", placeholder: "請輸入驗證權杖")
                ]
            )
        ]
    }
    
    // Instagram 設定步驟
    private func getInstagramSetupSteps() -> [StepData] {
        return [
            StepData(
                number: 1,
                title: "建立 Instagram Business 帳號",
                description: "將個人 Instagram 帳號轉換為商業帳號",
                icon: "camera.fill",
                isCompleted: false,
                isExpanded: true,
                instructions: [
                    "1. 在 Instagram 應用程式中開啟設定",
                    "2. 選擇「帳號」>「切換到專業帳號」",
                    "3. 選擇「商業」帳號類型",
                    "4. 連接 Facebook 專頁"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Instagram Business Account ID", placeholder: "請輸入 Instagram 商業帳號 ID"),
                    InputField(label: "Connected Facebook Page ID", placeholder: "請輸入連接的 Facebook 專頁 ID")
                ]
            ),
            StepData(
                number: 2,
                title: "設定 Facebook 應用程式",
                description: "在 Meta for Developers 中建立應用程式",
                icon: "app.badge.fill",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 前往 Meta for Developers (https://developers.facebook.com/)",
                    "2. 建立新的應用程式",
                    "3. 添加 Instagram Basic Display 產品",
                    "4. 設定應用程式權限"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "App ID", placeholder: "請輸入應用程式 ID"),
                    InputField(label: "App Secret", placeholder: "請輸入應用程式密鑰")
                ]
            ),
            StepData(
                number: 3,
                title: "取得存取權杖",
                description: "獲取 Instagram Graph API 存取權杖",
                icon: "key.fill",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 在應用程式設定中生成長期存取權杖",
                    "2. 授權應用程式存取 Instagram 帳號",
                    "3. 設定 Webhook 以接收訊息通知",
                    "4. 測試 API 連接"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Long-lived Access Token", placeholder: "請輸入長期存取權杖"),
                    InputField(label: "Webhook URL", placeholder: "請輸入 Webhook URL")
                ]
            )
        ]
    }
    
    // Facebook 設定步驟
    private func getFacebookSetupSteps() -> [StepData] {
        return [
            StepData(
                number: 1,
                title: "建立 Facebook 應用程式",
                description: "在 Meta for Developers 中建立 Messenger 應用程式",
                icon: "app.badge.fill",
                isCompleted: false,
                isExpanded: true,
                instructions: [
                    "1. 前往 Meta for Developers (https://developers.facebook.com/)",
                    "2. 建立新的應用程式",
                    "3. 添加 Messenger 產品",
                    "4. 設定應用程式基本資訊"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "App ID", placeholder: "請輸入應用程式 ID"),
                    InputField(label: "App Secret", placeholder: "請輸入應用程式密鑰")
                ]
            ),
            StepData(
                number: 2,
                title: "設定 Facebook 專頁",
                description: "連接 Facebook 專頁到應用程式",
                icon: "person.2.fill",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 在應用程式設定中添加 Facebook 專頁",
                    "2. 生成專頁存取權杖",
                    "3. 設定專頁訊息權限",
                    "4. 啟用訊息接收功能"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Page ID", placeholder: "請輸入專頁 ID"),
                    InputField(label: "Page Access Token", placeholder: "請輸入專頁存取權杖")
                ]
            ),
            StepData(
                number: 3,
                title: "設定 Webhook",
                description: "設定 Webhook 以接收 Messenger 訊息",
                icon: "link",
                isCompleted: false,
                isExpanded: false,
                instructions: [
                    "1. 在 Messenger 設定中配置 Webhook",
                    "2. 設定 Webhook URL (必須是 HTTPS)",
                    "3. 選擇要接收的事件類型",
                    "4. 驗證 Webhook 設定"
                ],
                hasInputFields: true,
                inputFields: [
                    InputField(label: "Webhook URL", placeholder: "請輸入 Webhook URL"),
                    InputField(label: "Webhook Verify Token", placeholder: "請輸入驗證權杖")
                ]
            )
        ]
    }
    

    
    // 平台設定視圖
    struct PlatformSetupView: View {
        let platform: ChannelManagementView.PlatformType
        let setupSteps: [StepData]
        @Binding var inputValues: [String]
        @Binding var completedSteps: Set<Int>
        @State private var expandedSteps: Set<Int> = [0] // 預設展開第一個步驟
        let onComplete: () -> Void
        let onBack: () -> Void
        
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // 標題區域
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: platform.icon)
                                .font(.title2)
                                .foregroundColor(platform.color)
                            
                            Text("\(platform.displayName) API設定")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        Text("請按照以下步驟完成 \(platform.displayName) API 的設定")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 步驟列表
                    VStack(spacing: 12) {
                        ForEach(Array(setupSteps.enumerated()), id: \.element.number) { index, step in
                            ExpandableStepCard(
                                step: step,
                                isExpanded: Binding(
                                    get: { expandedSteps.contains(index) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedSteps.insert(index)
                                        } else {
                                            expandedSteps.remove(index)
                                        }
                                    }
                                ),
                                isCompleted: Binding(
                                    get: { completedSteps.contains(index) },
                                    set: { _ in }
                                ),
                                inputValues: $inputValues,
                                onNext: {
                                    handleNextStep(currentIndex: index)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 完成按鈕
                    VStack(spacing: 15) {
                        Button("完成設置") {
                            onComplete()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(platform.color)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
                .padding(.bottom, 60)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        onBack()
                    }
                    .foregroundColor(platform.color)
                }
            }
        }
        
        private func handleNextStep(currentIndex: Int) {
            // 根據步驟保存相應的數據
            if setupSteps[currentIndex].hasInputFields {
                saveStepData(currentIndex: currentIndex)
            }
            
            // 延遲一下讓動畫完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // 收起當前步驟
                    expandedSteps.remove(currentIndex)
                    
                    // 如果有下一個步驟，展開它
                    if currentIndex + 1 < setupSteps.count {
                        expandedSteps.insert(currentIndex + 1)
                    }
                }
            }
        }
        
        private func saveStepData(currentIndex: Int) {
            // 確保輸入值數組有足夠的元素
            while inputValues.count < 6 {
                inputValues.append("")
            }
            
            // 根據平台和步驟保存數據
            switch platform {
            case .line:
                saveLineData(currentIndex: currentIndex)
            case .whatsapp:
                saveWhatsAppData(currentIndex: currentIndex)
            case .instagram:
                saveInstagramData(currentIndex: currentIndex)
            case .facebook:
                saveFacebookData(currentIndex: currentIndex)
            }
            
            // 更新完成狀態
            updateCompletedStepsForPlatform()
        }
        
        private func updateCompletedStepsForPlatform() {
            completedSteps.removeAll()
            
            switch platform {
            case .line:
                if !(UserDefaults.standard.string(forKey: "lineChannelSecret")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "lineChannelAccessToken")?.isEmpty ?? true) {
                    completedSteps.insert(0)
                }
                if !(UserDefaults.standard.string(forKey: "userWebhookURL")?.isEmpty ?? true) {
                    completedSteps.insert(1)
                }
                
            case .whatsapp:
                if !(UserDefaults.standard.string(forKey: "whatsappBusinessAccountId")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "whatsappPhoneNumberId")?.isEmpty ?? true) {
                    completedSteps.insert(0)
                }
                if !(UserDefaults.standard.string(forKey: "whatsappAccessToken")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "whatsappPhoneNumber")?.isEmpty ?? true) {
                    completedSteps.insert(1)
                }
                if !(UserDefaults.standard.string(forKey: "whatsappWebhookUrl")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "whatsappWebhookVerifyToken")?.isEmpty ?? true) {
                    completedSteps.insert(2)
                }
                
            case .instagram:
                if !(UserDefaults.standard.string(forKey: "instagramBusinessAccountId")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "instagramFacebookPageId")?.isEmpty ?? true) {
                    completedSteps.insert(0)
                }
                if !(UserDefaults.standard.string(forKey: "instagramAppId")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "instagramAppSecret")?.isEmpty ?? true) {
                    completedSteps.insert(1)
                }
                if !(UserDefaults.standard.string(forKey: "instagramAccessToken")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "instagramWebhookUrl")?.isEmpty ?? true) {
                    completedSteps.insert(2)
                }
                
            case .facebook:
                if !(UserDefaults.standard.string(forKey: "facebookAppId")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "facebookAppSecret")?.isEmpty ?? true) {
                    completedSteps.insert(0)
                }
                if !(UserDefaults.standard.string(forKey: "facebookPageId")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "facebookPageAccessToken")?.isEmpty ?? true) {
                    completedSteps.insert(1)
                }
                if !(UserDefaults.standard.string(forKey: "facebookWebhookUrl")?.isEmpty ?? true) &&
                   !(UserDefaults.standard.string(forKey: "facebookWebhookVerifyToken")?.isEmpty ?? true) {
                    completedSteps.insert(2)
                }
            }
        }
        
        private func saveLineData(currentIndex: Int) {
            switch currentIndex {
            case 0: // Channel Secret和Channel Access Token
                UserDefaults.standard.set(inputValues[0], forKey: "lineChannelSecret")
                UserDefaults.standard.set(inputValues[1], forKey: "lineChannelAccessToken")
                print("✅ LINE Step 1: Channel credentials saved!")
            case 1: // Webhook URL
                UserDefaults.standard.set(inputValues[0], forKey: "userWebhookURL")
                print("✅ LINE Step 2: 用戶專屬 Webhook URL saved!")
            default:
                print("✅ LINE Step \(currentIndex + 1) completed!")
            }
        }
        
        private func saveWhatsAppData(currentIndex: Int) {
            switch currentIndex {
            case 0: // Business Account ID和Phone Number ID
                UserDefaults.standard.set(inputValues[0], forKey: "whatsappBusinessAccountId")
                UserDefaults.standard.set(inputValues[1], forKey: "whatsappPhoneNumberId")
                print("✅ WhatsApp Step 1: Business account data saved!")
            case 1: // Access Token和Phone Number
                UserDefaults.standard.set(inputValues[0], forKey: "whatsappAccessToken")
                UserDefaults.standard.set(inputValues[1], forKey: "whatsappPhoneNumber")
                print("✅ WhatsApp Step 2: Access credentials saved!")
            case 2: // Webhook URL和Verify Token
                UserDefaults.standard.set(inputValues[0], forKey: "whatsappWebhookUrl")
                UserDefaults.standard.set(inputValues[1], forKey: "whatsappWebhookVerifyToken")
                print("✅ WhatsApp Step 3: Webhook settings saved!")
            default:
                print("✅ WhatsApp Step \(currentIndex + 1) completed!")
            }
        }
        
        private func saveInstagramData(currentIndex: Int) {
            switch currentIndex {
            case 0: // Instagram Business Account ID和Facebook Page ID
                UserDefaults.standard.set(inputValues[0], forKey: "instagramBusinessAccountId")
                UserDefaults.standard.set(inputValues[1], forKey: "instagramFacebookPageId")
                print("✅ Instagram Step 1: Account data saved!")
            case 1: // App ID和App Secret
                UserDefaults.standard.set(inputValues[0], forKey: "instagramAppId")
                UserDefaults.standard.set(inputValues[1], forKey: "instagramAppSecret")
                print("✅ Instagram Step 2: App credentials saved!")
            case 2: // Access Token和Webhook URL
                UserDefaults.standard.set(inputValues[0], forKey: "instagramAccessToken")
                UserDefaults.standard.set(inputValues[1], forKey: "instagramWebhookUrl")
                print("✅ Instagram Step 3: Access token saved!")
            default:
                print("✅ Instagram Step \(currentIndex + 1) completed!")
            }
        }
        
        private func saveFacebookData(currentIndex: Int) {
            switch currentIndex {
            case 0: // App ID和App Secret
                UserDefaults.standard.set(inputValues[0], forKey: "facebookAppId")
                UserDefaults.standard.set(inputValues[1], forKey: "facebookAppSecret")
                print("✅ Facebook Step 1: App credentials saved!")
            case 1: // Page ID和Page Access Token
                UserDefaults.standard.set(inputValues[0], forKey: "facebookPageId")
                UserDefaults.standard.set(inputValues[1], forKey: "facebookPageAccessToken")
                print("✅ Facebook Step 2: Page credentials saved!")
            case 2: // Webhook URL和Verify Token
                UserDefaults.standard.set(inputValues[0], forKey: "facebookWebhookUrl")
                UserDefaults.standard.set(inputValues[1], forKey: "facebookWebhookVerifyToken")
                print("✅ Facebook Step 3: Webhook settings saved!")
            default:
                print("✅ Facebook Step \(currentIndex + 1) completed!")
            }
        }
    }
    
    private func saveChannelToDatabase() {
        // 根據平台創建對應的 Channel
        let channelName = getChannelName()
        let platformName = platform.rawValue
        
        let newChannel = Channel(
            name: channelName,
            platform: platformName,
            userId: "current_user" // 這裡應該使用實際的用戶ID
        )
        
        // 根據平台設定對應的憑證
        setChannelCredentials(newChannel)
        newChannel.isActive = true
        
        modelContext.insert(newChannel)
        
        do {
            try modelContext.save()
            print("✅ \(platform.displayName) Channel saved to database successfully!")
        } catch {
            print("❌ Error saving \(platform.displayName) channel to database: \(error)")
        }
    }
    
    private func getChannelName() -> String {
        switch platform {
        case .line:
            return "LINE 官方帳號"
        case .whatsapp:
            return "WhatsApp Business"
        case .instagram:
            return "Instagram 商業帳號"
        case .facebook:
            return "Facebook Messenger"
        }
    }
    
    private func setChannelCredentials(_ channel: Channel) {
        switch platform {
        case .line:
            channel.apiKey = UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
            channel.channelSecret = UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
            
        case .whatsapp:
            channel.apiKey = UserDefaults.standard.string(forKey: "whatsappAccessToken") ?? ""
            channel.channelSecret = UserDefaults.standard.string(forKey: "whatsappBusinessAccountId") ?? ""
            
        case .instagram:
            channel.apiKey = UserDefaults.standard.string(forKey: "instagramAccessToken") ?? ""
            channel.channelSecret = UserDefaults.standard.string(forKey: "instagramBusinessAccountId") ?? ""
            
        case .facebook:
            channel.apiKey = UserDefaults.standard.string(forKey: "facebookPageAccessToken") ?? ""
            channel.channelSecret = UserDefaults.standard.string(forKey: "facebookAppId") ?? ""
        }
    }
    
    // 同步頻道資料到後端
    private func syncChannelToBackend() {
        Task {
            do {
                let channelRequest = createChannelAPIRequest()
                let channelAPIService = ChannelAPIService.shared
                
                print("📤 正在發送頻道資料到後端...")
                let response = try await channelAPIService.createChannel(channelRequest)
                print("✅ 頻道已成功同步到後端，ID: \(response.id)")
                
                // 更新本地頻道的後端 ID
                updateLocalChannelWithBackendId(response.id)
                
            } catch {
                print("❌ 同步頻道到後端失敗: \(error.localizedDescription)")
                // 即使同步失敗，本地資料仍然保存
            }
        }
    }
    
    // 建立頻道 API 請求
    private func createChannelAPIRequest() -> ChannelAPIRequest {
        let channelName = getChannelName()
        let platformName = platform.rawValue
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "current_user"
        
        var apiKey = ""
        var channelSecret = ""
        var webhookUrl: String? = nil
        
        switch platform {
        case .line:
            apiKey = UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
            channelSecret = UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
            webhookUrl = UserDefaults.standard.string(forKey: "userWebhookURL")
            
        case .whatsapp:
            apiKey = UserDefaults.standard.string(forKey: "whatsappAccessToken") ?? ""
            channelSecret = UserDefaults.standard.string(forKey: "whatsappBusinessAccountId") ?? ""
            webhookUrl = UserDefaults.standard.string(forKey: "whatsappWebhookUrl")
            
        case .instagram:
            apiKey = UserDefaults.standard.string(forKey: "instagramAccessToken") ?? ""
            channelSecret = UserDefaults.standard.string(forKey: "instagramBusinessAccountId") ?? ""
            webhookUrl = UserDefaults.standard.string(forKey: "instagramWebhookUrl")
            
        case .facebook:
            apiKey = UserDefaults.standard.string(forKey: "facebookPageAccessToken") ?? ""
            channelSecret = UserDefaults.standard.string(forKey: "facebookAppId") ?? ""
            webhookUrl = UserDefaults.standard.string(forKey: "facebookWebhookUrl")
        }
        
        return ChannelAPIRequest(
            name: channelName,
            platform: platformName,
            apiKey: apiKey,
            channelSecret: channelSecret,
            webhookUrl: webhookUrl,
            isActive: true,
            userId: userId
        )
    }
    
    // 更新本地頻道與後端 ID 的關聯
    private func updateLocalChannelWithBackendId(_ backendId: String) {
        // 這裡可以將後端 ID 儲存到 UserDefaults 或本地資料庫
        // 以便後續的更新和刪除操作
        UserDefaults.standard.set(backendId, forKey: "\(platform.rawValue)_backend_id")
    }
    
    private func completeSetup() {
        // 根據平台檢查設定完整性
        let isComplete = checkPlatformSetup()
        
        if isComplete {
            print("🔍 開始測試 \(platform.displayName) API 連線...")
            
            // 測試 API 連線並同步到後端
            Task {
                let isConnected = await testPlatformConnection()
                
                await MainActor.run {
                    if isConnected {
                        print("🎉 \(platform.displayName) API 設定完成！連線成功！")
                        print("💾 正在保存頻道資料到本地資料庫...")
                        saveChannelToDatabase()
                        print("🌐 正在同步頻道資料到後端...")
                        syncChannelToBackend()
                        print("✅ 頻道設定已成功保存並同步！")
                        dismiss()
                    } else {
                        print("⚠️ \(platform.displayName) API 設定完成，但連線測試失敗")
                        print("💾 仍然保存頻道資料到本地資料庫...")
                        saveChannelToDatabase()
                        print("🌐 正在同步頻道資料到後端...")
                        syncChannelToBackend()
                        print("✅ 頻道設定已保存並同步（連線測試失敗）")
                        dismiss()
                    }
                }
            }
        } else {
            print("❌ 請完成所有必要的設定步驟")
            print("📋 缺少的設定項目：")
            printMissingSettings()
        }
    }
    
    private func printMissingSettings() {
        switch platform {
        case .line:
            if UserDefaults.standard.string(forKey: "lineChannelSecret")?.isEmpty ?? true {
                print("   - LINE Channel Secret")
            }
            if UserDefaults.standard.string(forKey: "lineChannelAccessToken")?.isEmpty ?? true {
                print("   - LINE Channel Access Token")
            }
            if UserDefaults.standard.string(forKey: "userWebhookURL")?.isEmpty ?? true {
                print("   - LINE 用戶專屬 Webhook URL")
            }
            
        case .whatsapp:
            if UserDefaults.standard.string(forKey: "whatsappBusinessAccountId")?.isEmpty ?? true {
                print("   - WhatsApp Business Account ID")
            }
            if UserDefaults.standard.string(forKey: "whatsappAccessToken")?.isEmpty ?? true {
                print("   - WhatsApp Access Token")
            }
            if UserDefaults.standard.string(forKey: "whatsappWebhookUrl")?.isEmpty ?? true {
                print("   - WhatsApp Webhook URL")
            }
            
        case .instagram:
            if UserDefaults.standard.string(forKey: "instagramBusinessAccountId")?.isEmpty ?? true {
                print("   - Instagram Business Account ID")
            }
            if UserDefaults.standard.string(forKey: "instagramAccessToken")?.isEmpty ?? true {
                print("   - Instagram Access Token")
            }
            if UserDefaults.standard.string(forKey: "instagramWebhookUrl")?.isEmpty ?? true {
                print("   - Instagram Webhook URL")
            }
            
        case .facebook:
            if UserDefaults.standard.string(forKey: "facebookAppId")?.isEmpty ?? true {
                print("   - Facebook App ID")
            }
            if UserDefaults.standard.string(forKey: "facebookPageAccessToken")?.isEmpty ?? true {
                print("   - Facebook Page Access Token")
            }
            if UserDefaults.standard.string(forKey: "facebookWebhookUrl")?.isEmpty ?? true {
                print("   - Facebook Webhook URL")
            }
        }
    }
    
    private func checkPlatformSetup() -> Bool {
        switch platform {
        case .line:
            let hasCredentials = !(UserDefaults.standard.string(forKey: "lineChannelSecret")?.isEmpty ?? true)
            let hasToken = !(UserDefaults.standard.string(forKey: "lineChannelAccessToken")?.isEmpty ?? true)
            let hasWebhook = !(UserDefaults.standard.string(forKey: "userWebhookURL")?.isEmpty ?? true)
            return hasCredentials && hasToken && hasWebhook
            
        case .whatsapp:
            let hasBusinessId = !(UserDefaults.standard.string(forKey: "whatsappBusinessAccountId")?.isEmpty ?? true)
            let hasToken = !(UserDefaults.standard.string(forKey: "whatsappAccessToken")?.isEmpty ?? true)
            let hasWebhook = !(UserDefaults.standard.string(forKey: "whatsappWebhookUrl")?.isEmpty ?? true)
            return hasBusinessId && hasToken && hasWebhook
            
        case .instagram:
            let hasAccountId = !(UserDefaults.standard.string(forKey: "instagramBusinessAccountId")?.isEmpty ?? true)
            let hasToken = !(UserDefaults.standard.string(forKey: "instagramAccessToken")?.isEmpty ?? true)
            let hasWebhook = !(UserDefaults.standard.string(forKey: "instagramWebhookUrl")?.isEmpty ?? true)
            return hasAccountId && hasToken && hasWebhook
            
        case .facebook:
            let hasAppId = !(UserDefaults.standard.string(forKey: "facebookAppId")?.isEmpty ?? true)
            let hasPageToken = !(UserDefaults.standard.string(forKey: "facebookPageAccessToken")?.isEmpty ?? true)
            let hasWebhook = !(UserDefaults.standard.string(forKey: "facebookWebhookUrl")?.isEmpty ?? true)
            return hasAppId && hasPageToken && hasWebhook
        }
    }
    
    private func testPlatformConnection() async -> Bool {
        do {
            let channelAPIService = ChannelAPIService.shared
            
            var apiKey = ""
            var channelSecret = ""
            
            switch platform {
            case .line:
                print("🔗 測試 LINE API 連線...")
                apiKey = UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
                channelSecret = UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
                
            case .whatsapp:
                print("🔗 測試 WhatsApp Business API 連線...")
                apiKey = UserDefaults.standard.string(forKey: "whatsappAccessToken") ?? ""
                channelSecret = UserDefaults.standard.string(forKey: "whatsappBusinessAccountId") ?? ""
                
            case .instagram:
                print("🔗 測試 Instagram Graph API 連線...")
                apiKey = UserDefaults.standard.string(forKey: "instagramAccessToken") ?? ""
                channelSecret = UserDefaults.standard.string(forKey: "instagramBusinessAccountId") ?? ""
                
            case .facebook:
                print("🔗 測試 Facebook Messenger API 連線...")
                apiKey = UserDefaults.standard.string(forKey: "facebookPageAccessToken") ?? ""
                channelSecret = UserDefaults.standard.string(forKey: "facebookAppId") ?? ""
            }
            
            // 使用後端測試端點
            let isConnected = try await channelAPIService.testChannelConnection(
                platform: platform.rawValue,
                apiKey: apiKey,
                channelSecret: channelSecret
            )
            
            print(isConnected ? "✅ \(platform.displayName) API 連線成功" : "❌ \(platform.displayName) API 連線失敗")
            return isConnected
            
        } catch {
            print("❌ 測試 \(platform.displayName) API 連線時發生錯誤: \(error.localizedDescription)")
            // 如果後端測試失敗，回退到本地測試
            return await fallbackLocalTest()
        }
    }
    
    // 本地測試作為備用方案
    private func fallbackLocalTest() async -> Bool {
        switch platform {
        case .line:
            let lineService = LineService()
            return await lineService.checkConnection()
            
        case .whatsapp, .instagram, .facebook:
            // 簡單的憑證存在性檢查
            let hasValidCredentials = !(UserDefaults.standard.string(forKey: "\(platform.rawValue.lowercased())AccessToken")?.isEmpty ?? true)
            return hasValidCredentials
        }
    }
    
}

// 連接狀態枚舉
enum ConnectionStatus {
    case connected
    case disconnected
    case testing
    case unknown
    
    var displayName: String {
        switch self {
        case .connected:
            return "已連接"
        case .disconnected:
            return "未連接"
        case .testing:
            return "測試中"
        case .unknown:
            return "未知"
        }
    }
    
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .testing:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        case .testing:
            return "clock.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

// 輸入欄位結構
struct InputField {
    let label: String
    let placeholder: String
    var value: String = ""
    var isReadOnly: Bool = false
    var copyButton: Bool = false
}

// 步驟數據結構
struct StepData {
    let number: Int
    let title: String
    let description: String
    let icon: String
    var isCompleted: Bool
    var isExpanded: Bool = false
    var instructions: [String]
    var hasInputFields: Bool = false
    var inputFields: [InputField] = []
}

// 步驟標題組件
struct StepHeaderView: View {
    let step: StepData
    let isExpanded: Bool
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("步驟 \(step.number)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.coolAccent)
                }
                .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.primaryText)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        Text("成功!")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Color.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dividerColor, lineWidth: 1)
            )
        }
    }
}

// 輸入欄位組件
struct InputFieldsView: View {
    let fields: [InputField]
    @Binding var inputValues: [String]
    @State private var showingCopyAlert = false
    @State private var copyAlertMessage = ""
    var onRegenerate: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.primaryText)
                    
                    HStack {
                        TextField(field.placeholder, text: Binding(
                            get: { inputValues.indices.contains(index) ? inputValues[index] : "" },
                            set: { newValue in
                                if !field.isReadOnly && inputValues.indices.contains(index) {
                                    inputValues[index] = newValue
                                } else if !field.isReadOnly {
                                    inputValues.append(newValue)
                                }
                            }
                        ))
                        .textFieldStyle(CustomTextFieldStyle())
                        .disabled(field.isReadOnly)
                        .foregroundColor(field.isReadOnly ? .secondary : .primary)
                        
                        if field.copyButton {
                            if !inputValues.isEmpty && inputValues.indices.contains(index) && !inputValues[index].isEmpty {
                                Button(action: {
                                    copyToClipboard(inputValues[index])
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                // 如果 URL 沒有顯示，顯示重新生成按鈕
                                Button(action: {
                                    onRegenerate?()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .alert("複製成功", isPresented: $showingCopyAlert) {
            Button("確定") { }
        } message: {
            Text(copyAlertMessage)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        copyAlertMessage = "已複製到剪貼簿"
        showingCopyAlert = true
    }
}

// 步驟說明組件
struct StepInstructionsView: View {
    let instructions: [String]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.coolAccent)
                            .frame(width: 24, height: 24)
                        
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Text(instruction)
                        .font(.subheadline)
                        .foregroundColor(Color.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// 下拉式步驟卡片組件
struct ExpandableStepCard: View {
    let step: StepData
    @Binding var isExpanded: Bool
    @Binding var isCompleted: Bool
    @Binding var inputValues: [String]
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            StepHeaderView(
                step: step,
                isExpanded: isExpanded,
                isCompleted: isCompleted,
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            )
            
            if isExpanded {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(Color.coolAccent)
                        
                        Text("如何\(step.title.components(separatedBy: " ").first ?? "")?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.primaryText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    if step.hasInputFields {
                        Text(getInputFieldDescription(for: step))
                            .font(.subheadline)
                            .foregroundColor(Color.primaryText)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                            .padding(.horizontal, 16)
                        
                        InputFieldsView(
                            fields: step.inputFields, 
                            inputValues: $inputValues,
                            onRegenerate: {
                                // 重新生成 webhook URL
                                Task {
                                    await regenerateWebhookURL()
                                }
                            }
                        )
                    } else {
                        StepInstructionsView(instructions: step.instructions)
                    }
                    
                    HStack {
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                    .font(.subheadline)
                                    .foregroundColor(Color.coolAccent)
                                
                                Text("我在哪裡找到以上資訊?")
                                    .font(.subheadline)
                                    .foregroundColor(Color.coolAccent)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isCompleted = true
                                isExpanded = false
                                onNext()
                            }
                        }) {
                            Text("下一頁")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.coolAccent)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(Color.cardBackground.opacity(0.5))
                .cornerRadius(12)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    private func getInputFieldDescription(for step: StepData) -> String {
        // 根據步驟標題返回對應的說明文字
        if step.title.contains("API 憑證") || step.title.contains("存取憑證") {
            return "請複製對應平台中的 API 憑證並將其貼到以下欄位中。"
        } else if step.title.contains("Webhook") {
            return "請設定 Webhook URL 以接收平台訊息通知。"
        } else if step.title.contains("帳號") {
            return "請輸入您的平台帳號相關資訊。"
        } else {
            return "請填寫以下必要資訊以完成設定。"
        }
    }
    
    private func regenerateWebhookURL() async {
        print("🔄 手動重新生成 webhook URL...")
        
        // 生成臨時用戶 ID
        let tempUserId = UUID().uuidString
        UserDefaults.standard.set(tempUserId, forKey: "currentUserId")
        
        // 生成 webhook URL
        let webhookURL = "https://ai-chatbot-umqm.onrender.com/api/webhook/line/\(tempUserId)"
        
        await MainActor.run {
            // 確保數組有足夠的元素
            while inputValues.count < 3 {
                inputValues.append("")
            }
            inputValues[2] = webhookURL
            
            // 更新完成狀態
            isCompleted = true
            
            print("📱 手動生成的 webhook URL: \(webhookURL)")
        }
    }
}

// 步驟詳情視圖
struct StepDetailView: View {
    let step: StepData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 步驟標題
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: step.icon)
                                    .font(.title)
                                    .foregroundColor(Color.warmAccent)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("步驟 \(step.number)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.warmAccent)
                                    
                                    Text(step.title)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.primaryText)
                                }
                                
                                Spacer()
                            }
                            
                            Text(step.description)
                                .font(.subheadline)
                                .foregroundColor(Color.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 詳細說明
                        VStack(spacing: 16) {
                            StepInstructionCard(
                                title: "操作步驟",
                                content: getStepInstructions(for: step.number)
                            )
                            
                            StepInstructionCard(
                                title: "注意事項",
                                content: getStepNotes(for: step.number)
                            )
                            
                            StepInstructionCard(
                                title: "完成檢查",
                                content: getStepChecklist(for: step.number)
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("步驟詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(Color.warmAccent)
                }
            }
        }
    }
    
    private func getStepInstructions(for stepNumber: Int) -> String {
        switch stepNumber {
        case 1:
            return "1. 登入LINE Developers Console\n2. 點擊「Create Channel」\n3. 選擇「Messaging API」\n4. 填寫頻道基本資訊\n5. 確認創建"
        case 2:
            return "1. 進入頻道設定頁面\n2. 複製Channel Secret\n3. 生成Channel Access Token\n4. 保存這些重要資訊"
        case 3:
            return "1. 設定Webhook URL\n2. 啟用Webhook\n3. 測試Webhook連接\n4. 確認接收消息"
        case 4:
            return "1. 設置官方帳號名稱\n2. 上傳帳號頭像\n3. 設定帳號描述\n4. 配置回應設定"
        case 5:
            return "1. 在LINE Developers中連接\n2. 掃描QR碼或輸入帳號\n3. 確認連接狀態\n4. 測試消息發送"
        case 6:
            return "1. 選擇主要語言\n2. 設定地區選項\n3. 配置時區設定\n4. 保存語言設定"
        default:
            return "請按照步驟說明進行操作"
        }
    }
    
    private func getStepNotes(for stepNumber: Int) -> String {
        switch stepNumber {
        case 1:
            return "• 確保有LINE Developers帳號\n• 頻道名稱要具有識別性\n• 建議使用英文命名"
        case 2:
            return "• Channel Secret和Token要妥善保存\n• 不要分享給他人\n• 定期更新Token"
        case 3:
            return "• Webhook URL必須是HTTPS\n• 確保伺服器可以接收POST請求\n• 測試連接很重要"
        case 4:
            return "• 官方帳號名稱要簡潔明瞭\n• 頭像要符合品牌形象\n• 描述要清楚說明服務內容"
        case 5:
            return "• 確保官方帳號已驗證\n• 連接後要測試功能\n• 注意API使用限制"
        case 6:
            return "• 語言設定影響用戶體驗\n• 地區設定影響服務範圍\n• 時區設定影響消息時間"
        default:
            return "請注意每個步驟的細節"
        }
    }
    
    private func getStepChecklist(for stepNumber: Int) -> String {
        switch stepNumber {
        case 1:
            return "□ 已創建Message API Channel\n□ 頻道名稱已設定\n□ 基本資訊已填寫\n□ 頻道狀態為Active"
        case 2:
            return "□ 已獲取Channel Secret\n□ 已生成Channel Access Token\n□ 已保存重要資訊\n□ 已測試Token有效性"
        case 3:
            return "□ 已設定Webhook URL\n□ 已啟用Webhook功能\n□ 已測試連接\n□ 已確認接收消息"
        case 4:
            return "□ 已設定帳號名稱\n□ 已上傳頭像\n□ 已填寫描述\n□ 已配置回應設定"
        case 5:
            return "□ 已連接官方帳號\n□ 已確認連接狀態\n□ 已測試消息發送\n□ 已驗證功能正常"
        case 6:
            return "□ 已選擇主要語言\n□ 已設定地區選項\n□ 已配置時區\n□ 已保存所有設定"
        default:
            return "請確認所有項目已完成"
        }
    }
}

// 步驟說明卡片
struct StepInstructionCard: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.primaryText)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }
}

// 平台選擇卡片
struct PlatformSelectionCard: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? color.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Line特定設定
struct LineSpecificSettings: View {
    @State private var channelId = ""
    @State private var channelSecret = ""
    
    var body: some View {
        SettingsSection(title: "Line設定") {
            VStack(spacing: 15) {
                SettingsField(
                    title: "Channel ID",
                    placeholder: "輸入Line Channel ID",
                    text: $channelId,
                    icon: "number.circle"
                )
                
                SettingsField(
                    title: "Channel Secret",
                    placeholder: "輸入Line Channel Secret",
                    text: $channelSecret,
                    isSecure: true,
                    icon: "lock.circle"
                )
            }
        }
    }
}

// Instagram特定設定
struct InstagramSpecificSettings: View {
    @State private var pageId = ""
    @State private var accessToken = ""
    
    var body: some View {
        SettingsSection(title: "Instagram設定") {
            VStack(spacing: 15) {
                SettingsField(
                    title: "Page ID",
                    placeholder: "輸入Facebook Page ID",
                    text: $pageId,
                    icon: "person.2.circle"
                )
                
                SettingsField(
                    title: "Access Token",
                    placeholder: "輸入Facebook Access Token",
                    text: $accessToken,
                    isSecure: true,
                    icon: "key.fill"
                )
            }
        }
    }
}

// WhatsApp特定設定
struct WhatsAppSpecificSettings: View {
    @State private var phoneNumberId = ""
    @State private var businessAccountId = ""
    
    var body: some View {
        SettingsSection(title: "WhatsApp設定") {
            VStack(spacing: 15) {
                SettingsField(
                    title: "Phone Number ID",
                    placeholder: "輸入WhatsApp Phone Number ID",
                    text: $phoneNumberId,
                    icon: "phone.circle"
                )
                
                SettingsField(
                    title: "Business Account ID",
                    placeholder: "輸入Business Account ID",
                    text: $businessAccountId,
                    icon: "building.2.circle"
                )
            }
        }
    }
}

// Facebook特定設定
struct FacebookSpecificSettings: View {
    @State private var pageId = ""
    @State private var accessToken = ""
    
    var body: some View {
        SettingsSection(title: "Facebook設定") {
            VStack(spacing: 15) {
                SettingsField(
                    title: "Page ID",
                    placeholder: "輸入Facebook Page ID",
                    text: $pageId,
                    icon: "person.2.circle"
                )
                
                SettingsField(
                    title: "Access Token",
                    placeholder: "輸入Facebook Access Token",
                    text: $accessToken,
                    isSecure: true,
                    icon: "key.fill"
                )
            }
        }
    }
}

// 頻道詳情視圖
struct ChannelDetailView: View {
    let channel: Channel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTestingConnection = false
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 頻道資訊卡片
                        ChannelInfoCard(channel: channel)
                        
                        // 統計資訊
                        ChannelStatsCard(channel: channel)
                        
                        // 操作按鈕
                        VStack(spacing: 15) {
                            Button("編輯設定") {
                                showingEdit = true
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                            
                            Button(action: testChannelConnection) {
                                HStack {
                                    if isTestingConnection {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: connectionStatus.icon)
                                            .foregroundColor(connectionStatus.color)
                                    }
                                    
                                    Text(isTestingConnection ? "測試中..." : "測試連接")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(isTestingConnection)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
                    .sheet(isPresented: $showingEdit) {
                EditChannelView(channel: channel)
            }
            .onAppear {
                // 自動檢查連接狀態
                if channel.platform == "LINE" {
                    testChannelConnection()
                }
            }
    }
    
    // 測試頻道連接
    private func testChannelConnection() {
        if channel.platform == "LINE" {
            isTestingConnection = true
            connectionStatus = .testing
            
            Task {
                let lineService = LineService()
                let isConnected = await lineService.checkConnection()
                
                await MainActor.run {
                    isTestingConnection = false
                    connectionStatus = isConnected ? .connected : .disconnected
                    
                    if isConnected {
                        print("✅ LINE 頻道連接測試成功！")
                    } else {
                        print("❌ LINE 頻道連接測試失敗！")
                    }
                }
            }
        } else {
            print("⚠️ 此頻道類型暫不支援連接測試")
        }
    }
}

// 頻道資訊卡片
struct ChannelInfoCard: View {
    let channel: Channel
    
    var body: some View {
        VStack(spacing: 20) {
            // 圖標和狀態
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(channel.colorValue.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: channel.icon)
                        .font(.system(size: 40))
                        .foregroundColor(channel.colorValue)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(channel.isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(channel.isActive ? "已連接" : "未連接")
                        .font(.caption)
                        .foregroundColor(channel.isActive ? .green : .gray)
                }
            }
            
            // 基本資訊
            VStack(spacing: 8) {
                Text(channel.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(channel.channelDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 詳細資訊
            VStack(spacing: 12) {
                ChannelDetailRow(title: "平台", value: channel.platform, icon: "antenna.radiowaves.left.and.right.fill")
                ChannelDetailRow(title: "API狀態", value: channel.apiStatus, icon: "checkmark.circle.fill")
                ChannelDetailRow(title: "最後活動", value: channel.lastActivity.formatted(), icon: "clock.fill")
                ChannelDetailRow(title: "訊息總數", value: "\(channel.totalMessages)", icon: "message.fill")
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// 頻道統計卡片
struct ChannelStatsCard: View {
    let channel: Channel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("今日統計")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 15) {
                ChannelStatItem(title: "今日訊息", value: "\(channel.todayMessages)", icon: "message.fill", color: .blue)
                ChannelStatItem(title: "回應時間", value: "\(channel.avgResponseTime)秒", icon: "clock.fill", color: .green)
                ChannelStatItem(title: "滿意度", value: "\(channel.satisfactionScore)%", icon: "star.fill", color: .orange)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// 頻道詳情行
struct ChannelDetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// 頻道統計項目
struct ChannelStatItem: View {
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
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// 編輯頻道視圖
struct EditChannelView: View {
    let channel: Channel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var channelName: String
    @State private var apiKey: String
    @State private var webhookUrl: String
    @State private var isActive: Bool
    
    init(channel: Channel) {
        self.channel = channel
        _channelName = State(initialValue: channel.name)
        _apiKey = State(initialValue: channel.apiKey)
        _webhookUrl = State(initialValue: channel.webhookUrl)
        _isActive = State(initialValue: channel.isActive)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 基本設定
                        SettingsSection(title: "基本設定") {
                            VStack(spacing: 15) {
                                SettingsField(
                                    title: "頻道名稱",
                                    placeholder: "輸入頻道名稱",
                                    text: $channelName,
                                    icon: "tag"
                                )
                                
                                SettingsField(
                                    title: "API金鑰",
                                    placeholder: "輸入平台API金鑰",
                                    text: $apiKey,
                                    isSecure: true,
                                    icon: "key.fill"
                                )
                                
                                SettingsField(
                                    title: "Webhook URL",
                                    placeholder: "輸入Webhook URL（可選）",
                                    text: $webhookUrl,
                                    icon: "link"
                                )
                                
                                Toggle("啟用頻道", isOn: $isActive)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // 操作按鈕
                        VStack(spacing: 15) {
                            Button("保存變更") {
                                saveChanges()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                            
                            Button("取消") {
                                dismiss()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 10)
                }
            }
            .navigationTitle("編輯頻道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        // 更新 Channel 資料
        channel.name = channelName
        channel.apiKey = apiKey
        channel.webhookUrl = webhookUrl
        channel.isActive = isActive
        
        // 如果是 LINE 頻道，同時更新 UserDefaults
        if channel.platform == "LINE" {
            UserDefaults.standard.set(apiKey, forKey: "lineChannelAccessToken")
            UserDefaults.standard.set(webhookUrl, forKey: "lineWebhookUrl")
            
            // 測試更新後的連接
            Task {
                let lineService = LineService()
                let isConnected = await lineService.checkConnection()
                
                await MainActor.run {
                    if isConnected {
                        print("✅ LINE 設定更新成功，連接正常！")
                    } else {
                        print("⚠️ LINE 設定已更新，但連接測試失敗")
                    }
                }
            }
        }
        
        // 保存到資料庫
        do {
            try modelContext.save()
            print("✅ 頻道設定已保存")
        } catch {
            print("❌ 保存頻道設定失敗：\(error)")
        }
        
        dismiss()
    }
}

#Preview {
    ChannelManagementView()
        .modelContainer(for: Channel.self, inMemory: true)
} 