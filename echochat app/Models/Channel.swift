//
//  Channel.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class Channel {
    var id: String
    var name: String
    var platform: String
    var channelDescription: String
    var icon: String
    var color: String
    var apiKey: String
    var webhookUrl: String
    var channelSecret: String
    var isActive: Bool
    var apiStatus: String
    var totalMessages: Int
    var todayMessages: Int
    var avgResponseTime: Int
    var satisfactionScore: Int
    var lastActivity: Date
    var createdAt: Date
    var updatedAt: Date
    var userId: String
    
    init(name: String, platform: String, userId: String) {
        self.id = UUID().uuidString
        self.name = name
        self.platform = platform
        self.channelDescription = "\(platform) 頻道"
        self.icon = "antenna.radiowaves.left.and.right"
        self.color = "#007AFF"
        self.apiKey = ""
        self.webhookUrl = ""
        self.channelSecret = ""
        self.isActive = false
        self.apiStatus = "未連接"
        self.totalMessages = 0
        self.todayMessages = 0
        self.avgResponseTime = 0
        self.satisfactionScore = 0
        self.lastActivity = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = userId
        
        // 根據平台設定預設值
        switch platform.lowercased() {
        case "line":
            self.icon = "message.circle.fill"
            self.color = "#00C300"
            self.channelDescription = "Line 官方帳號"
        case "instagram":
            self.icon = "camera.circle.fill"
            self.color = "#E4405F"
            self.channelDescription = "Instagram 商業帳號"
        case "whatsapp":
            self.icon = "phone.circle.fill"
            self.color = "#25D366"
            self.channelDescription = "WhatsApp Business"
        case "facebook":
            self.icon = "person.2.circle.fill"
            self.color = "#1877F2"
            self.channelDescription = "Facebook 粉絲專頁"
        case "telegram":
            self.icon = "paperplane.circle.fill"
            self.color = "#0088CC"
            self.channelDescription = "Telegram Bot"
        case "discord":
            self.icon = "gamecontroller.circle.fill"
            self.color = "#5865F2"
            self.channelDescription = "Discord Bot"
        default:
            break
        }
    }
}

// 擴展Channel以提供樣本數據
extension Channel {
    static var sampleChannels: [Channel] {
        let channels = [
            Channel(name: "Line官方帳號", platform: "Line", userId: "user1"),
            Channel(name: "Instagram商業帳號", platform: "Instagram", userId: "user1"),
            Channel(name: "WhatsApp Business", platform: "WhatsApp", userId: "user1")
        ]
        
        // 設定樣本數據
        channels[0].isActive = true
        channels[0].apiStatus = "已連接"
        channels[0].totalMessages = 1250
        channels[0].todayMessages = 45
        channels[0].avgResponseTime = 15
        channels[0].satisfactionScore = 92
        channels[0].lastActivity = Date().addingTimeInterval(-3600)
        
        channels[1].isActive = true
        channels[1].apiStatus = "已連接"
        channels[1].totalMessages = 890
        channels[1].todayMessages = 23
        channels[1].avgResponseTime = 20
        channels[1].satisfactionScore = 88
        channels[1].lastActivity = Date().addingTimeInterval(-7200)
        
        channels[2].isActive = false
        channels[2].apiStatus = "未連接"
        channels[2].totalMessages = 0
        channels[2].todayMessages = 0
        channels[2].avgResponseTime = 0
        channels[2].satisfactionScore = 0
        channels[2].lastActivity = Date().addingTimeInterval(-86400)
        
        return channels
    }
}

// 擴展Channel以提供顏色轉換
extension Channel {
    var colorValue: Color {
        Color(hex: color) ?? .blue
    }
}

// Color擴展以支援十六進制顏色
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 