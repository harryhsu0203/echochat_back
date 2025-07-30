//
//  ChannelManagementView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct ChannelManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @State private var showingAddChannel = false
    @State private var selectedChannel: Channel?
    @State private var showingDeleteAlert = false
    @State private var channelToDelete: Channel?
    
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("新增頻道") {
                    showingAddChannel = true
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingAddChannel) {
            AddChannelView()
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
                QuickActionCard(
                    title: "Line",
                    icon: "message.circle.fill",
                    color: .green,
                    action: { showingAddChannel = true }
                )
                
                QuickActionCard(
                    title: "Instagram",
                    icon: "camera.circle.fill",
                    color: .purple,
                    action: { showingAddChannel = true }
                )
                
                QuickActionCard(
                    title: "WhatsApp",
                    icon: "phone.circle.fill",
                    color: .green,
                    action: { showingAddChannel = true }
                )
                
                QuickActionCard(
                    title: "Facebook",
                    icon: "person.2.circle.fill",
                    color: .blue,
                    action: { showingAddChannel = true }
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
                
                Text("\(Channel.sampleChannels.count) 個頻道")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if Channel.sampleChannels.isEmpty {
                EmptyChannelsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Channel.sampleChannels, id: \.id) { channel in
                        ChannelCard(channel: channel) {
                            selectedChannel = channel
                        } onDelete: {
                            channelToDelete = channel
                            showingDeleteAlert = true
                        }
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
                    value: "\(Channel.sampleChannels.reduce(0) { $0 + $1.totalMessages })",
                    icon: "message.fill",
                    color: .blue
                )
                
                ChannelStatCard(
                    title: "活躍頻道",
                    value: "\(Channel.sampleChannels.filter { $0.isActive }.count)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .green
                )
                
                ChannelStatCard(
                    title: "今日訊息",
                    value: "\(Channel.sampleChannels.reduce(0) { $0 + $1.todayMessages })",
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
    }
    
    private func deleteChannel(_ channel: Channel) {
        // 刪除頻道邏輯
    }
}



// 快速操作卡片
struct QuickActionCard: View {
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
                        
                        // 狀態指示器
                        Circle()
                            .fill(channel.isActive ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
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
    
    // 輸入值管理
    @State private var channelSecret: String = ""
    @State private var channelAccessToken: String = ""
    @State private var inputValues: [String] = ["", ""] // 對應Channel Secret和Channel Access Token
    
    // LINE設置步驟數據
    @State private var lineSetupSteps = [
        StepData(
            number: 1,
            title: "建立訊息 Message API Channel",
            description: "在LINE Developers Console中創建新的Message API Channel",
            icon: "plus.circle.fill",
            isCompleted: false,
            isExpanded: true,
            instructions: [
                "使用管理員帳號登入LINE 開發者控制台。",
                "選擇或創建Provider > 選擇Admin並選擇\"Message API Channel\"或\"Create a new Channel\"與選擇\"Message API Channel\"。",
                "填寫頻道名稱等基本資料。",
                "同意條款和條件後，點選\"建立\"按鈕。"
            ]
        ),
        StepData(
            number: 2,
            title: "設定頻道秘密和頻道存取令牌",
            description: "獲取Channel Secret和Channel Access Token",
            icon: "key.fill",
            isCompleted: false,
            isExpanded: false,
            instructions: [
                "進入頻道設定頁面。",
                "複製Channel Secret並妥善保存。",
                "生成Channel Access Token。",
                "保存這些重要資訊，不要分享給他人。"
            ],
            hasInputFields: true,
            inputFields: [
                InputField(label: "Channel Secret", placeholder: "請輸入Channel Secret"),
                InputField(label: "Channel Access Token", placeholder: "請輸入Channel Access Token")
            ]
        ),
        StepData(
            number: 3,
            title: "設定 Webhook URL",
            description: "配置Webhook URL以接收LINE消息",
            icon: "link",
            isCompleted: false,
            isExpanded: false,
            instructions: [
                "在LINE Developers Console中進入Webhook設定。",
                "設定Webhook URL（必須是HTTPS）。",
                "啟用Webhook功能。",
                "測試Webhook連接。"
            ],
            hasInputFields: true,
            inputFields: [
                InputField(label: "Webhook URL", placeholder: "請輸入Webhook URL (必須是HTTPS)")
            ]
        ),
        StepData(
            number: 4,
            title: "LINE 官方帳號設置",
            description: "設置LINE官方帳號的基本資訊",
            icon: "person.circle.fill",
            isCompleted: false,
            isExpanded: false,
            instructions: [
                "設置官方帳號名稱。",
                "上傳帳號頭像。",
                "設定帳號描述。",
                "配置回應設定。"
            ],
            hasInputFields: true,
            inputFields: [
                InputField(label: "官方帳號名稱", placeholder: "請輸入官方帳號名稱"),
                InputField(label: "帳號描述", placeholder: "請輸入帳號描述")
            ]
        ),
        StepData(
            number: 5,
            title: "連接LINE 官方帳號",
            description: "將Message API Channel與官方帳號連接",
            icon: "link.circle.fill",
            isCompleted: false,
            isExpanded: false,
            instructions: [
                "在LINE Developers中連接官方帳號。",
                "掃描QR碼或輸入帳號。",
                "確認連接狀態。",
                "測試消息發送功能。"
            ]
        ),
        StepData(
            number: 6,
            title: "頻道特定語言設定",
            description: "設定頻道的語言和地區設定",
            icon: "globe",
            isCompleted: false,
            isExpanded: false,
            instructions: [
                "選擇主要語言。",
                "設定地區選項。",
                "配置時區設定。",
                "保存語言設定。"
            ],
            hasInputFields: true,
            inputFields: [
                InputField(label: "主要語言", placeholder: "請選擇主要語言"),
                InputField(label: "時區設定", placeholder: "請選擇時區")
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 標題區域
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "message.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.warmAccent)
                                
                                Text("LINE API設定")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.primaryText)
                                
                                Spacer()
                            }
                            
                            Text("請按照以下步驟完成LINE Message API的設定")
                                .font(.subheadline)
                                .foregroundColor(Color.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 步驟列表
                        VStack(spacing: 12) {
                            ForEach(Array(lineSetupSteps.enumerated()), id: \.element.number) { index, step in
                                ExpandableStepCard(
                                    step: step,
                                    isExpanded: Binding(
                                        get: { lineSetupSteps[index].isExpanded },
                                        set: { lineSetupSteps[index].isExpanded = $0 }
                                    ),
                                    isCompleted: Binding(
                                        get: { lineSetupSteps[index].isCompleted },
                                        set: { lineSetupSteps[index].isCompleted = $0 }
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
                                completeSetup()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.warmAccent)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("LINE API設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color.warmAccent)
                }
            }

        }
    }
    
    private func handleNextStep(currentIndex: Int) {
        // 根據步驟保存相應的數據
        if lineSetupSteps[currentIndex].hasInputFields {
            saveStepData(currentIndex: currentIndex)
        }
        
        // 延遲一下讓動畫完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                // 收起當前步驟
                lineSetupSteps[currentIndex].isExpanded = false
                
                // 如果有下一個步驟，展開它
                if currentIndex + 1 < lineSetupSteps.count {
                    lineSetupSteps[currentIndex + 1].isExpanded = true
                }
            }
        }
    }
    
    private func saveStepData(currentIndex: Int) {
        // 確保輸入值數組有足夠的元素
        while inputValues.count < 2 {
            inputValues.append("")
        }
        
        switch currentIndex {
        case 1: // 第二步驟：Channel Secret和Channel Access Token
            channelSecret = inputValues[0]
            channelAccessToken = inputValues[1]
            print("✅ LINE Step 2: Channel credentials saved!")
            print("Channel Secret: \(channelSecret)")
            print("Channel Access Token: \(channelAccessToken)")
            
        case 2: // 第三步驟：Webhook URL
            let webhookUrl = inputValues[0]
            print("✅ LINE Step 3: Webhook URL saved!")
            print("Webhook URL: \(webhookUrl)")
            
        case 3: // 第四步驟：官方帳號設置
            let accountName = inputValues[0]
            let accountDescription = inputValues[1]
            print("✅ LINE Step 4: Official account settings saved!")
            print("Account Name: \(accountName)")
            print("Account Description: \(accountDescription)")
            
        case 5: // 第六步驟：語言設定
            let primaryLanguage = inputValues[0]
            let timezone = inputValues[1]
            print("✅ LINE Step 6: Language settings saved!")
            print("Primary Language: \(primaryLanguage)")
            print("Timezone: \(timezone)")
            
        default:
            print("✅ LINE Step \(currentIndex + 1) completed!")
        }
        
        // 如果是最後一步，創建並保存Channel
        if currentIndex == lineSetupSteps.count - 1 {
            saveChannelToDatabase()
        }
    }
    
    private func saveChannelToDatabase() {
        // 創建新的Channel實例並保存到數據庫
        let newChannel = Channel(
            name: "LINE Channel",
            platform: "LINE",
            userId: "current_user" // 這裡應該使用實際的用戶ID
        )
        
        // 設定Channel的憑證
        newChannel.apiKey = channelAccessToken
        newChannel.channelSecret = channelSecret
        newChannel.isActive = true
        
        modelContext.insert(newChannel)
        
        do {
            try modelContext.save()
            print("✅ LINE Channel saved to database successfully!")
        } catch {
            print("❌ Error saving LINE channel to database: \(error)")
        }
    }
    

    
    private func completeSetup() {
        // 完成設置的邏輯
        dismiss()
    }
}

// 輸入欄位結構
struct InputField {
    let label: String
    let placeholder: String
    var value: String = ""
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
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.primaryText)
                    
                    TextField(field.placeholder, text: Binding(
                        get: { inputValues.indices.contains(index) ? inputValues[index] : "" },
                        set: { newValue in
                            if inputValues.indices.contains(index) {
                                inputValues[index] = newValue
                            } else {
                                inputValues.append(newValue)
                            }
                        }
                    ))
                    .textFieldStyle(CustomTextFieldStyle())
                }
            }
        }
        .padding(.horizontal, 16)
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
                        Text("請複製Message API Channel中的Channel Secret和Channel Access Token並將其貼到以下欄位中。")
                            .font(.subheadline)
                            .foregroundColor(Color.primaryText)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                            .padding(.horizontal, 16)
                        
                        InputFieldsView(fields: step.inputFields, inputValues: $inputValues)
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
                            
                            Button("測試連接") {
                                // 測試連接邏輯
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
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
        // 保存變更邏輯
        dismiss()
    }
}

#Preview {
    ChannelManagementView()
        .modelContainer(for: Channel.self, inMemory: true)
} 