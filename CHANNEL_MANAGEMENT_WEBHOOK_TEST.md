# ChannelManagementView 用戶專屬 Webhook URL 測試指南

## 功能概述

我們已經將用戶專屬 webhook URL 功能整合到 `ChannelManagementView.swift` 的 LINE 設定流程中。現在當用戶在頻道管理頁面設定 LINE 頻道時，系統會自動生成專屬的 webhook URL。

## 測試步驟

### 1. 進入頻道管理頁面
- 在您的 app 中導航到「頻道管理」頁面

### 2. 點擊 LINE 快速操作
- 在「快速操作」區塊中點擊「Line」卡片
- 這會打開 LINE API 設定視圖

### 3. 查看用戶專屬 Webhook URL
在 LINE 設定流程中，您會看到：

#### 步驟 1：取得 LINE API 憑證
- 輸入 Channel Secret
- 輸入 Channel Access Token

#### 步驟 2：設定您的專屬 Webhook URL ⭐
- **標題**：「設定您的專屬 Webhook URL」
- **描述**：「系統已為您生成專屬的 Webhook URL，請複製到 LINE Developers Console」
- **輸入欄位**：「您的專屬 Webhook URL」
- **狀態**：自動生成，只讀，帶複製按鈕

### 4. 預期結果

#### 成功情況
您應該會看到：
```
設定您的專屬 Webhook URL
系統已為您生成專屬的 Webhook URL，請複製到 LINE Developers Console

您的專屬 Webhook URL
https://ai-chatbot-umqm.onrender.com/api/webhook/line/{您的用戶ID} [複製]

操作步驟：
1. 系統已自動生成您的專屬 Webhook URL
2. 點擊複製按鈕複製 URL
3. 在 LINE Developers Console 中貼上此 URL
4. 啟用 Webhook 功能並點擊「Verify」測試連接
```

#### 調試信息
在 Xcode 控制台中，您應該會看到：
```
📱 生成的用戶專屬 webhook URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/{用戶ID}
📱 用戶 ID: {用戶ID}
✅ LINE Step 2: 用戶專屬 Webhook URL saved!
```

## 功能特點

### ✅ 已整合的功能
- **自動生成**：進入 LINE 設定時自動生成用戶專屬 webhook URL
- **用戶隔離**：每個用戶都有獨立的 webhook 端點
- **複製功能**：一鍵複製 URL 到剪貼簿
- **本地儲存**：URL 保存在本地，下次進入時直接顯示
- **後端同步**：嘗試同步到後端（可選）

### 🔄 自動化流程
1. 用戶點擊 LINE 快速操作
2. 系統自動檢查本地是否有已保存的用戶 ID
3. 如果沒有，生成臨時 ID 或從後端獲取
4. 使用用戶 ID 生成專屬 webhook URL
5. 顯示在設定步驟中
6. 保存到本地儲存

### 🛡️ 安全性
- 每個用戶都有獨立的 webhook 端點
- 基於用戶 ID 動態生成
- 本地儲存保護

## 測試檢查清單

### 基本功能測試
- [ ] 進入頻道管理頁面
- [ ] 點擊 LINE 快速操作
- [ ] 查看步驟 2 是否顯示「您的專屬 Webhook URL」
- [ ] 檢查 URL 是否包含用戶 ID
- [ ] 測試複製按鈕功能
- [ ] 檢查 Xcode 控制台的調試信息

### 錯誤處理測試
- [ ] 測試網路連線失敗時的行為
- [ ] 測試後端 API 不可用時的行為
- [ ] 檢查錯誤信息的顯示

### 本地儲存測試
- [ ] 完成設定後關閉 app
- [ ] 重新打開 app 並進入 LINE 設定
- [ ] 檢查是否顯示之前生成的 URL

## 故障排除

### 如果看不到專屬 Webhook URL
1. 確保您已經編譯並運行了最新版本的 app
2. 檢查 Xcode 控制台是否有錯誤信息
3. 嘗試重新啟動 app

### 如果 URL 沒有生成
1. 檢查網路連線
2. 查看 Xcode 控制台的錯誤信息
3. 確保 LineAPIService 正確實作

### 如果複製功能不工作
1. 檢查剪貼簿權限
2. 確保 URL 已經生成
3. 重新測試複製按鈕

## 與 LINE Developers Console 整合

### 1. 複製專屬 URL
- 在 LINE 設定步驟中點擊複製按鈕
- URL 會複製到剪貼簿

### 2. 在 LINE Developers Console 設定
1. 登入 LINE Developers Console
2. 選擇您的 Channel
3. 在 Messaging API 設定中
4. 將 Webhook URL 設為複製的專屬 URL
5. 啟用 Use webhook
6. 點擊「Verify」測試連接

### 3. 範例 URL 格式
```
用戶 ID: 507f1f77bcf86cd799439011
專屬 URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/507f1f77bcf86cd799439011
```

## 技術細節

### 本地儲存鍵值
- `currentUserId`: 保存用戶 ID
- `userWebhookURL`: 保存生成的專屬 webhook URL

### 生成邏輯
1. 檢查本地是否有已保存的用戶 ID
2. 如果沒有，生成臨時 ID 或從後端獲取
3. 使用用戶 ID 生成專屬 webhook URL
4. 保存到本地儲存

### 錯誤處理
- 後端 API 失敗時使用本地模式
- 顯示適當的錯誤信息
- 保持功能可用性

這個功能現在已經完全整合到 ChannelManagementView 中，提供了類似 seachat 的用戶專屬 webhook URL 體驗！ 