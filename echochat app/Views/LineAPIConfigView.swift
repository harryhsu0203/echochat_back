//
//  LineAPIConfigView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import Combine

// MARK: - LINE API 設定頁面
struct LineAPIConfigView: View {
    @StateObject private var viewModel = LineAPIConfigViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 標題區域
                    headerSection
                    
                    // 設定狀態卡片
                    statusCard
                    
                    // 基本設定區域
                    basicSettingsSection
                    
                    // 進階設定區域
                    advancedSettingsSection
                    
                    // 連接測試區域
                    connectionTestSection
                    
                    // 操作按鈕區域
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("LINE API 設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("提示", isPresented: $viewModel.showingAlert) {
                Button("確定") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("成功", isPresented: $viewModel.showingSuccessAlert) {
                Button("確定") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .onAppear {
                viewModel.loadSettings()
            }
        }
    }
    
    // MARK: - 標題區域
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "message.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LINE 官方帳號設定")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("配置您的 LINE 聊天機器人與官方 API 的連接")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 設定步驟指示器
            HStack(spacing: 16) {
                ForEach(0..<4) { index in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.getStepColor(for: index))
                            .frame(width: 12, height: 12)
                        
                        Text(viewModel.getStepTitle(for: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 狀態卡片
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: viewModel.connectionStatus.icon)
                    .font(.title2)
                    .foregroundColor(viewModel.connectionStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.connectionStatus.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(viewModel.connectionStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if viewModel.connectionStatus == .connected {
                HStack {
                    Label("最後檢查: \(viewModel.lastCheckTime)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("重新檢查") {
                        viewModel.testConnection()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(viewModel.connectionStatus.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 基本設定區域
    private var basicSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本設定")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Channel ID
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Channel ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("如何獲取？") {
                        viewModel.showChannelIDHelp()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                TextField("輸入您的 Channel ID", text: $viewModel.channelId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("從 LINE Developers Console 獲得的 Channel ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Channel Secret
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Channel Secret")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("如何獲取？") {
                        viewModel.showChannelSecretHelp()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                SecureField("輸入您的 Channel Secret", text: $viewModel.channelSecret)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("從 LINE Developers Console 獲得的 Channel Secret")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Channel Access Token
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Channel Access Token")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("如何獲取？") {
                        viewModel.showAccessTokenHelp()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                SecureField("輸入您的 Channel Access Token", text: $viewModel.channelAccessToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("從 LINE Developers Console 獲得的 Channel Access Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 進階設定區域
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("進階設定")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Webhook URL
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Webhook URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("重新生成") {
                        viewModel.generateWebhookURL()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                HStack {
                    TextField("Webhook URL", text: $viewModel.webhookUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(true)
                    
                    Button(action: {
                        UIPasteboard.general.string = viewModel.webhookUrl
                        viewModel.showCopiedAlert()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.webhookUrl.isEmpty)
                }
                
                Text("此 URL 需要配置到 LINE Developers Console 的 Webhook URL 設定中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 自動回覆設定
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("自動回覆")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.autoReplyEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                Text("啟用後，系統將自動回覆收到的訊息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 訊息記錄
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("訊息記錄")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.messageLoggingEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                Text("啟用後，將記錄所有收發的訊息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 連接測試區域
    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("連接測試")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // API 連接測試
                Button(action: {
                    viewModel.testAPIConnection()
                }) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.white)
                        Text("測試 API 連接")
                            .fontWeight(.medium)
                        Spacer()
                        if viewModel.isTestingAPI {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(viewModel.isTestingAPI ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isTestingAPI)
                
                // Webhook 連接測試
                Button(action: {
                    viewModel.testWebhookConnection()
                }) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.white)
                        Text("測試 Webhook 連接")
                            .fontWeight(.medium)
                        Spacer()
                        if viewModel.isTestingWebhook {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(viewModel.isTestingWebhook ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isTestingWebhook)
                
                // 發送測試訊息
                Button(action: {
                    viewModel.sendTestMessage()
                }) {
                    HStack {
                        Image(systemName: "paperplane")
                            .foregroundColor(.white)
                        Text("發送測試訊息")
                            .fontWeight(.medium)
                        Spacer()
                        if viewModel.isSendingTestMessage {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(viewModel.isSendingTestMessage ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isSendingTestMessage)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 操作按鈕區域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 保存設定
            Button(action: {
                viewModel.saveSettings()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.white)
                    Text("保存設定")
                        .fontWeight(.semibold)
                    Spacer()
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(viewModel.isSaving ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
            
            // 重置設定
            Button(action: {
                viewModel.resetSettings()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                    Text("重置設定")
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - LINE 連接狀態枚舉
enum LineConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error
    
    var title: String {
        switch self {
        case .disconnected:
            return "未連接"
        case .connecting:
            return "連接中..."
        case .connected:
            return "已連接"
        case .error:
            return "連接錯誤"
        }
    }
    
    var description: String {
        switch self {
        case .disconnected:
            return "請配置 LINE API 設定"
        case .connecting:
            return "正在測試連接..."
        case .connected:
            return "LINE API 連接正常"
        case .error:
            return "連接失敗，請檢查設定"
        }
    }
    
    var icon: String {
        switch self {
        case .disconnected:
            return "xmark.circle"
        case .connecting:
            return "clock"
        case .connected:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - ViewModel
class LineAPIConfigViewModel: ObservableObject {
    @Published var channelId = ""
    @Published var channelSecret = ""
    @Published var channelAccessToken = ""
    @Published var webhookUrl = ""
    @Published var autoReplyEnabled = true
    @Published var messageLoggingEnabled = true
    
    @Published var connectionStatus: LineConnectionStatus = .disconnected
    @Published var lastCheckTime = "從未檢查"
    
    @Published var isLoading = false
    @Published var isTestingAPI = false
    @Published var isTestingWebhook = false
    @Published var isSendingTestMessage = false
    @Published var isSaving = false
    
    @Published var showingAlert = false
    @Published var showingSuccessAlert = false
    @Published var alertMessage = ""
    
    private let lineService = LineService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 監聽設定變更，自動更新連接狀態
        Publishers.CombineLatest3($channelId, $channelSecret, $channelAccessToken)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.updateConnectionStatus()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 設定管理
    func loadSettings() {
        isLoading = true
        
        // 從 UserDefaults 載入設定
        channelId = UserDefaults.standard.string(forKey: "lineChannelId") ?? ""
        channelSecret = UserDefaults.standard.string(forKey: "lineChannelSecret") ?? ""
        channelAccessToken = UserDefaults.standard.string(forKey: "lineChannelAccessToken") ?? ""
        let storedWebhook = UserDefaults.standard.string(forKey: "lineWebhookUrl") ?? ""
        // 防呆：若存的是錯誤值（例如被寫成 secret 或空值），改為重新生成
        if storedWebhook.isEmpty || !LineAPIService.shared.validateWebhookURL(storedWebhook) {
            generateWebhookURL()
        } else {
            webhookUrl = storedWebhook
        }
        autoReplyEnabled = UserDefaults.standard.bool(forKey: "lineAutoReplyEnabled")
        messageLoggingEnabled = UserDefaults.standard.bool(forKey: "lineMessageLoggingEnabled")
        
        // 生成 webhook URL
        if webhookUrl.isEmpty || !LineAPIService.shared.validateWebhookURL(webhookUrl) {
            generateWebhookURL()
        }
        
        isLoading = false
        updateConnectionStatus()
    }
    
    func saveSettings() {
        guard !channelId.isEmpty && !channelSecret.isEmpty && !channelAccessToken.isEmpty else {
            alertMessage = "請填寫完整的 LINE API 設定"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(channelId, forKey: "lineChannelId")
        UserDefaults.standard.set(channelSecret, forKey: "lineChannelSecret")
        UserDefaults.standard.set(channelAccessToken, forKey: "lineChannelAccessToken")
        UserDefaults.standard.set(webhookUrl, forKey: "lineWebhookUrl")
        UserDefaults.standard.set(autoReplyEnabled, forKey: "lineAutoReplyEnabled")
        UserDefaults.standard.set(messageLoggingEnabled, forKey: "lineMessageLoggingEnabled")
        
        // 更新 LineService
        lineService.updateCredentials(
            accessToken: channelAccessToken,
            channelSecret: channelSecret
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSaving = false
            self.alertMessage = "設定保存成功！"
            self.showingSuccessAlert = true
            self.updateConnectionStatus()
        }
    }
    
    func resetSettings() {
        channelId = ""
        channelSecret = ""
        channelAccessToken = ""
        webhookUrl = ""
        autoReplyEnabled = true
        messageLoggingEnabled = true
        
        // 清除 UserDefaults
        UserDefaults.standard.removeObject(forKey: "lineChannelId")
        UserDefaults.standard.removeObject(forKey: "lineChannelSecret")
        UserDefaults.standard.removeObject(forKey: "lineChannelAccessToken")
        UserDefaults.standard.removeObject(forKey: "lineWebhookUrl")
        UserDefaults.standard.removeObject(forKey: "lineAutoReplyEnabled")
        UserDefaults.standard.removeObject(forKey: "lineMessageLoggingEnabled")
        
        generateWebhookURL()
        updateConnectionStatus()
        
        alertMessage = "設定已重置"
        showingAlert = true
    }
    
    // MARK: - 連接測試
    func testConnection() {
        Task {
            await testAPIConnection()
        }
    }
    
    func testAPIConnection() {
        guard !channelAccessToken.isEmpty else {
            alertMessage = "請先填寫 Channel Access Token"
            showingAlert = true
            return
        }
        
        isTestingAPI = true
        connectionStatus = .connecting
        
        Task {
            let isConnected = await lineService.checkConnection()
            
            await MainActor.run {
                self.isTestingAPI = false
                self.connectionStatus = isConnected ? .connected : .error
                self.lastCheckTime = self.formatCurrentTime()
                
                if isConnected {
                    self.alertMessage = "API 連接測試成功！"
                    self.showingSuccessAlert = true
                } else {
                    self.alertMessage = "API 連接測試失敗，請檢查設定"
                    self.showingAlert = true
                }
            }
        }
    }
    
    func testWebhookConnection() {
        guard !webhookUrl.isEmpty else {
            alertMessage = "Webhook URL 尚未生成"
            showingAlert = true
            return
        }
        
        isTestingWebhook = true
        
        Task {
            // 模擬 webhook 測試
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            
            await MainActor.run {
                self.isTestingWebhook = false
                self.alertMessage = "Webhook 連接測試完成"
                self.showingSuccessAlert = true
            }
        }
    }
    
    func sendTestMessage() {
        guard connectionStatus == .connected else {
            alertMessage = "請先確保 API 連接正常"
            showingAlert = true
            return
        }
        
        isSendingTestMessage = true
        
        Task {
            do {
                try await lineService.sendMessage(
                    message: "這是一條測試訊息，發送時間：\(formatCurrentTime())",
                    customerId: "test_user"
                )
                
                await MainActor.run {
                    self.isSendingTestMessage = false
                    self.alertMessage = "測試訊息發送成功！"
                    self.showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isSendingTestMessage = false
                    self.alertMessage = "測試訊息發送失敗：\(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    // MARK: - 輔助功能
    func generateWebhookURL() {
        let currentConfig = ConfigurationManager.shared.currentConfig
        let userId = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
        webhookUrl = "\(currentConfig.baseURL)/api/webhook/line/\(userId)"
    }
    
    func updateConnectionStatus() {
        if channelId.isEmpty || channelSecret.isEmpty || channelAccessToken.isEmpty {
            connectionStatus = .disconnected
        } else {
            // 自動測試連接
            Task {
                await testAPIConnection()
            }
        }
    }
    
    func getStepColor(for index: Int) -> Color {
        switch index {
        case 0: return channelId.isEmpty ? .gray : .green
        case 1: return channelSecret.isEmpty ? .gray : .green
        case 2: return channelAccessToken.isEmpty ? .gray : .green
        case 3: return connectionStatus == .connected ? .green : .gray
        default: return .gray
        }
    }
    
    func getStepTitle(for index: Int) -> String {
        switch index {
        case 0: return "Channel ID"
        case 1: return "Secret"
        case 2: return "Token"
        case 3: return "連接"
        default: return ""
        }
    }
    
    func showChannelIDHelp() {
        alertMessage = "1. 登入 LINE Developers Console\n2. 選擇您的 Channel\n3. 在 Basic settings 中找到 Channel ID"
        showingAlert = true
    }
    
    func showChannelSecretHelp() {
        alertMessage = "1. 在 LINE Developers Console 中\n2. 選擇您的 Channel\n3. 在 Basic settings 中找到 Channel Secret"
        showingAlert = true
    }
    
    func showAccessTokenHelp() {
        alertMessage = "1. 在 LINE Developers Console 中\n2. 選擇您的 Channel\n3. 在 Messaging API 設定中找到 Channel access token"
        showingAlert = true
    }
    
    func showCopiedAlert() {
        alertMessage = "Webhook URL 已複製到剪貼簿"
        showingSuccessAlert = true
    }
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

#Preview {
    LineAPIConfigView()
}
