import SwiftUI

// MARK: - 統一配色方案
extension Color {
    // 主背景色
    static let primaryBackground = Color(red: 1.0, green: 1.0, blue: 1.0) // #FFFFFF
    
    // 主要文字色
    static let primaryText = Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    
    // 次要文字色
    static let secondaryText = Color(red: 0.67, green: 0.67, blue: 0.67) // #AAAAAA
    
    // 暖色調強調色（淺米色/棕褐色）
    static let warmAccent = Color(red: 0.83, green: 0.76, blue: 0.69) // #D4C2B0
    
    // 冷色調強調色（淺青色/薄荷綠）
    static let coolAccent = Color(red: 0.4, green: 0.8, blue: 0.72) // #66CCB8
    
    // 卡片背景色
    static let cardBackground = Color(red: 1.0, green: 1.0, blue: 1.0) // #FFFFFF
    
    // 分割線色
    static let dividerColor = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2
    
    // 選中狀態色
    static let selectedColor = Color(red: 0.83, green: 0.76, blue: 0.69) // #D4C2B0
    
    // 未選中狀態色
    static let unselectedColor = Color(red: 0.67, green: 0.67, blue: 0.67) // #AAAAAA
}

// MARK: - 主題色彩管理器
struct AppColorScheme {
    static let shared = AppColorScheme()
    
    // 主要顏色
    let primary = Color.warmAccent
    let secondary = Color.coolAccent
    let background = Color.primaryBackground
    let surface = Color.cardBackground
    
    // 文字顏色
    let onPrimary = Color.primaryText
    let onSecondary = Color.primaryText
    let onBackground = Color.primaryText
    let onSurface = Color.primaryText
    
    // 狀態顏色
    let selected = Color.selectedColor
    let unselected = Color.unselectedColor
    let divider = Color.dividerColor
    
    // 功能顏色
    let success = Color.coolAccent
    let warning = Color.warmAccent
    let error = Color(red: 0.9, green: 0.3, blue: 0.3) // 錯誤紅色
    let info = Color.coolAccent
} 