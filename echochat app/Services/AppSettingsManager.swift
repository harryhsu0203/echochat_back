//
//  AppSettingsManager.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import UIKit

class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()
    
    @AppStorage("selectedLanguage") var selectedLanguage: String = "繁體中文"
    @AppStorage("colorScheme") var colorScheme: String = "自動"
    @AppStorage("fontSize") var fontSize: String = "標準"
    @AppStorage("enableHapticFeedback") var enableHapticFeedback: Bool = true
    @AppStorage("enableAnimations") var enableAnimations: Bool = true
    @AppStorage("autoLockTimeout") var autoLockTimeout: Int = 5
    
    private init() {}
    
    // 獲取當前色彩模式
    var currentColorScheme: ColorScheme? {
        switch colorScheme {
        case "淺色":
            return .light
        case "深色":
            return .dark
        default:
            return nil // 自動模式
        }
    }
    
    // 獲取字體大小比例
    var fontSizeScale: CGFloat {
        switch fontSize {
        case "小":
            return 0.9
        case "大":
            return 1.1
        case "特大":
            return 1.2
        default:
            return 1.0 // 標準
        }
    }
    
    // 應用語言設定
    func applyLanguageSettings() {
        // 這裡可以實現語言切換邏輯
        // 例如：重新載入本地化字符串
        print("語言已切換為：\(selectedLanguage)")
    }
    
    // 應用色彩模式設定
    func applyColorSchemeSettings() {
        // 這裡可以實現色彩模式切換邏輯
        print("色彩模式已切換為：\(colorScheme)")
    }
    
    // 應用字體大小設定
    func applyFontSizeSettings() {
        // 這裡可以實現字體大小調整邏輯
        print("字體大小已調整為：\(fontSize)")
    }
    
    // 觸覺回饋
    func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enableHapticFeedback else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    // 檢查是否需要顯示動畫
    func shouldShowAnimations() -> Bool {
        return enableAnimations
    }
    
    // 獲取自動鎖定時間（秒）
    var autoLockTimeoutSeconds: TimeInterval {
        return TimeInterval(autoLockTimeout * 60) // 轉換為秒
    }
    
    // 重設為預設值
    func resetToDefaults() {
        selectedLanguage = "繁體中文"
        colorScheme = "自動"
        fontSize = "標準"
        enableHapticFeedback = true
        enableAnimations = true
        autoLockTimeout = 5
    }
    
    // 匯出設定
    func exportSettings() -> [String: Any] {
        return [
            "語言": selectedLanguage,
            "色彩模式": colorScheme,
            "字體大小": fontSize,
            "觸覺回饋": enableHapticFeedback,
            "動畫效果": enableAnimations,
            "自動鎖定時間": autoLockTimeout
        ]
    }
    
    // 匯入設定
    func importSettings(_ settings: [String: Any]) {
        if let language = settings["語言"] as? String {
            selectedLanguage = language
        }
        if let scheme = settings["色彩模式"] as? String {
            colorScheme = scheme
        }
        if let size = settings["字體大小"] as? String {
            fontSize = size
        }
        if let haptic = settings["觸覺回饋"] as? Bool {
            enableHapticFeedback = haptic
        }
        if let animations = settings["動畫效果"] as? Bool {
            enableAnimations = animations
        }
        if let timeout = settings["自動鎖定時間"] as? Int {
            autoLockTimeout = timeout
        }
    }
}

// 支援的語言列表
struct SupportedLanguages {
    static let languages = [
        Language(code: "zh-TW", name: "繁體中文", nativeName: "繁體中文"),
        Language(code: "zh-CN", name: "簡體中文", nativeName: "简体中文"),
        Language(code: "en", name: "English", nativeName: "English"),
        Language(code: "ja", name: "日本語", nativeName: "日本語"),
        Language(code: "ko", name: "한국어", nativeName: "한국어"),
        Language(code: "es", name: "Español", nativeName: "Español"),
        Language(code: "fr", name: "Français", nativeName: "Français"),
        Language(code: "de", name: "Deutsch", nativeName: "Deutsch"),
        Language(code: "it", name: "Italiano", nativeName: "Italiano"),
        Language(code: "pt", name: "Português", nativeName: "Português")
    ]
}

struct Language {
    let code: String
    let name: String
    let nativeName: String
}

// 色彩模式選項
struct ColorSchemeOptions {
    static let options = [
        ColorSchemeOption(value: "自動", description: "跟隨系統設定"),
        ColorSchemeOption(value: "淺色", description: "始終使用淺色模式"),
        ColorSchemeOption(value: "深色", description: "始終使用深色模式")
    ]
}

struct ColorSchemeOption {
    let value: String
    let description: String
}

// 字體大小選項
struct FontSizeOptions {
    static let options = [
        FontSizeOption(value: "小", scale: 0.9, description: "適合小螢幕設備"),
        FontSizeOption(value: "標準", scale: 1.0, description: "預設字體大小"),
        FontSizeOption(value: "大", scale: 1.1, description: "適合閱讀"),
        FontSizeOption(value: "特大", scale: 1.2, description: "適合視力不佳用戶")
    ]
}

struct FontSizeOption {
    let value: String
    let scale: CGFloat
    let description: String
} 