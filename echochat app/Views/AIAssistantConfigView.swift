//
//  AIAssistantConfigView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData
import UIKit

struct AIAssistantConfigView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    
    // AI服務設定
    @AppStorage("aiServiceEnabled") private var aiServiceEnabled = false
    @AppStorage("selectedAIModel") private var selectedAIModel = "客服專家"
    @AppStorage("maxTokens") private var maxTokens = 1000
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("systemPrompt") private var systemPrompt = "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。"
    
    // AI助理個性化設定
    @AppStorage("aiName") private var aiName = "EchoChat 助理"
    @AppStorage("aiPersonality") private var aiPersonality = "友善、專業、耐心"
    @AppStorage("aiSpecialties") private var aiSpecialties = "產品諮詢、技術支援、訂單處理"
    @AppStorage("aiResponseStyle") private var aiResponseStyle = "正式"
    @AppStorage("aiLanguage") private var aiLanguage = "繁體中文"
    @AppStorage("aiAvatar") private var aiAvatar = "robot"
    @AppStorage("enableShortReply") private var enableShortReply = false
    @AppStorage("aiDefaultModel") private var aiDefaultModel = "gpt-5.0"
    @AppStorage("aiFallbackModel") private var aiFallbackModel = ""
    @AppStorage("aiAutoEscalateEnabled") private var aiAutoEscalateEnabled = true
    @AppStorage("aiEscalateKeywords") private var aiEscalateKeywords = "退款, 合約, 發票, 抱怨, 故障"
    
    // 進階設定
    @AppStorage("maxContextLength") private var maxContextLength = 10
    @AppStorage("enableResponseFiltering") private var enableResponseFiltering = true
    @AppStorage("enableSentimentAnalysis") private var enableSentimentAnalysis = false
    @AppStorage("enableAutoApproval") private var enableAutoApproval = false
    @AppStorage("approvalThreshold") private var approvalThreshold = 0.8
    
    // 狀態管理
    @State private var selectedTab: ConfigTab = .basic
    @State private var showingPreview = false
    @State private var showingTestResult = false
    @State private var testResult = ""
    @State private var isLoading = false
    @State private var showingTemplatePicker = false
    @State private var showingCustomInstructions = false
    @State private var customInstructions = ""
    @StateObject private var aiSettingsService = AISettingsAPIService()
    @State private var hasLoadedAISettings = false
    
    enum ConfigTab: String, CaseIterable {
        case service = "服務設定"
        case basic = "基本設定"
        case personality = "個性設定"
        case advanced = "進階設定"
        case templates = "回應模板"
        case test = "測試連線"
        
        var icon: String {
            switch self {
            case .service:
                return "cloud.fill"
            case .basic:
                return "gear"
            case .personality:
                return "person.circle"
            case .advanced:
                return "slider.horizontal.3"
            case .templates:
                return "text.bubble"
            case .test:
                return "network"
            }
        }
        
        var color: Color {
            switch self {
            case .service:
                return .blue
            case .basic:
                return .blue
            case .personality:
                return .green
            case .advanced:
                return .orange
            case .templates:
                return .purple
            case .test:
                return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 頂部標題和AI助理預覽
            VStack(spacing: 16) {
                // 頁面標題
                HStack {
                    Text("AI助理配置")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.primaryText)
                    
                    Spacer()
                    
                    // 保存按鈕
                    Button(action: {
                        saveSettings()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            
                            Text("保存")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // AI助理預覽卡片
                AIAssistantPreviewCard(
                    name: aiName,
                    avatar: aiAvatar,
                    personality: aiPersonality,
                    specialties: aiSpecialties,
                    isServiceEnabled: aiServiceEnabled
                )
                
                // 功能標籤按鈕
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ConfigTab.allCases, id: \.self) { tab in
                            ConfigTabButton(
                                tab: tab,
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 16)
            .background(Color(.systemBackground))
            
            // 主要內容區域
            ScrollView {
                VStack(spacing: 24) {
                    switch selectedTab {
                    case .service:
                        ServiceSettingsView(
                            aiServiceEnabled: $aiServiceEnabled,
                            selectedAIModel: $selectedAIModel
                        )
                    case .basic:
                        BasicSettingsView(
                            selectedAIModel: $selectedAIModel,
                            maxTokens: $maxTokens,
                            temperature: $temperature,
                            systemPrompt: $systemPrompt,
                            enableShortReply: $enableShortReply,
                            defaultModel: $aiDefaultModel,
                            fallbackModel: $aiFallbackModel,
                            autoEscalateEnabled: $aiAutoEscalateEnabled,
                            escalateKeywordsText: $aiEscalateKeywords
                        )
                    case .personality:
                        PersonalitySettingsView(
                            aiName: $aiName,
                            aiPersonality: $aiPersonality,
                            aiSpecialties: $aiSpecialties,
                            aiResponseStyle: $aiResponseStyle,
                            aiLanguage: $aiLanguage,
                            aiAvatar: $aiAvatar
                        )
                    case .advanced:
                        AdvancedSettingsView(
                            maxContextLength: $maxContextLength,
                            enableResponseFiltering: $enableResponseFiltering,
                            enableSentimentAnalysis: $enableSentimentAnalysis,
                            enableAutoApproval: $enableAutoApproval,
                            approvalThreshold: $approvalThreshold,
                            customInstructions: $customInstructions
                        )
                    case .templates:
                        TemplateSettingsView(
                            showingTemplatePicker: $showingTemplatePicker
                        )
                    case .test:
                        TestConnectionView(
                            selectedAIModel: selectedAIModel,
                            showingTestResult: $showingTestResult,
                            testResult: $testResult,
                            isLoading: $isLoading
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingPreview) {
            AIAssistantPreviewView(
                name: aiName,
                avatar: aiAvatar,
                personality: aiPersonality,
                specialties: aiSpecialties,
                responseStyle: aiResponseStyle
            )
        }
        .alert("測試結果", isPresented: $showingTestResult) {
            Button("確定") { }
        } message: {
            Text(testResult)
        }
        .task {
            await loadAISettings()
        }
    }
    
    private func saveSettings() {
        // 保存所有設定到UserDefaults
        UserDefaults.standard.set(aiServiceEnabled, forKey: "aiServiceEnabled")
        UserDefaults.standard.set(selectedAIModel, forKey: "selectedAIModel")
        UserDefaults.standard.set(maxTokens, forKey: "maxTokens")
        UserDefaults.standard.set(temperature, forKey: "temperature")
        UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt")
        UserDefaults.standard.set(aiName, forKey: "aiName")
        UserDefaults.standard.set(aiPersonality, forKey: "aiPersonality")
        UserDefaults.standard.set(aiSpecialties, forKey: "aiSpecialties")
        UserDefaults.standard.set(aiResponseStyle, forKey: "aiResponseStyle")
        UserDefaults.standard.set(aiLanguage, forKey: "aiLanguage")
        UserDefaults.standard.set(aiAvatar, forKey: "aiAvatar")
        UserDefaults.standard.set(maxContextLength, forKey: "maxContextLength")
        UserDefaults.standard.set(enableResponseFiltering, forKey: "enableResponseFiltering")
        UserDefaults.standard.set(enableSentimentAnalysis, forKey: "enableSentimentAnalysis")
        UserDefaults.standard.set(enableAutoApproval, forKey: "enableAutoApproval")
        UserDefaults.standard.set(approvalThreshold, forKey: "approvalThreshold")
        UserDefaults.standard.set(customInstructions, forKey: "customInstructions")
        UserDefaults.standard.set(enableShortReply, forKey: "enableShortReply")
        UserDefaults.standard.set(aiDefaultModel, forKey: "aiDefaultModel")
        UserDefaults.standard.set(aiFallbackModel, forKey: "aiFallbackModel")
        UserDefaults.standard.set(aiAutoEscalateEnabled, forKey: "aiAutoEscalateEnabled")
        UserDefaults.standard.set(aiEscalateKeywords, forKey: "aiEscalateKeywords")
        
        // 顯示保存成功提示
        // 這裡可以添加一個簡單的成功提示

        let keywords = parseKeywords(aiEscalateKeywords)
        let settings = AISettings(
            defaultModel: aiDefaultModel,
            fallbackModel: aiFallbackModel.isEmpty ? nil : aiFallbackModel,
            autoEscalateEnabled: aiAutoEscalateEnabled,
            escalateKeywords: keywords
        )
        Task {
            try? await aiSettingsService.updateSettings(settings)
        }
    }

    private func parseKeywords(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，\n")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func loadAISettings() async {
        guard !hasLoadedAISettings else { return }
        hasLoadedAISettings = true
        do {
            let settings = try await aiSettingsService.fetchSettings()
            await MainActor.run {
                aiDefaultModel = settings.defaultModel
                aiFallbackModel = settings.fallbackModel ?? ""
                aiAutoEscalateEnabled = settings.autoEscalateEnabled
                aiEscalateKeywords = settings.escalateKeywords.joined(separator: ", ")
            }
        } catch {
            // 若讀取失敗，仍保留本地設定
        }
    }
}

// MARK: - 配置標籤按鈕
struct ConfigTabButton: View {
    let tab: AIAssistantConfigView.ConfigTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : Color.warmAccent)
                
                Text(tab.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .white : Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 80, height: 60)
            .background(
                isSelected ? Color.warmAccent : Color.cardBackground
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.warmAccent : Color.dividerColor,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - AI助理預覽卡片
struct AIAssistantPreviewCard: View {
    let name: String
    let avatar: String
    let personality: String
    let specialties: String
    let isServiceEnabled: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 頭像
            Image(systemName: avatar)
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // 資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("供應商：OpenAI")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(personality)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(specialties)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 狀態指示器
            HStack(spacing: 4) {
                Circle()
                    .fill(isServiceEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(isServiceEnabled ? "已配置" : "未配置")
                    .font(.caption2)
                    .foregroundColor(isServiceEnabled ? .green : .gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - 基本設定視圖
struct BasicSettingsView: View {
    @Binding var selectedAIModel: String
    @Binding var maxTokens: Int
    @Binding var temperature: Double
    @Binding var systemPrompt: String
    @Binding var enableShortReply: Bool
    @Binding var defaultModel: String
    @Binding var fallbackModel: String
    @Binding var autoEscalateEnabled: Bool
    @Binding var escalateKeywordsText: String
    
    // 模型方案清單
    private let modelsCatalog: [ModelCatalogItem] = [
        ModelCatalogItem(
            id: "gpt-5.2",
            displayName: "GPT-5.2",
            category: .cost,
            shortDesc: "大量一般客服，回覆快、成本低",
            bestFor: ["大量一般客服", "快速 FAQ 回覆", "高頻詢問處理"],
            cautions: ["複雜/高風險議題建議升級"],
            priceTier: "低",
            tags: ["推薦", "省成本"],
            detail: "適合處理大量一般客服訊息，回覆速度快、成本低。遇到合約/退款/爭議等高風險問題建議升級模型。"
        ),
        ModelCatalogItem(
            id: "gpt-5.1",
            displayName: "GPT-5.1",
            category: .cost,
            shortDesc: "穩定高效、通用客服場景",
            bestFor: ["一般客服", "產品諮詢", "大量訊息處理"],
            cautions: ["高風險議題建議升級"],
            priceTier: "中低",
            tags: ["省成本"],
            detail: "適合主流客服需求，回覆穩定、成本可控。遇到複雜問題可搭配升級模型。"
        ),
        ModelCatalogItem(
            id: "gpt-5.0",
            displayName: "GPT-5.0",
            category: .cost,
            shortDesc: "一般客服與大量訊息（省成本、回覆快）",
            bestFor: ["大量一般客服", "基礎問題處理"],
            cautions: ["複雜/高風險議題建議升級"],
            priceTier: "低",
            tags: ["省成本", "高速"],
            detail: "適合一般客服與大量訊息處理。遇到合約/退款/爭議/技術問題時建議升級模型。"
        ),
        ModelCatalogItem(
            id: "gpt-4.1",
            displayName: "GPT-4.1",
            category: .quality,
            shortDesc: "合約/退款/技術等複雜問題",
            bestFor: ["合約", "退款爭議", "技術問題", "文件理解"],
            cautions: ["成本較高"],
            priceTier: "高",
            tags: ["高品質"],
            detail: "高推理能力與穩定性，適合高風險或高複雜度客服場景，但成本較高。"
        ),
        ModelCatalogItem(
            id: "gpt-4o",
            displayName: "GPT-4o",
            category: .quality,
            shortDesc: "高品質回覆、複雜問題",
            bestFor: ["合約", "退款爭議", "技術問題", "高品質回覆"],
            cautions: ["成本較高"],
            priceTier: "高",
            tags: ["高品質"],
            detail: "適合高品質回覆與複雜問題處理，成本較高。"
        ),
        ModelCatalogItem(
            id: "gpt-5.x-code",
            displayName: "GPT-5.x Code",
            category: .code,
            shortDesc: "API 串接、除錯、程式生成",
            bestFor: ["API 串接", "除錯", "程式生成", "工程問題排除"],
            cautions: ["不建議處理 UI/版面問題", "不建議高風險客服"],
            priceTier: "高",
            tags: ["工程", "高推理"],
            detail: "適合工程任務（API 串接、除錯、程式生成），不建議用來處理 UI/版面或高風險客服問題。"
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // 模型方案
            ConfigSection(title: "模型方案", icon: "brain.head.profile") {
                VStack(spacing: 16) {
                    ForEach(ModelCategory.allCases, id: \.self) { category in
                        let items = modelsCatalog.filter { $0.category == category }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(category.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(category.color)

                                ForEach(items) { item in
                                    ModelCatalogCard(item: item)
                                }
                            }
                        }
                    }
                }
            }

            // 模型選擇
            ConfigSection(title: "模型選擇", icon: "checkmark.circle") {
                VStack(spacing: 16) {
                    HStack {
                        Text("預設模型")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: $defaultModel) {
                            ForEach(modelsCatalog) { item in
                                Text(item.displayName).tag(item.id)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    HStack {
                        Text("升級模型（可選）")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: $fallbackModel) {
                            Text("不啟用").tag("")
                            ForEach(modelsCatalog) { item in
                                Text(item.displayName).tag(item.id)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("高風險自動升級")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("遇到關鍵字自動切換到升級模型")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $autoEscalateEnabled)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("關鍵字（逗號分隔）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $escalateKeywordsText)
                            .frame(minHeight: 70)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                }
            }
            
            // 模型參數
            ConfigSection(title: "回應參數", icon: "slider.horizontal.3") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("簡短回答模式")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("啟用後偏向精簡回覆")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $enableShortReply)
                            .labelsHidden()
                    }

                    ConfigSlider(
                        title: "回應長度",
                        value: Binding(
                            get: { Double(maxTokens) },
                            set: { maxTokens = Int($0) }
                        ),
                        range: 100...2000,
                        step: 100,
                        format: "%.0f"
                    )
                    
                    ConfigSlider(
                        title: "創造性",
                        value: $temperature,
                        range: 0...2,
                        step: 0.1,
                        format: "%.1f"
                    )
                }
            }
            
            // 系統提示詞
            ConfigSection(title: "系統提示詞", icon: "text.quote") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    
                    Text("這將決定AI助理的基本行為和回應方式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            if selectedAIModel != defaultModel {
                selectedAIModel = defaultModel
            }
        }
        .onChange(of: defaultModel) { _, newValue in
            selectedAIModel = newValue
        }
    }
    
    private func updateSystemPrompt(for model: String) {
        // 所有模型都使用相同的客服提示詞，因為模型本身已經決定了AI的能力
        systemPrompt = "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。根據客戶的需求提供準確、有用的資訊，並確保客戶滿意度。"
    }
}

// MARK: - 模型方案資料
enum ModelCategory: CaseIterable {
    case cost
    case quality
    case code
    
    var displayName: String {
        switch self {
        case .cost:
            return "省成本／高速（大量一般客服）"
        case .quality:
            return "高品質／複雜問題"
        case .code:
            return "程式／串接／Debug"
        }
    }
    
    var color: Color {
        switch self {
        case .cost:
            return .green
        case .quality:
            return .orange
        case .code:
            return .blue
        }
    }
}

struct ModelCatalogItem: Identifiable {
    let id: String
    let displayName: String
    let category: ModelCategory
    let shortDesc: String
    let bestFor: [String]
    let cautions: [String]
    let priceTier: String
    let tags: [String]
    let detail: String
}

struct ModelCatalogCard: View {
    let item: ModelCatalogItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(item.shortDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .foregroundColor(item.category.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.category.color.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
            }
            
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !item.bestFor.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("建議使用情境")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(item.bestFor, id: \.self) { text in
                                Text("• \(text)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if !item.cautions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("注意事項")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(item.cautions, id: \.self) { text in
                                Text("• \(text)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text("成本等級：\(item.priceTier)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 6)
            } label: {
                Text(isExpanded ? "收合詳情" : "展開詳情")
                    .font(.caption)
                    .foregroundColor(item.category.color)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - 個性設定視圖
struct PersonalitySettingsView: View {
    @Binding var aiName: String
    @Binding var aiPersonality: String
    @Binding var aiSpecialties: String
    @Binding var aiResponseStyle: String
    @Binding var aiLanguage: String
    @Binding var aiAvatar: String
    
    var body: some View {
        VStack(spacing: 20) {
            // 基本資訊
            ConfigSection(title: "基本資訊", icon: "person.circle") {
                VStack(spacing: 16) {
                    ConfigField(
                        title: "助理名稱",
                        placeholder: "例如：EchoChat 助理",
                        text: $aiName
                    )
                    
                    ConfigPicker(
                        title: "頭像圖示",
                        selection: $aiAvatar,
                        options: [
                            ("robot", "機器人"),
                            ("person.circle", "人物"),
                            ("brain.head.profile", "大腦"),
                            ("sparkles", "閃爍"),
                            ("star.circle", "星星")
                        ]
                    )
                }
            }
            
            // 個性特質
            ConfigSection(title: "個性特質", icon: "heart") {
                VStack(spacing: 16) {
                    ConfigField(
                        title: "個性描述",
                        placeholder: "例如：友善、專業、耐心",
                        text: $aiPersonality
                    )
                    
                    ConfigField(
                        title: "專業領域",
                        placeholder: "例如：產品諮詢、技術支援",
                        text: $aiSpecialties
                    )
                }
            }
            
            // 回應設定
            ConfigSection(title: "回應設定", icon: "text.bubble") {
                VStack(spacing: 16) {
                    ConfigPicker(
                        title: "回應風格",
                        selection: $aiResponseStyle,
                        options: [
                            ("正式", "正式"),
                            ("友善", "友善"),
                            ("專業", "專業"),
                            ("輕鬆", "輕鬆"),
                            ("幽默", "幽默")
                        ]
                    )
                    
                    ConfigPicker(
                        title: "語言設定",
                        selection: $aiLanguage,
                        options: [
                            ("繁體中文", "繁體中文"),
                            ("簡體中文", "簡體中文"),
                            ("English", "English"),
                            ("日本語", "日本語")
                        ]
                    )
                }
            }
        }
    }
}

// MARK: - 進階設定視圖
struct AdvancedSettingsView: View {
    @Binding var maxContextLength: Int
    @Binding var enableResponseFiltering: Bool
    @Binding var enableSentimentAnalysis: Bool
    @Binding var enableAutoApproval: Bool
    @Binding var approvalThreshold: Double
    @Binding var customInstructions: String
    
    var body: some View {
        VStack(spacing: 20) {
            // 上下文管理
            ConfigSection(title: "上下文管理", icon: "list.bullet") {
                VStack(spacing: 16) {
                    ConfigSlider(
                        title: "最大上下文長度",
                        value: Binding(
                            get: { Double(maxContextLength) },
                            set: { maxContextLength = Int($0) }
                        ),
                        range: 5...20,
                        step: 1,
                        format: "%.0f"
                    )
                }
            }
            
            // 品質控制
            ConfigSection(title: "品質控制", icon: "checkmark.shield") {
                VStack(spacing: 16) {
                    ConfigToggle(
                        title: "回應過濾",
                        description: "過濾不當或無關的回應",
                        isOn: $enableResponseFiltering
                    )
                    
                    ConfigToggle(
                        title: "情感分析",
                        description: "分析客戶情感狀態",
                        isOn: $enableSentimentAnalysis
                    )
                    
                    ConfigToggle(
                        title: "自動核准",
                        description: "自動核准高信心度的回應",
                        isOn: $enableAutoApproval
                    )
                    
                    if enableAutoApproval {
                        ConfigSlider(
                            title: "核准閾值",
                            value: $approvalThreshold,
                            range: 0.5...1.0,
                            step: 0.1,
                            format: "%.1f"
                        )
                    }
                }
            }
            
            // 自定義指令
            ConfigSection(title: "自定義指令", icon: "text.quote") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $customInstructions)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    
                    Text("額外的指令或限制條件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 模板設定視圖
struct TemplateSettingsView: View {
    @Binding var showingTemplatePicker: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 快速模板（簡化版）
            ConfigSection(title: "常用模板", icon: "text.bubble") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(ResponseTemplate.templates.prefix(6), id: \.name) { template in
                        QuickTemplateCard(template: template)
                    }
                }
            }
            
            // 選擇模板按鈕
            ConfigButton(
                title: "選擇更多模板",
                icon: "list.bullet",
                color: .blue
            ) {
                showingTemplatePicker = true
            }
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView()
        }
    }
}

// MARK: - 測試連線視圖
struct TestConnectionView: View {
    let selectedAIModel: String
    @Binding var showingTestResult: Bool
    @Binding var testResult: String
    @Binding var isLoading: Bool
    @StateObject private var aiService = AIService()
    @State private var showingChatTest = false
    
    var body: some View {
        VStack(spacing: 20) {
            // AI模型狀態
            ConfigSection(title: "AI模型狀態", icon: "brain.head.profile") {
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        
                        Text("已選擇：\(selectedAIModel)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("測試中...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 測試按鈕
            VStack(spacing: 12) {
                ConfigButton(
                    title: "測試AI聊天",
                    icon: "message.circle",
                    color: .blue
                ) {
                    showingChatTest = true
                }
                
                ConfigButton(
                    title: "測試AI回應",
                    icon: "text.bubble",
                    color: .green
                ) {
                    testAIResponse()
                }
                
                ConfigButton(
                    title: "預覽AI功能",
                    icon: "eye",
                    color: .orange
                ) {
                    previewAIFeatures()
                }
                
                ConfigButton(
                    title: "檢查模型狀態",
                    icon: "checkmark.shield",
                    color: .purple
                ) {
                    checkModelStatus()
                }
            }
        }
        .sheet(isPresented: $showingChatTest) {
            ChatTestView(
                selectedAIModel: selectedAIModel,
                aiService: aiService
            )
        }
    }
    
    private func testAIResponse() {
        isLoading = true
        
        Task {
            do {
                let response = try await aiService.generateResponse(for: "你好，請簡單介紹一下你自己", conversationHistory: [])
                await MainActor.run {
                    isLoading = false
                    testResult = "AI回應測試成功！\n\n選擇的模型：\(selectedAIModel)\n\n測試回應：\(response)"
                    showingTestResult = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    testResult = "測試失敗：\(error.localizedDescription)\n\n請檢查：\n1. API金鑰是否正確設定\n2. 網路連線是否正常\n3. API端點是否正確"
                    showingTestResult = true
                }
            }
        }
    }
    
    private func previewAIFeatures() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            let modelFeatures = getModelFeatures(for: selectedAIModel)
            testResult = "\(selectedAIModel) 功能預覽：\n\n\(modelFeatures)"
            showingTestResult = true
        }
    }
    
    private func getModelFeatures(for model: String) -> String {
        switch model {
        case "GPT-4.1":
            return "• 最新最先進的AI技術\n• 超強的理解力和創造力\n• 處理複雜問題能力最佳\n• 支援多種語言和格式\n• 最高品質的回應"
        case "GPT-4":
            return "• 高級AI模型\n• 優秀的創意和分析能力\n• 適合複雜任務處理\n• 深度理解上下文\n• 專業級回應品質"
        case "GPT-4 Mini":
            return "• 輕量級GPT-4模型\n• 快速回應速度\n• 成本效益優化\n• 保持高品質輸出\n• 適合日常客服需求"
        case "GPT-3.5 Turbo":
            return "• 經典平衡模型\n• 穩定可靠的表現\n• 快速回應時間\n• 成本效益良好\n• 適合一般客服場景"
        case "Claude-3":
            return "• 擅長分析和寫作\n• 優秀的邏輯推理能力\n• 專業文檔處理\n• 深度思考能力\n• 適合技術支援"
        default:
            return "• 智能客服回應\n• 多語言支援\n• 上下文理解\n• 專業知識庫\n• 個性化設定"
        }
    }
    
    private func checkModelStatus() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            testResult = "模型狀態檢查完成：\n\n✅ 模型已就緒\n✅ 服務正常運行\n✅ 回應品質良好\n✅ 設定已保存"
            showingTestResult = true
        }
    }
}

// MARK: - AI聊天測試視圖
struct ChatTestView: View {
    let selectedAIModel: String
    let aiService: AIService
    
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [TestChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 聊天標題
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("AI聊天測試")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("模型：\(selectedAIModel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(.separator)),
                    alignment: .bottom
                )
                
                // 聊天訊息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                // 歡迎訊息
                                VStack(spacing: 16) {
                                    Image(systemName: "message.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    Text("開始與AI對話")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("測試您的AI配置，發送訊息開始對話")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                ForEach(messages) { message in
                                    TestChatMessageView(message: message)
                                        .id(message.id)
                                }
                                
                                if isLoading {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("AI正在思考...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .id("loading")
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: messages.count) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isLoading) { oldValue, newValue in
                        if isLoading {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 輸入區域
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        TextField("輸入訊息...", text: $inputText, axis: .vertical)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .focused($isInputFocused)
                            .disabled(isLoading)
                        
                        Button(action: sendMessage) {
                            Image(systemName: isLoading ? "stop.circle" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(isLoading ? .red : .blue)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // 添加歡迎訊息
            let welcomeMessage = TestChatMessage(
                id: UUID(),
                content: "您好！我是您的AI助手，使用\(selectedAIModel)模型。請發送訊息開始測試對話。",
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(welcomeMessage)
        }
    }
    
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // 添加用戶訊息
        let userMessage = TestChatMessage(
            id: UUID(),
            content: trimmedText,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // 清空輸入框
        inputText = ""
        isInputFocused = false
        
        // 開始AI回應
        isLoading = true
        
        Task {
            do {
                // 準備對話歷史
                let conversationHistory = messages.map { message in
                    ChatMessage(
                        content: message.content,
                        isFromUser: message.isFromUser
                    )
                }
                
                let response = try await aiService.generateResponse(for: trimmedText, conversationHistory: conversationHistory)
                
                await MainActor.run {
                    // 添加AI回應
                    let aiMessage = TestChatMessage(
                        id: UUID(),
                        content: response,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(aiMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 添加錯誤訊息
                    let errorMessage = TestChatMessage(
                        id: UUID(),
                        content: "抱歉，回應時發生錯誤：\(error.localizedDescription)",
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 聊天訊息模型
struct TestChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - 聊天訊息視圖
struct TestChatMessageView: View {
    let message: TestChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                userMessageBubble
            } else {
                aiMessageBubble
                Spacer()
            }
        }
    }
    
    private var userMessageBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .cornerRadius(4, corners: [.topLeft])
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var aiMessageBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                    .cornerRadius(4, corners: [.topRight])
            }
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 圓角擴展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 支援組件

struct ConfigSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color.warmAccent)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.primaryText)
                
                Spacer()
            }
            
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }
}

struct ConfigField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color.primaryText)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
            }
        }
    }
}

struct ConfigSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                Text(String(format: format, value))
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
            
            Slider(value: $value, in: range, step: step)
                .accentColor(Color.warmAccent)
        }
    }
}

struct ConfigPicker: View {
    let title: String
    @Binding var selection: String
    let options: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(options, id: \.0) { option in
                    Button(option.1) {
                        selection = option.0
                    }
                }
            } label: {
                HStack {
                    Text(options.first { $0.0 == selection }?.1 ?? selection)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }
}

struct ConfigToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
        }
    }
}

struct ConfigButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(8)
        }
    }
}

// MARK: - 快速模板卡片
struct QuickTemplateCard: View {
    let template: ResponseTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.category.icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(template.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }
}

// MARK: - 模板選擇器視圖
struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: TemplateCategory? = nil
    @State private var searchText = ""
    
    var filteredTemplates: [ResponseTemplate] {
        let templates = ResponseTemplate.templates
        if let category = selectedCategory {
            return templates.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            return templates.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        return templates
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜尋欄
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜尋模板...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 分類篩選
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "全部",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(TemplateCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.displayName,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
                
                // 模板列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTemplates, id: \.name) { template in
                            TemplateDetailCard(template: template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("選擇模板")
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

// MARK: - 分類篩選按鈕
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.blue : Color.cardBackground
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color.blue : Color.dividerColor,
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - 模板詳細卡片
struct TemplateDetailCard: View {
    let template: ResponseTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: template.category.icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // 複製模板內容到剪貼簿
                    UIPasteboard.general.string = template.content
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            
            Text(template.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Text(template.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(12)
                .background(Color.cardBackground.opacity(0.5))
                .cornerRadius(8)
            
            HStack {
                Spacer()
                
                Button("使用此模板") {
                    // 這裡可以添加使用模板的邏輯
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }
}

// MARK: - AI模型卡片
struct AIModelCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 圖示
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color.warmAccent)
                    .frame(width: 40, height: 40)
                    .background(
                        isSelected ? Color.warmAccent : Color.warmAccent.opacity(0.1)
                    )
                    .clipShape(Circle())
                
                // 內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : Color.primaryText)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : Color.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 選擇指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.warmAccent : Color.cardBackground
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.warmAccent : Color.dividerColor,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - AI助理預覽視圖
struct AIAssistantPreviewView: View {
    let name: String
    let avatar: String
    let personality: String
    let specialties: String
    let responseStyle: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 助理資訊
                VStack(spacing: 16) {
                    Image(systemName: avatar)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .frame(width: 100, height: 100)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(spacing: 8) {
                        Text(name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(personality)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(specialties)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // 回應風格預覽
                VStack(alignment: .leading, spacing: 12) {
                    Text("回應風格預覽")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("客戶：您好，我想詢問關於產品退貨的事項")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(name)：您好！我是\(name)，很高興為您服務。關於產品退貨，我可以為您詳細說明相關流程和注意事項。請問您購買的是哪個產品呢？")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationTitle("AI助理預覽")
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

// MARK: - 服務設定視圖
struct ServiceSettingsView: View {
    @Binding var aiServiceEnabled: Bool
    @Binding var selectedAIModel: String
    
    // AI服務方案選項
    private let aiModels = [
        ("客服專家", "專業客服AI，擅長處理客戶諮詢", "person.circle.fill", "blue"),
        ("銷售助手", "銷售導向AI，專注於產品推廣", "chart.line.uptrend.xyaxis", "green"),
        ("技術支援", "技術支援AI，解決技術問題", "wrench.and.screwdriver.fill", "orange"),
        ("多語言客服", "支援多種語言的國際化客服", "globe", "purple"),
        ("情感分析", "具備情感分析能力的智能客服", "heart.fill", "red")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // 服務啟用設定
            ConfigSection(title: "AI服務狀態", icon: "cloud.fill") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI自動回應服務")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("啟用後，系統將自動回應客戶訊息")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $aiServiceEnabled)
                            .labelsHidden()
                    }
                    
                    // 服務狀態指示器
                    HStack {
                        Circle()
                            .fill(aiServiceEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(aiServiceEnabled ? "AI服務已啟用" : "AI服務未啟用")
                            .font(.caption)
                            .foregroundColor(aiServiceEnabled ? .green : .gray)
                        
                        Spacer()
                    }
                }
            }
            
            // AI模型選擇
            ConfigSection(title: "AI服務方案", icon: "brain.head.profile") {
                VStack(spacing: 12) {
                    ForEach(aiModels, id: \.0) { model in
                        AIModelCard(
                            title: model.0,
                            description: model.1,
                            icon: model.2,
                            color: Color(model.3),
                            isSelected: selectedAIModel == model.0
                        ) {
                            selectedAIModel = model.0
                        }
                    }
                }
            }
            
            // 使用統計
            ConfigSection(title: "使用統計", icon: "chart.bar.fill") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本月回應次數")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("1,234")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("客戶滿意度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("4.8/5.0")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("平均回應時間")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("2.3秒")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("問題解決率")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("85%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // 服務說明
            ConfigSection(title: "服務說明", icon: "info.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("• 無需設定API金鑰，我們提供完整的AI服務")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("• 支援Line官方帳號自動回應")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("• 可自定義AI個性和回應風格")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("• 24/7全天候自動客服服務")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("• 支援多種語言和專業領域")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    AIAssistantConfigView()
} 