# 用戶專屬 Webhook URL 實作總結

## 功能概述

我們已經成功實現了類似 seachat 的用戶專屬 webhook URL 功能，每個用戶都有基於其用戶 ID 的獨特 webhook 端點。

## 主要功能

### 1. 動態用戶專屬 URL 生成
- 從後端獲取用戶 ID
- 自動生成格式：`https://ai-chatbot-umqm.onrender.com/api/webhook/line/{userId}`
- 支援重新生成和更新

### 2. 前端實作 (LineSettingsView.swift)

#### 新增狀態變數
```swift
@State private var currentUserId: String = ""
@State private var userSpecificWebhookUrl = ""
@State private var isGeneratingUrl = false
```

#### 主要功能方法
- `generateUserSpecificWebhookURL()` - 生成用戶專屬 webhook URL
- `getUserIDFromBackend()` - 從後端獲取用戶 ID
- `generateWebhookURLForUser()` - 生成用戶專屬的 webhook URL
- `syncUserWebhookURLToBackend()` - 同步到後端
- `copyUserSpecificWebhookURL()` - 複製 URL 到剪貼簿

#### UI 改進
- 新增「您的專屬端點」區塊
- 顯示用戶 ID 和動態生成的 URL
- 重新整理按鈕和複製功能
- 載入狀態指示器

### 3. 後端服務實作 (LineAPIService.swift)

#### 新增方法
```swift
// 獲取用戶資料和 ID
func getUserProfile() async throws -> UserProfileData

// 生成用戶專屬的 webhook URL
func generateUserSpecificWebhookURL(userId: String) -> String

// 同步用戶 webhook URL 到後端
func syncUserWebhookURL(userId: String, webhookURL: String) async throws -> Bool

// 獲取用戶的 webhook URL 設定
func getUserWebhookURL() async throws -> String
```

## 使用流程

### 1. 用戶登入後
- 自動從後端獲取用戶 ID
- 生成專屬的 webhook URL
- 同步到後端資料庫

### 2. 在 LINE Developers Console 設定
1. 登入 LINE Developers Console
2. 選擇您的 Channel
3. 在 Messaging API 設定中
4. 將 Webhook URL 設為生成的專屬 URL
5. 啟用 Use webhook

### 3. 範例 URL 格式
```
用戶 ID: 507f1f77bcf86cd799439011
專屬 URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/507f1f77bcf86cd799439011
```

## 安全性特點

### 1. 用戶隔離
- 每個用戶都有獨立的 webhook 端點
- 防止用戶間互相干擾

### 2. 認證驗證
- 所有 API 請求都需要有效的 JWT token
- 驗證用戶只能訪問自己的端點

### 3. URL 驗證
- 確保 webhook URL 包含正確的用戶 ID
- 防止 URL 偽造

### 4. LINE 簽名驗證
- 使用 LINE Channel Secret 驗證 webhook 簽名
- 防止偽造請求

## 後端 API 端點

### 1. 獲取用戶資料
```
GET /api/user/profile
Authorization: Bearer {token}
```

### 2. 同步 webhook URL
```
POST /api/user/webhook-url
Authorization: Bearer {token}
Body: {
  "webhookUrl": "https://...",
  "platform": "line"
}
```

### 3. 用戶專屬 webhook 處理
```
POST /api/webhook/line/{userId}
X-Line-Signature: {signature}
Body: {LINE webhook event}
```

## 資料庫模型

### UserWebhookSetting
```javascript
{
  userId: ObjectId,
  webhookUrl: String,
  platform: String,
  isActive: Boolean,
  createdAt: Date,
  updatedAt: Date
}
```

### LineWebhookEvent
```javascript
{
  userId: ObjectId,
  eventType: String,
  sourceId: String,
  message: Mixed,
  replyToken: String,
  timestamp: Date,
  processed: Boolean
}
```

## 監控和日誌

### 1. Webhook 事件記錄
- 記錄所有 webhook 事件
- 包含用戶 ID、事件類型、時間戳

### 2. 錯誤處理
- 全局錯誤處理機制
- 錯誤通知系統

### 3. 速率限制
- 防止濫用 API
- 15 分鐘內最多 100 個請求

## 與 seachat 的相似性

### 1. 用戶專屬端點
- 每個用戶都有獨立的 webhook URL
- 基於用戶 ID 動態生成

### 2. 自動化流程
- 登入後自動生成專屬 URL
- 一鍵複製到 LINE Developers Console

### 3. 安全性
- 用戶隔離和認證
- LINE 簽名驗證

### 4. 易用性
- 清晰的 UI 介面
- 即時狀態反饋

## 下一步改進

### 1. 多平台支援
- 支援 Telegram、WhatsApp 等其他平台
- 統一的 webhook 管理介面

### 2. 進階功能
- Webhook 事件統計
- 自動回應規則設定
- 訊息歷史記錄

### 3. 監控增強
- 即時 webhook 狀態監控
- 效能指標追蹤
- 異常警報系統

這個實作提供了完整的用戶專屬 webhook URL 功能，確保每個用戶都有獨立的端點，並且具有適當的安全性和易用性。 