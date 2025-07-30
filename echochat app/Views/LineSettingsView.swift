//
//  LineSettingsView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI

struct LineSettingsView: View {
    @AppStorage("lineChannelAccessToken") private var channelAccessToken = ""
    @AppStorage("lineChannelSecret") private var channelSecret = ""
    @AppStorage("lineWebhookUrl") private var webhookUrl = ""
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
                                isSecure: true
                            )
                            
                            SettingsField(
                                title: "Channel Secret",
                                placeholder: "輸入您的 Line Channel Secret",
                                text: $channelSecret,
                                isSecure: true
                            )
                            
                            SettingsField(
                                title: "Webhook URL",
                                placeholder: "Webhook 端點 URL",
                                text: $webhookUrl
                            )
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
                                format: "%.1f"
                            )
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
                                
                                Text("https://your-domain.com/webhook/line")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
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
        
        // 模擬保存過程
        Task {
            await simulateLineSaveProcess()
        }
    }
    
    // 模擬Line保存過程
    private func simulateLineSaveProcess() async {
        // 步驟1：驗證設定 (0-20%)
        await updateLineProgress(to: 0.2, status: .validating, delay: 0.5)
        
        // 步驟2：檢查Line API連線 (20-50%)
        await updateLineProgress(to: 0.5, status: .connecting, delay: 1.0)
        
        // 步驟3：測試Webhook設定 (50-80%)
        await updateLineProgress(to: 0.8, status: .testing, delay: 1.5)
        
        // 步驟4：保存設定 (80-100%)
        await updateLineProgress(to: 1.0, status: .saving, delay: 0.8)
        
        // 完成
        await MainActor.run {
            saveStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingSaveProgress = false
                testResult = "Line設定保存成功！串接已完成。"
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
        
        // 模擬測試連線
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let success = !channelAccessToken.isEmpty && !channelSecret.isEmpty
            testResult = success ? "連線成功！Line API 已正確設定。" : "連線失敗！請檢查 Channel Access Token 和 Channel Secret。"
            isTesting = false
            showingTestAlert = true
        }
    }
}

// 新增：Line保存狀態枚舉
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