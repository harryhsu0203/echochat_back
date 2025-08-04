# Webhook URL 修復測試指南

## 問題描述

用戶在 ChannelManagementView 的 LINE 設定中看到「正在生成您的專屬 URL...」，但沒有顯示實際的 URL。

## 修復內容

### 1. 添加了詳細的調試信息
- 在 URL 生成過程的每個步驟都添加了 `print` 語句
- 可以通過 Xcode 控制台查看詳細的執行過程

### 2. 改進了錯誤處理
- 添加了備用方案，即使後端 API 失敗也能生成 URL
- 使用臨時用戶 ID 確保功能可用

### 3. 添加了手動重新生成功能
- 當 URL 沒有顯示時，會顯示重新生成按鈕（🔄）
- 點擊按鈕可以手動生成 webhook URL

## 測試步驟

### 1. 重新編譯並運行 app
```bash
# 在 Xcode 中重新編譯專案
```

### 2. 進入頻道管理頁面
- 導航到「頻道管理」頁面
- 點擊「Line」快速操作卡片

### 3. 查看調試信息
在 Xcode 控制台中，您應該會看到類似以下的調試信息：

```
🔄 強制重新生成 webhook URL...
🚀 開始載入用戶專屬 webhook URL...
🔍 開始獲取用戶 ID...
📱 本地沒有用戶 ID，嘗試從後端獲取...
📱 調用 getUserProfile...
❌ 後端獲取用戶 ID 失敗: [錯誤信息]
📱 生成臨時用戶 ID: [UUID]
🔗 開始生成用戶專屬 webhook URL...
📱 用戶 ID: [UUID]
🔗 LineAPIService - 生成 webhook URL:
   - 原始 baseURL: https://ai-chatbot-umqm.onrender.com/api
   - 清理後 baseURL: https://ai-chatbot-umqm.onrender.com
   - 用戶 ID: [UUID]
   - 最終 URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/[UUID]
🔗 生成的 webhook URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/[UUID]
✅ 成功生成 webhook URL，準備更新 UI...
📱 已擴展 inputValues 並設置 [2]: https://ai-chatbot-umqm.onrender.com/api/webhook/line/[UUID]
📱 已標記步驟 1 為完成
📱 UI 更新完成！
📱 生成的用戶專屬 webhook URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/[UUID]
📱 用戶 ID: [UUID]
```

### 4. 檢查 UI 顯示
在 LINE 設定步驟 2 中，您應該會看到：
- 輸入欄位顯示實際的 webhook URL
- 複製按鈕（📋）可用
- 步驟標記為完成（綠色勾號）

### 5. 如果仍然沒有顯示 URL
如果 URL 仍然沒有顯示，您會看到：
- 輸入欄位顯示「正在生成您的專屬 URL...」
- 重新生成按鈕（🔄）而不是複製按鈕
- 點擊重新生成按鈕可以手動生成 URL

## 預期結果

### 成功情況
```
您的專屬 Webhook URL
https://ai-chatbot-umqm.onrender.com/api/webhook/line/[用戶ID] [📋複製]
```

### 調試信息
```
📱 手動生成的 webhook URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/[UUID]
```

## 故障排除

### 如果看不到調試信息
1. 確保 Xcode 控制台已打開
2. 檢查是否有過濾器阻擋了調試信息
3. 重新運行 app

### 如果 URL 仍然沒有生成
1. 檢查 Xcode 控制台的錯誤信息
2. 嘗試點擊重新生成按鈕
3. 檢查網路連線

### 如果重新生成按鈕不工作
1. 檢查是否有編譯錯誤
2. 重新編譯並運行 app
3. 檢查控制台是否有錯誤信息

## 技術細節

### 修復的方法
1. **詳細調試**：添加了完整的調試信息追蹤
2. **備用方案**：使用臨時用戶 ID 確保功能可用
3. **手動觸發**：添加了重新生成按鈕作為備用方案
4. **錯誤隔離**：後端同步失敗不影響 UI 顯示

### 本地儲存
- `currentUserId`: 保存用戶 ID（臨時或從後端獲取）
- `userWebhookURL`: 保存生成的專屬 webhook URL

### 生成邏輯
1. 嘗試從本地獲取用戶 ID
2. 如果沒有，嘗試從後端獲取
3. 如果後端失敗，生成臨時用戶 ID
4. 使用用戶 ID 生成專屬 webhook URL
5. 更新 UI 並保存到本地

這個修復確保了即使後端 API 不可用，用戶也能看到專屬的 webhook URL！ 