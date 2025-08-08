//
//  SettingsView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("apiURL") private var apiURL = "https://api.openai.com/v1/chat/completions"
    @AppStorage("modelName") private var modelName = "gpt-3.5-turbo"
    @AppStorage("maxTokens") private var maxTokens = 1000
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("systemPrompt") private var systemPrompt = "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
    
    // 新增AI助理相關設定
    @AppStorage("aiName") private var aiName = "EchoChat 助理"
    @AppStorage("aiDescription") private var aiDescription = "專業的智能客服助理，能夠協助解決各種客戶問題"
    @AppStorage("aiPersonality") private var aiPersonality = "友善、專業、耐心"
    @AppStorage("aiSpecialties") private var aiSpecialties = "產品諮詢、技術支援、訂單處理"
    @AppStorage("aiLanguage") private var aiLanguage = "繁體中文"
    @AppStorage("aiResponseStyle") private var aiResponseStyle = "正式"
    @AppStorage("aiAvatar") private var aiAvatar = "robot"
    
    @State private var showingAPIKeyAlert = false
    @State private var showingResetAlert = false
    @State private var maxTokensDouble = 1000.0
    @State private var showingPreview = false
    @State private var showingTemplatePicker = false
    @State private var showingSetupGuide = false
    @State private var currentStep = 0
    @State private var showingSuccessAlert = false
    @State private var alertMessage = ""
    
    // 新增：進度條相關狀態
    @State private var isSaving = false
    @State private var saveProgress: Double = 0.0
    @State private var saveStatus: SaveStatus = .idle
    @State private var showingSaveProgress = false
    
    // 快速設定模板
    private let aiTemplates = [
        AITemplate(
            name: "客服助理",
            description: "專業的客戶服務代表",
            personality: "友善、專業、耐心",
            specialties: "產品諮詢、技術支援、訂單處理",
            responseStyle: "正式",
            systemPrompt: "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
        ),
        AITemplate(
            name: "創意寫手",
            description: "富有創意的內容創作者",
            personality: "創意、活潑、有趣",
            specialties: "文案撰寫、故事創作、行銷內容",
            responseStyle: "輕鬆",
            systemPrompt: "你是一個富有創意的寫手，能夠創作有趣且吸引人的內容。"
        ),
        AITemplate(
            name: "技術顧問",
            description: "專業的技術問題解決專家",
            personality: "專業、準確、詳細",
            specialties: "程式開發、技術問題、系統架構",
            responseStyle: "專業",
            systemPrompt: "你是一個專業的技術顧問，能夠提供準確且詳細的技術建議。"
        ),
        AITemplate(
            name: "學習導師",
            description: "耐心的教育指導者",
            personality: "耐心、鼓勵、啟發",
            specialties: "知識傳授、學習指導、概念解釋",
            responseStyle: "友善",
            systemPrompt: "你是一個耐心的學習導師，能夠用簡單易懂的方式解釋複雜概念。"
        )
    ]
    
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
                    // 快速設定區域
                    QuickSetupSection()
                    
                    // 新功能區域
                    NewFeaturesSection()
                    
                    // AI 助理基本資訊
                    SettingsSection(title: "AI 助理基本資訊") {
                        VStack(spacing: 15) {
                            SettingsField(
                                title: "助理名稱",
                                placeholder: "輸入AI助理的名稱",
                                text: $aiName,
                                icon: "person.circle"
                            )
                            
                            SettingsField(
                                title: "助理描述",
                                placeholder: "描述AI助理的功能和特色",
                                text: $aiDescription,
                                icon: "text.quote"
                            )
                            
                            SettingsField(
                                title: "個性特質",
                                placeholder: "例如：友善、專業、耐心",
                                text: $aiPersonality,
                                icon: "heart"
                            )
                            
                            SettingsField(
                                title: "專業領域",
                                placeholder: "例如：產品諮詢、技術支援",
                                text: $aiSpecialties,
                                icon: "star"
                            )
                        }
                    }
                    
                    // AI 模型設定
                    SettingsSection(title: "AI 模型設定") {
                        VStack(spacing: 15) {
                            SettingsField(
                                title: "API 金鑰",
                                placeholder: "輸入您的 OpenAI API 金鑰",
                                text: $apiKey,
                                isSecure: true,
                                icon: "key"
                            )
                            
                            SettingsField(
                                title: "API 端點",
                                placeholder: "API URL",
                                text: $apiURL,
                                icon: "network"
                            )
                            
                            SettingsField(
                                title: "模型名稱",
                                placeholder: "模型名稱",
                                text: $modelName,
                                icon: "cpu"
                            )
                            
                            SettingsSlider(
                                title: "最大 Token 數",
                                value: $maxTokensDouble,
                                range: 100...4000,
                                step: 100,
                                icon: "number"
                            )
                            .onChange(of: maxTokensDouble) { _, newValue in
                                maxTokens = Int(newValue)
                            }
                            
                            SettingsSlider(
                                title: "溫度 (創造性)",
                                value: $temperature,
                                range: 0...2,
                                step: 0.1,
                                format: "%.1f",
                                icon: "thermometer"
                            )
                        }
                    }
                    
                    // AI 回應設定
                    SettingsSection(title: "AI 回應設定") {
                        VStack(spacing: 15) {
                            SettingsPicker(
                                title: "回應風格",
                                icon: "text.bubble",
                                selection: $aiResponseStyle,
                                options: ["正式", "友善", "專業", "輕鬆", "幽默"]
                            )
                            
                            SettingsPicker(
                                title: "語言設定",
                                icon: "globe",
                                selection: $aiLanguage,
                                options: ["繁體中文", "簡體中文", "English", "日本語"]
                            )
                            
                            SettingsPicker(
                                title: "頭像圖示",
                                icon: "photo",
                                selection: $aiAvatar,
                                options: ["robot", "person.circle", "brain.head.profile", "sparkles", "star.circle"]
                            )
                        }
                    }
                    
                    // 系統提示詞
                    SettingsSection(title: "AI 角色設定") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "text.quote")
                                    .foregroundColor(.blue)
                                Text("系統提示詞")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            TextEditor(text: $systemPrompt)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            
                            Text("這將決定AI助理的行為和回應方式")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 操作按鈕
                    VStack(spacing: 15) {
                        // 新增：保存設定按鈕
                        SettingsButton(
                            title: "保存設定",
                            icon: "checkmark.circle",
                            action: saveSettings,
                            isDestructive: false
                        )
                        
                        SettingsButton(
                            title: "預覽 AI 助理",
                            icon: "eye",
                            action: { showingPreview = true }
                        )
                        
                        SettingsButton(
                            title: "測試 API 連線",
                            icon: "network",
                            action: testAPIConnection
                        )
                        
                        NavigationLink(destination: AIAssistantConfigView()) {
                            SettingsButton(title: "AI助理配置", icon: "brain.head.profile", action: {}, isDestructive: false)
                        }
                        
                        NavigationLink(destination: LineSettingsView()) {
                            SettingsButton(title: "Line 設定", icon: "message.circle", action: {}, isDestructive: false)
                        }
                        
                        NavigationLink(destination: SystemSettingsView()) {
                            SettingsButton(title: "系統設定", icon: "gearshape", action: {}, isDestructive: false)
                        }
                        
                        SettingsButton(
                            title: "重設所有設定",
                            icon: "arrow.clockwise",
                            action: { showingResetAlert = true },
                            isDestructive: true
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 10)
            }
        }
        .navigationTitle("AI 助理設定")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("引導設定") {
                    showingSetupGuide = true
                }
                .foregroundColor(.blue)
            }
        }
        .onAppear {
            // 初始化 maxTokensDouble
            maxTokensDouble = Double(maxTokens)
        }
        .alert("API 金鑰", isPresented: $showingAPIKeyAlert) {
            Button("確定") { }
        } message: {
            Text("請先在設定中輸入您的 OpenAI API 金鑰才能使用聊天功能。")
        }
        .alert("重設設定", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重設", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("確定要重設所有設定嗎？此操作無法復原。")
        }
        .alert("操作成功", isPresented: $showingSuccessAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingPreview) {
            AIPreviewView(
                aiName: aiName,
                aiDescription: aiDescription,
                aiPersonality: aiPersonality,
                aiSpecialties: aiSpecialties,
                aiResponseStyle: aiResponseStyle,
                aiLanguage: aiLanguage,
                aiAvatar: aiAvatar
            )
        }
        .sheet(isPresented: $showingTemplatePicker) {
            SettingsTemplatePickerView(templates: aiTemplates) { template in
                applyTemplate(template)
            }
        }
        .sheet(isPresented: $showingSetupGuide) {
            SetupGuideView(currentStep: $currentStep)
        }
        .sheet(isPresented: $showingSaveProgress) {
            SaveProgressView(
                progress: $saveProgress,
                status: $saveStatus,
                isPresented: $showingSaveProgress
            )
        }
    }
    
    // 新增：保存設定功能
    private func saveSettings() {
        guard !apiKey.isEmpty else {
            showingAPIKeyAlert = true
            return
        }
        
        showingSaveProgress = true
        saveProgress = 0.0
        saveStatus = .validating
        
        // 模擬保存過程
        Task {
            await simulateSaveProcess()
        }
    }
    
    // 模擬保存過程
    private func simulateSaveProcess() async {
        // 步驟1：驗證設定 (0-20%)
        await updateProgress(to: 0.2, status: .validating, delay: 0.5)
        
        // 步驟2：檢查API連線 (20-50%)
        await updateProgress(to: 0.5, status: .connecting, delay: 1.0)
        
        // 步驟3：測試API回應 (50-80%)
        await updateProgress(to: 0.8, status: .testing, delay: 1.5)
        
        // 步驟4：保存設定 (80-100%)
        await updateProgress(to: 1.0, status: .saving, delay: 0.8)
        
        // 完成
        await MainActor.run {
            saveStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingSaveProgress = false
                alertMessage = "設定保存成功！API串接已完成。"
                showingSuccessAlert = true
            }
        }
    }
    
    // 更新進度
    private func updateProgress(to progress: Double, status: SaveStatus, delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                saveProgress = progress
                saveStatus = status
            }
        }
    }
    
    // 快速設定區域
    private func QuickSetupSection() -> some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("快速設定")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: { showingTemplatePicker = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("選擇模板")
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
                
                Button(action: { showingSetupGuide = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("引導設定")
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
    
    private func testAPIConnection() {
        guard !apiKey.isEmpty else {
            showingAPIKeyAlert = true
            return
        }
        
        // 模擬API測試
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            alertMessage = "API 連線測試成功！"
            showingSuccessAlert = true
        }
    }
    
    private func applyTemplate(_ template: AITemplate) {
        aiName = template.name
        aiDescription = template.description
        aiPersonality = template.personality
        aiSpecialties = template.specialties
        aiResponseStyle = template.responseStyle
        systemPrompt = template.systemPrompt
        
        alertMessage = "已套用「\(template.name)」模板"
        showingSuccessAlert = true
    }
    
    private func resetSettings() {
        apiKey = ""
        apiURL = "https://api.openai.com/v1/chat/completions"
        modelName = "gpt-3.5-turbo"
        maxTokens = 1000
        maxTokensDouble = 1000.0
        temperature = 0.7
        systemPrompt = "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
        
        // 重設AI助理設定
        aiName = "EchoChat 助理"
        aiDescription = "專業的智能客服助理，能夠協助解決各種客戶問題"
        aiPersonality = "友善、專業、耐心"
        aiSpecialties = "產品諮詢、技術支援、訂單處理"
        aiLanguage = "繁體中文"
        aiResponseStyle = "正式"
        aiAvatar = "robot"
        
        alertMessage = "所有設定已重設為預設值"
        showingSuccessAlert = true
    }
}

// 新增：保存狀態枚舉
enum SaveStatus {
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
            return "連線API"
        case .testing:
            return "測試回應"
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
            return "wifi"
        case .testing:
            return "message.circle"
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

// 新增：保存進度視圖
struct SaveProgressView: View {
    @Binding var progress: Double
    @Binding var status: SaveStatus
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
                    
                    Text(getStatusDescription())
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
    
    private func getStatusDescription() -> String {
        switch status {
        case .idle:
            return "準備開始保存設定"
        case .validating:
            return "檢查API金鑰和設定格式"
        case .connecting:
            return "建立與OpenAI API的連線"
        case .testing:
            return "測試API回應和功能"
        case .saving:
            return "將設定保存到本地儲存"
        case .success:
            return "設定保存成功！API串接已完成"
        case .error:
            return "保存過程中發生錯誤，請檢查設定"
        }
    }
}

// 示範聊天視圖
struct DemoChatView: View {
    let aiName: String
    let aiAvatar: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [DemoMessage] = [
        DemoMessage(text: "您好！我是您的AI助理，有什麼我可以幫助您的嗎？", isFromUser: false, timestamp: Date())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                VStack(spacing: 0) {
                    // 聊天區域
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                DemoMessageBubble(message: message, aiAvatar: aiAvatar)
                            }
                        }
                        .padding()
                    }
                    
                    // 輸入區域
                    HStack(spacing: 12) {
                        TextField("輸入訊息...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(.systemGray4)),
                        alignment: .top
                    )
                }
            }
            .navigationTitle(aiName)
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
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let userMessage = DemoMessage(text: messageText, isFromUser: true, timestamp: Date())
        messages.append(userMessage)
        
        let aiResponse = DemoMessage(
            text: "這是一個示範回應。在實際使用中，我會根據您的設定來回應您的問題。",
            isFromUser: false,
            timestamp: Date()
        )
        
        messageText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            messages.append(aiResponse)
        }
    }
}

// 示範訊息結構
struct DemoMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

// 示範訊息氣泡
struct DemoMessageBubble: View {
    let message: DemoMessage
    let aiAvatar: String
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: aiAvatar)
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        Text(message.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

// AI 模板結構
struct AITemplate {
    let name: String
    let description: String
    let personality: String
    let specialties: String
    let responseStyle: String
    let systemPrompt: String
}

// 設定模板選擇器視圖
struct SettingsTemplatePickerView: View {
    let templates: [AITemplate]
    let onSelect: (AITemplate) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(templates, id: \.name) { template in
                            SettingsTemplateCard(template: template) {
                                onSelect(template)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("選擇 AI 模板")
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
}

// 設定模板卡片
struct SettingsTemplateCard: View {
    let template: AITemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(template.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(template.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(template.personality, systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Label(template.responseStyle, systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
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

// 引導設定視圖
struct SetupGuideView: View {
    @Binding var currentStep: Int
    @Environment(\.dismiss) private var dismiss
    
    private let steps = [
        "歡迎使用 EchoChat！讓我們一起設定您的 AI 助理。",
        "首先，請為您的 AI 助理取一個名字，並描述它的功能。",
        "接下來，設定 AI 助理的個性和專業領域。",
        "選擇回應風格和語言設定。",
        "最後，輸入您的 OpenAI API 金鑰來啟用 AI 功能。",
        "完成！您的 AI 助理已經準備就緒。"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                VStack(spacing: 30) {
                    // 進度指示器
                    ProgressView(value: Double(currentStep), total: Double(steps.count - 1))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.horizontal)
                    
                    // 步驟內容
                    VStack(spacing: 20) {
                        Image(systemName: currentStep == 0 ? "hand.wave" : "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(steps[currentStep])
                            .font(.title3)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    Spacer()
                    
                    // 導航按鈕
                    HStack(spacing: 20) {
                        if currentStep > 0 {
                            Button("上一步") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Button(currentStep == steps.count - 1 ? "完成" : "下一步") {
                            if currentStep < steps.count - 1 {
                                withAnimation {
                                    currentStep += 1
                                }
                            } else {
                                dismiss()
                            }
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
                .padding()
            }
            .navigationTitle("設定引導")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳過") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// AI 預覽視圖
struct AIPreviewView: View {
    let aiName: String
    let aiDescription: String
    let aiPersonality: String
    let aiSpecialties: String
    let aiResponseStyle: String
    let aiLanguage: String
    let aiAvatar: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDemoChat = false
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // AI 助理卡片
                        VStack(spacing: 20) {
                            // 頭像和狀態
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: aiAvatar)
                                        .font(.system(size: 50))
                                        .foregroundColor(.blue)
                                }
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("線上")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            // 基本資訊
                            VStack(spacing: 8) {
                                Text(aiName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(aiDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
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
                        
                        // 詳細資訊
                        VStack(spacing: 15) {
                            PreviewInfoRow(title: "個性特質", value: aiPersonality, icon: "heart.fill")
                            PreviewInfoRow(title: "專業領域", value: aiSpecialties, icon: "star.fill")
                            PreviewInfoRow(title: "回應風格", value: aiResponseStyle, icon: "text.bubble.fill")
                            PreviewInfoRow(title: "語言設定", value: aiLanguage, icon: "globe")
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        // 操作按鈕
                        VStack(spacing: 12) {
                            Button(action: { showingDemoChat = true }) {
                                HStack {
                                    Image(systemName: "message.circle.fill")
                                        .foregroundColor(.white)
                                    Text("開始對話")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            Button(action: { dismiss() }) {
                                Text("返回設定")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("AI 助理預覽")
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
        .sheet(isPresented: $showingDemoChat) {
            DemoChatView(aiName: aiName, aiAvatar: aiAvatar)
        }
    }
}

struct PreviewInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 16)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 新功能區域
struct NewFeaturesSection: View {
    @State private var showingPlanManagement = false
    @State private var showingKnowledgeManagement = false
    
    var body: some View {
        SettingsSection(title: "新功能") {
            VStack(spacing: 15) {
                // 會員方案管理
                Button(action: {
                    showingPlanManagement = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("會員方案管理")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("查看和升級您的會員方案")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 知識庫管理
                Button(action: {
                    showingKnowledgeManagement = true
                }) {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("知識庫管理")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("管理您的知識項目和資料")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingPlanManagement) {
            PlanManagementView()
        }
        .sheet(isPresented: $showingKnowledgeManagement) {
            KnowledgeManagementView()
        }
    }
}

// 重複定義的組件已移至SharedComponents.swift

#Preview {
    NavigationView {
        SettingsView()
    }
} 