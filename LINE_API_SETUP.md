# LINE API 設定指南

本指南將幫助您完成 LINE Messaging API 的設定，讓 EchoChat 應用程式能夠與官方 LINE 平台進行串接。

## 📋 前置需求

1. LINE 開發者帳號
2. 網域和 SSL 憑證（用於 Webhook）
3. 伺服器端點（用於接收 Webhook）

## 🚀 設定步驟

### 步驟 1：建立 LINE Channel

1. 前往 [LINE Developers Console](https://developers.line.biz/)
2. 登入您的 LINE 帳號
3. 點擊「Create Channel」
4. 選擇「Messaging API」
5. 填寫以下資訊：
   - **Channel name**: 您的頻道名稱（例如：EchoChat Bot）
   - **Channel description**: 頻道描述
   - **Category**: 選擇適當的類別
   - **Subcategory**: 選擇子類別
6. 同意條款並點擊「Create」

### 步驟 2：取得 API 認證資訊

1. 在 Channel 設定頁面，找到「Messaging API」標籤
2. 記錄以下資訊：
   - **Channel ID**: 用於識別您的頻道
   - **Channel Secret**: 用於驗證 Webhook 簽名
   - **Channel Access Token**: 用於發送訊息

### 步驟 3：設定 Webhook URL

1. 在「Messaging API」設定頁面，找到「Webhook settings」
2. 啟用「Use webhook」
3. 設定 Webhook URL：
   ```
   https://your-domain.com/webhook/line
   ```
4. 點擊「Verify」測試連線

### 步驟 4：在應用程式中設定

1. 開啟 EchoChat 應用程式
2. 前往「設定」→「Line 設定」
3. 填入以下資訊：
   - **Channel Access Token**: 從步驟 2 取得的 Token
   - **Channel Secret**: 從步驟 2 取得的 Secret
   - **Webhook URL**: 您的 Webhook 端點

### 步驟 5：測試連線

1. 在 Line 設定頁面點擊「測試 Line 連線」
2. 確認顯示「連線成功！」
3. 如果失敗，請檢查：
   - Token 和 Secret 是否正確
   - 網路連線是否正常
   - LINE API 服務是否可用

## 🔧 伺服器端設定

### Webhook 端點實作

您需要在伺服器端實作 Webhook 端點來接收 LINE 訊息：

```swift
// 範例：使用 Vapor 框架
import Vapor

func webhookHandler(req: Request) async throws -> Response {
    guard let body = req.body.data else {
        throw Abort(.badRequest)
    }
    
    let signature = req.headers.first(name: "X-Line-Signature") ?? ""
    
    // 處理 Webhook 事件
    let webhookHandler = LineWebhookHandler(modelContext: req.application.modelContext)
    let (responseData, response) = try await webhookHandler.handleWebhookRequest(req)
    
    return Response(body: .init(data: responseData))
}
```

### 路由設定

```swift
// 設定 Webhook 路由
app.post("webhook", "line") { req in
    try await webhookHandler(req: req)
}
```

## 🔐 安全性考量

### 1. 簽名驗證

所有 Webhook 請求都會包含 `X-Line-Signature` 標頭，用於驗證請求的真實性：

```swift
// 驗證簽名
let signature = request.value(forHTTPHeaderField: "X-Line-Signature") ?? ""
let isValid = verifySignature(request.httpBody, signature: signature)
```

### 2. HTTPS 要求

LINE 要求所有 Webhook URL 必須使用 HTTPS：

```
✅ https://your-domain.com/webhook/line
❌ http://your-domain.com/webhook/line
```

### 3. 憑證管理

- 使用有效的 SSL 憑證
- 定期更新憑證
- 監控憑證到期日

## 🧪 測試功能

### 1. 模擬訊息

在開發階段，您可以使用應用程式內的模擬功能：

1. 在 Line 聊天頁面點擊「模擬新訊息」
2. 系統會產生測試訊息
3. 測試 AI 回應和手動回應功能

### 2. 實際測試

1. 在 LINE 中搜尋您的 Bot
2. 發送測試訊息
3. 確認訊息出現在應用程式中
4. 測試回應功能

## 📊 監控和除錯

### 1. 日誌記錄

應用程式會記錄以下資訊：
- Webhook 接收狀態
- API 呼叫結果
- 錯誤訊息

### 2. 常見錯誤

| 錯誤 | 原因 | 解決方案 |
|------|------|----------|
| 401 Unauthorized | Token 無效 | 檢查 Channel Access Token |
| 403 Forbidden | 權限不足 | 確認 Bot 設定 |
| 404 Not Found | URL 錯誤 | 檢查 Webhook URL |
| 500 Internal Error | 伺服器錯誤 | 檢查伺服器日誌 |

### 3. 除錯工具

- LINE Developers Console 的 Webhook 測試工具
- 應用程式內的連線測試功能
- 伺服器日誌分析

## 🔄 進階功能

### 1. 群組聊天支援

要支援群組聊天，需要額外設定：

```swift
// 檢查事件來源類型
if let source = event["source"] as? [String: Any],
   let type = source["type"] as? String {
    switch type {
    case "user":
        // 個人聊天
    case "group":
        // 群組聊天
    case "room":
        // 房間聊天
    default:
        break
    }
}
```

### 2. 多媒體訊息

支援圖片、影片、檔案等：

```swift
// 處理圖片訊息
if messageType == "image" {
    let messageId = message["id"] as? String ?? ""
    // 下載圖片
    let imageUrl = "\(lineAPIBaseURL)/bot/message/\(messageId)/content"
}
```

### 3. 快速回覆

設定快速回覆按鈕：

```swift
let quickReply = [
    "type": "text",
    "text": "選擇選項",
    "quickReply": [
        "items": [
            [
                "type": "action",
                "action": [
                    "type": "message",
                    "label": "選項 1",
                    "text": "選擇了選項 1"
                ]
            ]
        ]
    ]
]
```

## 📞 支援

如果遇到問題：

1. 查看 [LINE Developers 文件](https://developers.line.biz/docs/)
2. 檢查應用程式日誌
3. 聯繫開發團隊

---

**注意**: 請確保您的 LINE Bot 符合 [LINE 平台政策](https://developers.line.biz/docs/legal/policy/)。 