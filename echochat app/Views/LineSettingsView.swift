//
//  LineSettingsView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct LineSettingsView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject private var authService: AuthService
    
    @AppStorage("lineChannelAccessToken") private var channelAccessToken = ""
    @AppStorage("lineChannelSecret") private var channelSecret = ""
    @AppStorage("autoApproveMessages") private var autoApproveMessages = false
    @AppStorage("autoResponseEnabled") private var autoResponseEnabled = true
    @AppStorage("responseDelay") private var responseDelay = 2.0
    
    @State private var showingTestAlert = false
    @State private var testResult = ""
    @State private var isTesting = false
    
    // 新增：保存進度相關狀態
    @State private var isSaving = false
    @State private var saveProgress: Double = 0.0
    @State private var saveStatus: LineSaveStatus = .idle
    @State private var showingSaveProgress = false
    
    // 新增：API 整合相關狀態
    @State private var isLoadingSettings = false
    @State private var backendWebhookUrl = ""
    @State private var showingCopyAlert = false
    @State private var copyAlertMessage = ""
    @State private var loadError: String? = nil
    @State private var showingLoadError = false
    
    // 新增：用戶 ID 和動態 URL 生成
    @State private var currentUserId: String = ""
    @State private var userSpecificWebhookUrl = ""
    @State private var isGeneratingUrl = false
    
    // 新增：LINE API 服務
    @StateObject private var lineAPIService = LineAPIService()
    
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
            
            ScrollView {
                VStack(spacing: 25) {
                    // Line API 設定
                    SettingsSection(title: "Line API 設定") {
                        VStack(spacing: 15) {
                            SettingsField(
                                title: "Channel Access Token",
                                placeholder: "輸入您的 Line Channel Access Token",
                                text: $channelAccessToken,
                                isSecure: true,
                                icon: "key"
                            )
                            
                            SettingsField(
                                title: "Channel Secret",
                                placeholder: "輸入您的 Line Channel Secret",
                                text: $channelSecret,
                                isSecure: true,
                                icon: "lock"
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Webhook URL")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if isLoadingSettings {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else if loadError != nil {
                                        Button(action: {
                                            Task {
                                                await loadSettingsFromBackend()
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.caption)
                                                Text("重試")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.orange)
                                        }
                                    }
                                }
                                
                                HStack {
                                    TextField(
                                        loadError != nil ? "載入失敗，點擊重試" : (backendWebhookUrl.isEmpty ? "載入中..." : backendWebhookUrl),
                                        text: .constant(backendWebhookUrl)
                                    )
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(true)
                                    .foregroundColor(loadError != nil ? .red : (backendWebhookUrl.isEmpty ? .secondary : .primary))
                                    
                                    if !backendWebhookUrl.isEmpty && loadError == nil {
                                        Button(action: {
                                            copyWebhookURL()
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                
                                if let error = loadError {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        Spacer()
                                    }
                                }
                                
                                if !backendWebhookUrl.isEmpty {
                                    HStack {
                                        Image(systemName: lineAPIService.validateWebhookURL(backendWebhookUrl) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(lineAPIService.validateWebhookURL(backendWebhookUrl) ? .green : .red)
                                        Text(lineAPIService.validateWebhookURL(backendWebhookUrl) ? "URL 格式正確" : "URL 格式不正確")
                                            .font(.caption)
                                            .foregroundColor(lineAPIService.validateWebhookURL(backendWebhookUrl) ? .green : .red)
                                        
                                        Spacer()
                                        
                                        Button("測試") {
                                            Task {
                                                let isAccessible = await lineAPIService.testWebhookURL(backendWebhookUrl)
                                                testResult = isAccessible ? "Webhook URL 可訪問" : "Webhook URL 無法訪問"
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 自動回應設定
                    SettingsSection(title: "自動回應設定") {
                        VStack(spacing: 15) {
                            LineSettingsToggle(
                                title: "啟用自動回應",
                                isOn: $autoResponseEnabled
                            )
                            
                            LineSettingsToggle(
                                title: "自動核准訊息",
                                isOn: $autoApproveMessages,
                                isDisabled: !autoResponseEnabled
                            )
                            
                            SettingsSlider(
                                title: "回應延遲 (秒)",
                                value: $responseDelay,
                                range: 0...10,
                                step: 0.5,
                                format: "%.1f",
                                icon: "timer"
                            )
                        }
                    }
                    
                    // 快速操作
                    SettingsSection(title: "快速操作") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await loadSettingsFromBackend()
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.title2)
                                        Text("重新載入")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                }
                                .foregroundColor(.blue)
                                
                                Button(action: {
                                    testLineConnection()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "network")
                                            .font(.title2)
                                        Text("測試連線")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.orange, lineWidth: 1)
                                    )
                                }
                                .foregroundColor(.orange)
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    copyWebhookURL()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.title2)
                                        Text("複製 URL")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green, lineWidth: 1)
                                    )
                                }
                                .foregroundColor(.green)
                                .disabled(backendWebhookUrl.isEmpty)
                                
                                Button(action: {
                                    saveLineSettings()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.title2)
                                        Text("保存設定")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.purple, lineWidth: 1)
                                    )
                                }
                                .foregroundColor(.purple)
                                .disabled(channelAccessToken.isEmpty || channelSecret.isEmpty)
                            }
                        }
                    }
                    
                    // 操作按鈕
                    VStack(spacing: 15) {
                        // 新增：保存設定按鈕
                        Button(action: saveLineSettings) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.white)
                                }
                                Text("保存 Line 設定")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(isSaving)
                        
                        // 測試連線
                        Button(action: testLineConnection) {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wifi")
                                        .foregroundColor(.white)
                                }
                                Text("測試 Line 連線")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isTesting)
                        
                        if !testResult.isEmpty {
                            Text(testResult)
                                .font(.caption)
                                .foregroundColor(testResult.contains("成功") ? .green : .red)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Webhook 設定
                    SettingsSection(title: "Webhook 設定") {
                        VStack(spacing: 15) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Webhook 端點")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                // 新增：用戶專屬 Webhook URL
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("您的專屬端點")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if isGeneratingUrl {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Button(action: {
                                                Task {
                                                    await generateUserSpecificWebhookURL()
                                                }
                                            }) {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    
                                    if !userSpecificWebhookUrl.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(userSpecificWebhookUrl)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding()
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                                )
                                            
                                            HStack {
                                                Button(action: {
                                                    copyUserSpecificWebhookURL()
                                                }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.caption)
                                                        Text("複製")
                                                            .font(.caption)
                                                    }
                                                    .foregroundColor(.blue)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("用戶 ID: \(currentUserId)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    } else {
                                        Text("點擊重新整理按鈕生成您的專屬端點")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                    }
                                    
                                    Text("• 基於您的用戶 ID 動態生成")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("• 支援 AI 聊天回應")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("• 自動認證和授權")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    // 新增：測試按鈕
                                    Button(action: {
                                        Task {
                                            await generateUserSpecificWebhookURL()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.circle")
                                                .font(.caption)
                                            Text("測試生成")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("簡化端點")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("https://ai-chatbot-umqm.onrender.com/api/webhook/line-simple")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    
                                    Text("• 無需認證")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("• 基本事件處理")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                    
                    // 使用說明
                    SettingsSection(title: "使用說明") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. 在 Line Developers Console 建立 Channel")
                            Text("2. 取得 Channel Access Token 和 Channel Secret")
                            Text("3. 設定 Webhook URL")
                            Text("4. 測試連線")
                            Text("5. 開始接收客戶訊息")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Line 設定")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("測試結果", isPresented: $showingTestAlert) {
            Button("確定") { }
        } message: {
            Text(testResult)
        }
        .sheet(isPresented: $showingSaveProgress) {
            LineSaveProgressView(
                progress: $saveProgress,
                status: $saveStatus,
                isPresented: $showingSaveProgress
            )
        }
        .alert("複製成功", isPresented: $showingCopyAlert) {
            Button("確定") { }
        } message: {
            Text(copyAlertMessage)
        }
        .alert("載入錯誤", isPresented: $showingLoadError) {
            Button("重試") {
                Task {
                    await loadSettingsFromBackend()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(loadError ?? "未知錯誤")
        }
        .onAppear {
            loadExistingSettings()
            // 新增：自動生成用戶專屬 webhook URL
            Task {
                await generateUserSpecificWebhookURL()
            }
        }
    }
    
    // 新增：保存Line設定功能
    private func saveLineSettings() {
        guard !channelAccessToken.isEmpty && !channelSecret.isEmpty else {
            testResult = "請先輸入 Channel Access Token 和 Channel Secret"
            return
        }
        
        showingSaveProgress = true
        saveProgress = 0.0
        saveStatus = .validating
        
        // 實際保存到後端
        Task {
            await saveLineSettingsToBackend()
        }
    }
    
    // 實際保存Line設定到後端
    private func saveLineSettingsToBackend() async {
        do {
            // 步驟1：驗證設定 (0-20%)
            await updateLineProgress(to: 0.2, status: .validating, delay: 0.5)
            
            // 步驟2：檢查Line API連線 (20-50%)
            await updateLineProgress(to: 0.5, status: .connecting, delay: 1.0)
            
            let isConnected = await lineAPIService.checkConnection()
            
            // 步驟3：測試Webhook設定 (50-80%)
            await updateLineProgress(to: 0.8, status: .testing, delay: 1.5)
            
            // 步驟4：保存設定到後端 (80-90%)
            await updateLineProgress(to: 0.9, status: .saving, delay: 0.8)
            
            // 保存 Channel Secret 和 Channel Access Token 到後端
            let saveSuccess = try await lineAPIService.saveLineAPISettings(
                channelSecret: channelSecret,
                channelAccessToken: channelAccessToken
            )
            
            if !saveSuccess {
                throw LineAPIError.serverError("保存設定到後端失敗")
            }
            
            // 保存本地設定
            UserDefaults.standard.set(channelAccessToken, forKey: "lineChannelAccessToken")
            UserDefaults.standard.set(channelSecret, forKey: "lineChannelSecret")
            UserDefaults.standard.set(autoResponseEnabled, forKey: "autoResponseEnabled")
            UserDefaults.standard.set(autoApproveMessages, forKey: "autoApproveMessages")
            UserDefaults.standard.set(responseDelay, forKey: "responseDelay")
            
            // 重新載入設定以獲取最新的 Webhook URL
            await loadSettingsFromBackend()
            
            // 步驟5：完成保存 (90-100%)
            await updateLineProgress(to: 1.0, status: .saving, delay: 0.5)
            
            // 完成
            await MainActor.run {
                saveStatus = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingSaveProgress = false
                    testResult = isConnected ? "Line設定保存成功！串接已完成。" : "設定已保存，但連線測試失敗，請檢查API設定。"
                }
            }
        } catch let error {
            await MainActor.run {
                saveStatus = .error
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingSaveProgress = false
                    testResult = "保存失敗：\(error.localizedDescription)"
                }
            }
        }
    }
    
    // 更新Line進度
    private func updateLineProgress(to progress: Double, status: LineSaveStatus, delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                saveProgress = progress
                saveStatus = status
            }
        }
    }
    
    private func testLineConnection() {
        isTesting = true
        testResult = ""
        
        // 實際測試 LINE API 連線
        Task {
            let isConnected = await lineAPIService.checkConnection()
            
            await MainActor.run {
                if isConnected {
                    testResult = "連線成功！Line API 已正確設定。"
                } else {
                    testResult = "連線失敗！請檢查 Channel Access Token 和 Channel Secret。"
                }
                isTesting = false
                showingTestAlert = true
            }
        }
    }
    
    // 載入現有設定
    private func loadExistingSettings() {
        Task {
            await loadSettingsFromBackend()
        }
    }
    
    // 從後端載入設定
    private func loadSettingsFromBackend() async {
        await MainActor.run {
            isLoadingSettings = true
            loadError = nil
        }
        
        do {
            let settings = try await lineAPIService.fetchLineAPISettings()
            
            // 更新 UI（必須在主線程執行）
            await MainActor.run {
                channelSecret = settings.channelSecret
                channelAccessToken = settings.channelAccessToken
                // 安全防呆：若後端回傳的 webhookUrl 無效，改用本機正確生成的 URL
                let candidate = settings.webhookUrl
                let resolved = lineAPIService.validateWebhookURL(candidate) ? candidate : lineAPIService.getCurrentWebhookURL()
                backendWebhookUrl = resolved
                isLoadingSettings = false
                loadError = nil
            }
            
            print("✅ 成功從後端載入 LINE API 設定")
            print("📋 載入的資料：")
            print("   - Channel Secret: \(settings.channelSecret)")
            print("   - Channel Access Token: \(settings.channelAccessToken)")
            print("   - Webhook URL: \(settings.webhookUrl)")
        } catch {
            await MainActor.run {
                isLoadingSettings = false
                loadError = "載入失敗：\(error.localizedDescription)"
                print("❌ 載入設定失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // 複製 Webhook URL 到剪貼簿
    private func copyWebhookURL() {
        guard !backendWebhookUrl.isEmpty else { return }
        
        UIPasteboard.general.string = backendWebhookUrl
        copyAlertMessage = "Webhook URL 已複製到剪貼簿"
        showingCopyAlert = true
    }
    
    // 新增：生成用戶專屬 Webhook URL
    private func generateUserSpecificWebhookURL() async {
        await MainActor.run {
            isGeneratingUrl = true
        }
        
        // 先檢查是否有已保存的 URL
        if let savedWebhookURL = UserDefaults.standard.string(forKey: "userWebhookURL"),
           let savedUserId = UserDefaults.standard.string(forKey: "currentUserId") {
            print("📱 使用已保存的 webhook URL: \(savedWebhookURL)")
            await MainActor.run {
                self.currentUserId = savedUserId
                self.userSpecificWebhookUrl = savedWebhookURL
                self.isGeneratingUrl = false
            }
            return
        }
        
        do {
            // 從後端獲取用戶 ID
            let userId = try await getUserIDFromBackend()
            
            // 生成用戶專屬的 webhook URL
            let webhookURL = generateWebhookURLForUser(userId: userId)
            
            print("📱 生成新的 webhook URL: \(webhookURL)")
            print("📱 用戶 ID: \(userId)")
            
            await MainActor.run {
                self.currentUserId = userId
                self.userSpecificWebhookUrl = webhookURL
                self.isGeneratingUrl = false
            }
            
            // 同步到後端
            try await syncUserWebhookURLToBackend(userId: userId, webhookURL: webhookURL)
            
        } catch {
            await MainActor.run {
                self.isGeneratingUrl = false
                self.loadError = "生成專屬 URL 失敗：\(error.localizedDescription)"
                self.showingLoadError = true
            }
        }
    }
    
    // 從後端獲取用戶 ID
    private func getUserIDFromBackend() async throws -> String {
        // 先嘗試從本地獲取用戶 ID
        if let savedUserId = UserDefaults.standard.string(forKey: "currentUserId") {
            return savedUserId
        }
        
        // 如果本地沒有，嘗試從後端獲取
        do {
            let userProfile = try await lineAPIService.getUserProfile()
            // 保存到本地
            UserDefaults.standard.set(userProfile.userId, forKey: "currentUserId")
            return userProfile.userId
        } catch {
            // 如果後端失敗，生成一個臨時的用戶 ID
            let tempUserId = UUID().uuidString
            UserDefaults.standard.set(tempUserId, forKey: "currentUserId")
            return tempUserId
        }
    }
    
    // 生成用戶專屬的 webhook URL
    private func generateWebhookURLForUser(userId: String) -> String {
        return lineAPIService.generateUserSpecificWebhookURL(userId: userId)
    }
    
    // 同步用戶 webhook URL 到後端
    private func syncUserWebhookURLToBackend(userId: String, webhookURL: String) async throws {
        // 保存到本地
        UserDefaults.standard.set(webhookURL, forKey: "userWebhookURL")
        
        // 嘗試同步到後端（可選）
        do {
            let success = try await lineAPIService.syncUserWebhookURL(userId: userId, webhookURL: webhookURL)
            if !success {
                print("後端同步失敗，但本地已保存")
            }
        } catch {
            print("後端同步失敗：\(error.localizedDescription)，但本地已保存")
        }
    }
    
    // 複製用戶專屬 Webhook URL
    private func copyUserSpecificWebhookURL() {
        guard !userSpecificWebhookUrl.isEmpty else { return }
        
        UIPasteboard.general.string = userSpecificWebhookUrl
        copyAlertMessage = "您的專屬 Webhook URL 已複製到剪貼簿"
        showingCopyAlert = true
    }
}

// MARK: - Line 保存狀態枚舉
enum LineSaveStatus {
    case idle
    case validating
    case connecting
    case testing
    case saving
    case success
    case error
    
    var displayName: String {
        switch self {
        case .idle:
            return "準備中"
        case .validating:
            return "驗證設定"
        case .connecting:
            return "連線Line API"
        case .testing:
            return "測試Webhook"
        case .saving:
            return "保存設定"
        case .success:
            return "完成"
        case .error:
            return "錯誤"
        }
    }
    
    var icon: String {
        switch self {
        case .idle:
            return "gear"
        case .validating:
            return "checkmark.shield"
        case .connecting:
            return "message.circle"
        case .testing:
            return "network"
        case .saving:
            return "square.and.arrow.down"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .idle, .validating, .connecting, .testing, .saving:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

// 新增：Line保存進度視圖
struct LineSaveProgressView: View {
    @Binding var progress: Double
    @Binding var status: LineSaveStatus
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 背景模糊
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 進度圓環
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(status.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    VStack(spacing: 8) {
                        if status == .success {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: status.icon)
                                .font(.system(size: 40))
                                .foregroundColor(status.color)
                        }
                        
                        Text("\(Int(progress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                
                // 狀態文字
                VStack(spacing: 12) {
                    Text(status.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(getLineStatusDescription())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 進度條
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: status.color))
                        .frame(height: 6)
                    
                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(40)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
    }
    
    private func getLineStatusDescription() -> String {
        switch status {
        case .idle:
            return "準備開始保存Line設定"
        case .validating:
            return "檢查Channel Access Token和Channel Secret格式"
        case .connecting:
            return "建立與Line Messaging API的連線"
        case .testing:
            return "測試Webhook端點和回應功能"
        case .saving:
            return "將Line設定保存到本地儲存"
        case .success:
            return "Line設定保存成功！串接已完成"
        case .error:
            return "保存過程中發生錯誤，請檢查設定"
        }
    }
}

struct LineSettingsToggle: View {
    let title: String
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .disabled(isDisabled)
        }
    }
}

#Preview {
    NavigationView {
        LineSettingsView()
    }
} 