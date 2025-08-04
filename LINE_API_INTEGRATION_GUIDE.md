# LINE API 多租戶整合指南

## 概述

本指南說明如何在 echochat app 中使用新整合的多租戶 LINE API 功能。這個功能允許您管理多個 LINE Bot 整合，查看對話記錄，發送測試訊息，以及查看統計資料。

## 功能特色

### 1. 多租戶管理
- 支援多個 LINE Bot 整合
- 每個租戶獨立管理
- 租戶狀態監控（啟用/停用/待處理）

### 2. 對話記錄管理
- 查看所有對話記錄
- 分頁載入功能
- 對話內容搜尋
- 詳細對話檢視

### 3. 統計資料
- 總對話數統計
- 總訊息數統計
- 今日對話數
- 平均訊息數

### 4. 測試功能
- 發送測試訊息
- 即時訊息測試

## 使用方式

### 1. 存取 LINE 整合功能

在應用程式主畫面中，點擊底部導航欄的「LINE整合」標籤，即可進入 LINE 整合管理介面。

### 2. 查看租戶列表

- 系統會自動載入所有可用的 LINE Bot 整合
- 每個租戶會顯示：
  - 租戶名稱
  - 租戶 ID
  - 狀態（啟用/停用/待處理）
  - 建立時間
  - 查看對話按鈕

### 3. 搜尋租戶

使用頂部的搜尋欄位可以搜尋特定的租戶：
- 支援按租戶名稱搜尋
- 支援按租戶 ID 搜尋

### 4. 查看對話記錄

點擊租戶的「查看對話」按鈕，可以查看該租戶的所有對話記錄：

#### 對話列表功能：
- 顯示用戶 ID
- 顯示最後一則訊息
- 顯示訊息數量
- 顯示最後更新時間
- 支援下拉重新整理
- 支援分頁載入更多

#### 對話搜尋：
- 在對話列表中輸入關鍵字搜尋
- 支援即時搜尋功能

### 5. 查看對話詳情

點擊對話項目可以查看完整的對話內容：
- 顯示所有訊息
- 區分用戶和助理訊息
- 顯示訊息時間戳
- 支援滾動瀏覽

### 6. 查看統計資料

在對話列表頁面可以查看統計資料：
- 總對話數
- 總訊息數
- 今日對話數
- 平均每對話訊息數

### 7. 發送測試訊息

在對話列表頁面可以發送測試訊息：
- 輸入用戶 ID
- 輸入訊息內容
- 即時發送到 LINE

## API 端點

### 基礎端點
所有 API 端點都以 `/api/mobile/` 為前綴

### 主要端點

1. **獲取 LINE 整合列表**
   ```
   GET /api/mobile/line-integrations
   ```

2. **獲取對話記錄**
   ```
   GET /api/mobile/line-conversations/{tenantId}?page={page}&limit={limit}
   ```

3. **獲取對話詳情**
   ```
   GET /api/mobile/conversation/{conversationId}
   ```

4. **發送測試訊息**
   ```
   POST /api/mobile/line-test-message/{tenantId}
   ```

5. **獲取統計資料**
   ```
   GET /api/mobile/line-stats/{tenantId}
   ```

6. **搜尋對話**
   ```
   GET /api/mobile/search-conversations/{tenantId}?query={query}&page={page}&limit={limit}
   ```

## 資料模型

### LineIntegration
```swift
struct LineIntegration: Codable, Identifiable {
    let id: String
    let tenantId: String
    let tenantName: String
    let status: String
    let createdAt: String
    let updatedAt: String
}
```

### Conversation
```swift
struct Conversation: Codable, Identifiable {
    let id: String
    let sourceId: String
    let messageCount: Int
    let lastMessage: LastMessage?
    let createdAt: String
    let updatedAt: String
}
```

### Message
```swift
struct Message: Codable, Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: String
}
```

## 錯誤處理

系統會自動處理以下錯誤情況：
- 網路連線錯誤
- API 回應錯誤
- 資料解析錯誤
- 認證錯誤

錯誤訊息會以彈出視窗的形式顯示給使用者。

## 設定要求

### 後端設定
1. 確保後端已部署到 Render
2. 確保 LINE Bot 整合已正確設定
3. 確保 API 端點已實作並可正常運作

### 前端設定
1. 確保 `APIConfig.swift` 中的 baseURL 指向正確的後端網址
2. 確保使用者已登入並有有效的認證 token

## 注意事項

1. **網路連線**：確保裝置有穩定的網路連線
2. **認證**：使用者必須先登入才能使用此功能
3. **資料快取**：系統會快取部分資料以提升效能
4. **分頁載入**：大量資料會使用分頁載入以避免效能問題
5. **即時更新**：使用下拉重新整理功能可以獲取最新資料

## 故障排除

### 常見問題

1. **無法載入租戶列表**
   - 檢查網路連線
   - 檢查後端服務是否正常運作
   - 檢查認證 token 是否有效

2. **對話記錄為空**
   - 確認該租戶有實際的 LINE 對話
   - 檢查後端資料庫是否有正確儲存對話記錄

3. **測試訊息發送失敗**
   - 確認用戶 ID 是否正確
   - 確認 LINE Bot 是否正常運作
   - 檢查後端 LINE API 設定

4. **搜尋功能無結果**
   - 確認搜尋關鍵字是否正確
   - 確認該租戶是否有包含關鍵字的對話

### 聯絡支援

如果遇到無法解決的問題，請聯絡技術支援團隊，並提供以下資訊：
- 錯誤訊息截圖
- 操作步驟
- 裝置資訊
- 網路環境 