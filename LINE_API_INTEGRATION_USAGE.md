# LINE API 整合使用說明

## 📱 概述

本整合提供了完整的 LINE Webhook 和 API 功能，包括：
- 即時訊息接收
- 對話管理
- 統計資料
- 訊息發送
- 用戶資料查詢

## 🚀 快速開始

### 1. 基本使用

```swift
// 在您的 SwiftUI 視圖中使用
@StateObject private var lineManager = LineManager.shared

// 獲取 LINE 整合列表
lineManager.fetchIntegrations()

// 檢查連線狀態
await lineManager.checkConnection()

// 發送訊息
let success = await lineManager.sendMessage(
    message: "Hello from iOS!", 
    customerId: "user_id"
)
```

### 2. 即時訊息監聽

```swift
// 即時訊息會自動接收並顯示在 realTimeMessages 陣列中
List(lineManager.realTimeMessages, id: \.id) { message in
    Text(message.content)
}
```

## 📋 主要功能

### LINE 整合管理
- `fetchIntegrations()` - 獲取所有 LINE 整合
- `checkConnection()` - 檢查 LINE API 連線狀態

### 對話管理
- `fetchConversations(tenantId:page:)` - 獲取對話記錄
- `fetchConversationDetail(conversationId:)` - 獲取對話詳情
- `searchConversations(tenantId:query:page:)` - 搜尋對話

### 訊息發送
- `sendMessage(message:customerId:)` - 發送訊息到 LINE
- `sendTestMessage(tenantId:message:userId:completion:)` - 發送測試訊息

### 統計資料
- `fetchStats(tenantId:)` - 獲取統計資料

## 🎨 SwiftUI 組件

### 基本視圖
- `LineIntegrationsView` - LINE 整合列表
- `ConversationsView` - 對話列表
- `ConversationDetailView` - 對話詳情
- `RealTimeMessagesView` - 即時訊息
- `LineStatsView` - 統計資料

### 功能視圖
- `SendMessageView` - 發送訊息
- `ErrorView` - 錯誤顯示

## 🔧 配置設定

### 1. 後端 API 設定

在 `LineAPIService.swift` 中修改：
```swift
private let backendBaseURL = "http://localhost:3000" // 替換為您的實際 API 網址
```

### 2. LINE API 憑證

在 UserDefaults 中設定：
```swift
UserDefaults.standard.set("your_channel_access_token", forKey: "lineChannelAccessToken")
UserDefaults.standard.set("your_channel_secret", forKey: "lineChannelSecret")
```

## 📱 使用範例

### 完整的 LINE 儀表板

```swift
struct LineDashboardView: View {
    @StateObject private var lineManager = LineManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 整合列表
            LineIntegrationsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("整合")
                }
            
            // 即時訊息
            RealTimeMessagesView()
                .tabItem {
                    Image(systemName: "bolt")
                    Text("即時訊息")
                }
                .badge(lineManager.hasNewMessages ? lineManager.realTimeMessages.count : nil)
            
            // 統計資料
            if let firstIntegration = lineManager.integrations.first {
                LineStatsView(tenantId: firstIntegration.tenantId)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("統計")
                    }
            }
        }
        .onAppear {
            lineManager.fetchIntegrations()
        }
    }
}
```

### 發送訊息

```swift
struct SendMessageView: View {
    let tenantId: String
    let userId: String
    @StateObject private var lineManager = LineManager.shared
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            TextField("輸入訊息", text: $messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("發送訊息") {
                lineManager.sendTestMessage(
                    tenantId: tenantId,
                    message: messageText,
                    userId: userId
                ) { success, message in
                    print(success ? "發送成功" : "發送失敗: \(message)")
                }
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
    }
}
```

## 🔐 安全性

### 生產環境配置

1. 使用 HTTPS 協議
2. 設定適當的 API 金鑰
3. 實作適當的錯誤處理
4. 添加請求重試機制

### 錯誤處理

```swift
// 監聽錯誤
.alert("錯誤", isPresented: .constant(lineManager.errorMessage != nil)) {
    Button("確定") {
        lineManager.clearError()
    }
} message: {
    if let errorMessage = lineManager.errorMessage {
        Text(errorMessage)
    }
}
```

## 📊 資料模型

### 主要結構
- `LineIntegration` - LINE 整合資訊
- `Conversation` - 對話記錄
- `ConversationDetail` - 對話詳情
- `Message` - 訊息內容
- `RealTimeMessage` - 即時訊息
- `LineStats` - 統計資料

### API 回應
- `APIResponse<T>` - 通用 API 回應
- `IntegrationsResponse` - 整合列表回應
- `ConversationsResponse` - 對話列表回應
- `StatsResponse` - 統計資料回應

## 🚀 部署注意事項

1. **後端設定**
   - 確保後端 API 正常運作
   - 設定正確的 CORS 政策
   - 實作適當的認證機制

2. **iOS 設定**
   - 在 Info.plist 中添加網路權限
   - 設定適當的 App Transport Security
   - 處理背景應用程式更新

3. **WebSocket 連接**
   - 確保 WebSocket 端點可達
   - 實作連接重試機制
   - 處理網路中斷情況

## 🔧 故障排除

### 常見問題

1. **連線失敗**
   - 檢查後端 API 是否正常運作
   - 確認網路連線狀態
   - 檢查 API 端點設定

2. **即時訊息未接收**
   - 檢查 WebSocket 連接狀態
   - 確認推送通知權限
   - 檢查後端 WebSocket 端點

3. **訊息發送失敗**
   - 檢查 LINE API 憑證
   - 確認用戶 ID 是否正確
   - 檢查訊息格式

### 除錯技巧

```swift
// 啟用詳細日誌
print("LINE API 連線狀態: \(lineManager.isConnected)")
print("WebSocket 連線狀態: \(lineManager.isWebSocketConnected)")
print("即時訊息數量: \(lineManager.realTimeMessages.count)")
```

## 📚 參考資源

- [LINE Messaging API 文檔](https://developers.line.biz/en/docs/messaging-api/)
- [SwiftUI 文檔](https://developer.apple.com/documentation/swiftui/)
- [URLSession WebSocket 文檔](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask) 