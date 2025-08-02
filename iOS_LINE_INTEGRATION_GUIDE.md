# iOS LINE API 整合完整指南

## 📱 概述

本指南將幫助您將後端的 LINE Webhook 和相關 API 功能整合到您的 iOS 原生應用中。

## 🚀 快速開始

### 1. 後端設置

```bash
npm install ws
npm start
```

### 2. iOS 專案設置

將 `iOS_LINE_API_Client.swift` 檔案添加到您的 iOS 專案中。

## 📋 API 端點

### 基礎 API
- `GET /api/mobile/line-integrations` - 獲取所有 LINE 整合
- `GET /api/mobile/line-conversations/:tenantId` - 獲取對話記錄
- `GET /api/mobile/conversation/:conversationId` - 獲取對話詳情
- `GET /api/mobile/line-stats/:tenantId` - 獲取統計資料

### 互動 API
- `POST /api/mobile/send-message/:tenantId` - 發送訊息
- `GET /api/mobile/user-profile/:tenantId/:userId` - 獲取用戶資料

### WebSocket
- `ws://localhost:3000` - 即時訊息接收

## 🔧 使用範例

### 基本使用

```swift
@StateObject private var lineManager = LineManager.shared

// 獲取整合列表
lineManager.fetchIntegrations()

// 獲取對話記錄
lineManager.fetchConversations(tenantId: "your_tenant_id")

// 發送訊息
lineManager.sendTestMessage(
    tenantId: "your_tenant_id",
    message: "Hello from iOS!",
    userId: "target_user_id"
) { success, message in
    print(success ? "發送成功" : "發送失敗: \(message)")
}
```

### 即時訊息

```swift
@ObservedObject var apiClient = LineAPIClient.shared

// 即時訊息會自動接收並顯示在 realTimeMessages 陣列中
List(apiClient.realTimeMessages, id: \.id) { message in
    Text(message.content)
}
```

## 🎨 SwiftUI 組件

### 對話列表

```swift
struct ConversationsView: View {
    let tenantId: String
    @StateObject private var lineManager = LineManager.shared
    
    var body: some View {
        List(lineManager.conversations, id: \.id) { conversation in
            VStack(alignment: .leading) {
                Text("用戶: \(conversation.sourceId)")
                Text("訊息數: \(conversation.messageCount)")
            }
        }
        .onAppear {
            lineManager.fetchConversations(tenantId: tenantId)
        }
    }
}
```

## 🔐 安全性

### 生產環境配置

```swift
private let baseURL = "https://your-production-domain.com"
```

### 錯誤處理

```swift
enum APIError: Error, LocalizedError {
    case invalidURL, noData, decodingError, serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無效的 URL"
        case .noData: return "沒有收到資料"
        case .decodingError: return "資料解析錯誤"
        case .serverError(let message): return message
        }
    }
}
```

## 🚀 部署

1. 更新 baseURL 為生產環境網址
2. 確保 WebSocket 連接使用 wss:// 協議
3. 添加適當的錯誤處理和重試機制

## 📚 參考

- [LINE Messaging API](https://developers.line.biz/en/docs/messaging-api/)
- [SwiftUI 文檔](https://developer.apple.com/documentation/swiftui/) 