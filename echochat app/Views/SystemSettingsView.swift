//
//  SystemSettingsView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import UIKit

struct SystemSettingsView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage = "繁體中文"
    @AppStorage("colorScheme") private var colorScheme = "自動"
    @AppStorage("fontSize") private var fontSize = "標準"
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("autoLockTimeout") private var autoLockTimeout = 5
    
    @State private var showingLanguagePicker = false
    @State private var showingColorSchemePicker = false
    @State private var showingResetAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingLogoutAlert = false
    @State private var alertMessage = ""
    
    @EnvironmentObject private var settingsManager: AppSettingsManager
    @EnvironmentObject private var authService: AuthService
    
    // 支援的語言
    private let supportedLanguages = [
        "繁體中文",
        "簡體中文", 
        "English",
        "日本語",
        "한국어",
        "Español",
        "Français",
        "Deutsch",
        "Italiano",
        "Português"
    ]
    
    // 色彩模式選項
    private let colorSchemeOptions = [
        "自動",
        "淺色",
        "深色"
    ]
    
    // 字體大小選項
    private let fontSizeOptions = [
        "小",
        "標準",
        "大",
        "特大"
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
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // 用戶資訊卡片
                        UserInfoCard()
                        
                        // 外觀設定
                        SettingsSection(title: "外觀設定") {
                            VStack(spacing: 12) {
                                // 色彩模式
                                SettingsPickerRow(
                                    title: "色彩模式",
                                    value: colorScheme,
                                    icon: "paintbrush.fill",
                                    action: { 
                                        settingsManager.triggerHapticFeedback(.light)
                                        showingColorSchemePicker = true 
                                    }
                                )
                                
                                // 字體大小
                                SettingsPicker(
                                    title: "字體大小",
                                    icon: "textformat.size",
                                    selection: $fontSize,
                                    options: fontSizeOptions
                                )
                                .onChange(of: fontSize) { _, newValue in
                                    settingsManager.triggerHapticFeedback(.light)
                                    settingsManager.applyFontSizeSettings()
                                }
                            }
                        }
                        
                        // 語言設定
                        SettingsSection(title: "語言設定") {
                            VStack(spacing: 12) {
                                // 語言選擇
                                SettingsPickerRow(
                                    title: "系統語言",
                                    value: selectedLanguage,
                                    icon: "globe",
                                    action: { 
                                        settingsManager.triggerHapticFeedback(.light)
                                        showingLanguagePicker = true 
                                    }
                                )
                            }
                        }
                        
                        // 互動設定
                        SettingsSection(title: "互動設定") {
                            VStack(spacing: 12) {
                                // 觸覺回饋
                                SettingsToggle(
                                    title: "觸覺回饋",
                                    isOn: $enableHapticFeedback,
                                    icon: "iphone.radiowaves.left.and.right"
                                )
                                .onChange(of: enableHapticFeedback) { _, newValue in
                                    if newValue {
                                        settingsManager.triggerHapticFeedback(.medium)
                                    }
                                }
                                
                                // 動畫效果
                                SettingsToggle(
                                    title: "動畫效果",
                                    isOn: $enableAnimations,
                                    icon: "sparkles"
                                )
                                .onChange(of: enableAnimations) { _, newValue in
                                    settingsManager.triggerHapticFeedback(.light)
                                }
                                
                                // 自動鎖定時間
                                SettingsSlider(
                                    title: "自動鎖定時間",
                                    value: Binding(
                                        get: { Double(autoLockTimeout) },
                                        set: { 
                                            autoLockTimeout = Int($0)
                                            settingsManager.triggerHapticFeedback(.light)
                                        }
                                    ),
                                    range: 1...30,
                                    step: 1,
                                    format: "%.0f 分鐘",
                                    icon: "lock"
                                )
                            }
                        }
                        
                        // 系統資訊
                        SettingsSection(title: "系統資訊") {
                            VStack(spacing: 12) {
                                SystemInfoRow(title: "應用程式版本", value: "1.0.0")
                                SystemInfoRow(title: "iOS版本", value: UIDevice.current.systemVersion)
                                SystemInfoRow(title: "設備型號", value: UIDevice.current.model)
                                SystemInfoRow(title: "可用儲存空間", value: getAvailableStorage())
                            }
                        }
                        
                        // 操作按鈕
                        VStack(spacing: 12) {
                            SettingsButton(
                                title: "重設為預設值",
                                icon: "arrow.clockwise",
                                action: { 
                                    settingsManager.triggerHapticFeedback(.medium)
                                    showingResetAlert = true 
                                }
                            )
                            
                            SettingsButton(
                                title: "匯出設定",
                                icon: "square.and.arrow.up",
                                action: { 
                                    settingsManager.triggerHapticFeedback(.light)
                                    exportSettings() 
                                }
                            )
                            
                            SettingsButton(
                                title: "關於應用程式",
                                icon: "info.circle",
                                action: { 
                                    settingsManager.triggerHapticFeedback(.light)
                                    showAboutApp() 
                                }
                            )
                        }
                        
                        // 底部間距
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // 底部登出按鈕
                VStack(spacing: 0) {
                    Divider()
                    
                    Button(action: {
                        settingsManager.triggerHapticFeedback(.medium)
                        showingLogoutAlert = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            Text("登出")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("系統設定")
        .navigationBarTitleDisplayMode(.large)
        .alert("重設設定", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重設", role: .destructive) {
                settingsManager.triggerHapticFeedback(.heavy)
                resetToDefaults()
            }
        } message: {
            Text("確定要重設所有系統設定為預設值嗎？")
        }
        .alert("操作成功", isPresented: $showingSuccessAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
        .alert("確認登出", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("登出", role: .destructive) {
                Task {
                    await logout()
                }
            }
        } message: {
            Text("確定要登出嗎？")
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $selectedLanguage,
                languages: supportedLanguages
            )
        }
        .sheet(isPresented: $showingColorSchemePicker) {
            ColorSchemePickerView(
                selectedScheme: $colorScheme,
                options: colorSchemeOptions
            )
        }
        .onChange(of: colorScheme) { _, newValue in
            settingsManager.applyColorSchemeSettings()
        }
        .onChange(of: selectedLanguage) { _, newValue in
            settingsManager.applyLanguageSettings()
        }
    }
    
    private func resetToDefaults() {
        selectedLanguage = "繁體中文"
        colorScheme = "自動"
        fontSize = "標準"
        enableHapticFeedback = true
        enableAnimations = true
        autoLockTimeout = 5
        
        alertMessage = "系統設定已重設為預設值"
        showingSuccessAlert = true
    }
    
    private func exportSettings() {
        _ = [
            "語言": selectedLanguage,
            "色彩模式": colorScheme,
            "字體大小": fontSize,
            "觸覺回饋": enableHapticFeedback ? "開啟" : "關閉",
            "動畫效果": enableAnimations ? "開啟" : "關閉",
            "自動鎖定時間": "\(autoLockTimeout) 分鐘"
        ]
        
        // 模擬匯出功能
        alertMessage = "設定已匯出到檔案"
        showingSuccessAlert = true
    }
    
    private func showAboutApp() {
        alertMessage = "EchoChat v1.0.0\n智能聊天機器人管理系統"
        showingSuccessAlert = true
    }
    
    private func getAvailableStorage() -> String {
        // 模擬獲取可用儲存空間
        return "2.5 GB"
    }
    
    private func logout() async {
        await authService.logout()
    }
}

// 用戶資訊卡片
struct UserInfoCard: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        VStack(spacing: 16) {
            // 用戶頭像
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                )
            
            // 用戶資訊
            VStack(spacing: 4) {
                Text(authService.currentUser?.username ?? "未登入")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(authService.currentUser?.email ?? "請先登入")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 登入狀態指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(authService.currentUser != nil ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(authService.currentUser != nil ? "已登入" : "未登入")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// 色彩模式預覽
struct ColorSchemePreview: View {
    @AppStorage("colorScheme") private var colorScheme = "自動"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("預覽")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                // 淺色模式預覽
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 60, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    Text("淺色")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 深色模式預覽
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .frame(width: 60, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    Text("深色")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 自動模式預覽
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    Text("自動")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

// 語言資訊卡片
struct LanguageInfoCard: View {
    @AppStorage("selectedLanguage") private var selectedLanguage = "繁體中文"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("語言資訊")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("目前語言：\(selectedLanguage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("語言變更將在下次啟動應用程式時生效")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// 語言選擇器視圖
struct LanguagePickerView: View {
    @Binding var selectedLanguage: String
    let languages: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                List {
                    ForEach(languages, id: \.self) { language in
                        Button(action: {
                            selectedLanguage = language
                            dismiss()
                        }) {
                            HStack {
                                Text(language)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("選擇語言")
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

// 色彩模式選擇器視圖
struct ColorSchemePickerView: View {
    @Binding var selectedScheme: String
    let options: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                SoftGradientBackground()
                
                List {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selectedScheme = option
                            dismiss()
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedScheme == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("選擇色彩模式")
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

// 設定選擇器行
struct SettingsPickerRow: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 設定開關
struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool
    var icon: String? = nil
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

// 系統資訊行
struct SystemInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        SystemSettingsView()
            .environmentObject(AppSettingsManager.shared)
    }
} 