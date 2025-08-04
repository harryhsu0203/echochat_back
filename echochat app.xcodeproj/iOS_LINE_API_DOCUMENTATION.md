# iOS LINE API 文檔

## 概述

這是一套專門為 iOS 原生應用程式設計的 LINE Webhook API，提供完整的 LINE Bot 管理功能。

## API 基礎設定

### 基礎 URL
```
http://localhost:3000  # 開發環境
https://your-render-app.onrender.com  # 生產環境
```

### 請求格式
- Content-Type: `application/json`
- 所有回應都包含 `success` 欄位表示操作是否成功

## API 端點

### 1. 獲取 LINE 整合列表

**端點**: `GET /api/mobile/line-integrations`

**描述**: 獲取所有可用的 LINE Bot 整合

**請求範例**:
```swift
LineAPIClient.shared.getLineIntegrations { result in
    switch result {
    case .success(let response):
        print("整合數量: \(response.total)")
        for integration in response.integrations {
            print("租戶: \(integration.tenantName)")
        }
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

**回應格式**:
```json
{
  "success": true,
  "data": {
    "integrations": [
      {
        "tenantId": "company_a",
        "tenantName": "公司A",
        "status": "active",
        "createdAt": "2025-01-01T00:00:00.000Z",
        "updatedAt": "2025-01-01T00:00:00.000Z"
      }
    ],
    "total": 1
  }
}
```

### 2. 獲取對話記錄

**端點**: `GET /api/mobile/line-conversations/:tenantId`

**參數**:
- `tenantId`: 租戶ID
- `page`: 頁碼 (預設: 1)
- `limit`: 每頁數量 (預設: 20)

**請求範例**:
```swift
LineAPIClient.shared.getConversations(
    tenantId: "company_a",
    page: 1,
    limit: 20
) { result in
    switch result {
    case .success(let response):
        print("對話數量: \(response.pagination.total)")
        for conversation in response.conversations {
            print("對話ID: \(conversation.id)")
        }
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

**回應格式**:
```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "id": "line_conv_001",
        "sourceId": "user123",
        "messageCount": 4,
        "lastMessage": {
          "content": "您好！",
          "role": "user",
          "timestamp": "2025-01-01T00:00:00.000Z"
        },
        "createdAt": "2025-01-01T00:00:00.000Z",
        "updatedAt": "2025-01-01T00:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

### 3. 獲取對話詳情

**端點**: `GET /api/mobile/conversation/:conversationId`

**參數**:
- `conversationId`: 對話ID

**請求範例**:
```swift
LineAPIClient.shared.getConversationDetail(
    conversationId: "line_conv_001"
) { result in
    switch result {
    case .success(let response):
        print("訊息數量: \(response.conversation.messages.count)")
        for message in response.conversation.messages {
            print("\(message.role): \(message.content)")
        }
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

**回應格式**:
```json
{
  "success": true,
  "data": {
    "conversation": {
      "id": "line_conv_001",
      "platform": "line",
      "tenantId": "company_a",
      "sourceId": "user123",
      "messages": [
        {
          "role": "user",
          "content": "您好！",
          "timestamp": "2025-01-01T00:00:00.000Z"
        },
        {
          "role": "assistant",
          "content": "您好！有什麼可以幫助您的嗎？",
          "timestamp": "2025-01-01T00:00:01.000Z"
        }
      ],
      "createdAt": "2025-01-01T00:00:00.000Z",
      "updatedAt": "2025-01-01T00:00:01.000Z"
    }
  }
}
```

### 4. 發送測試訊息

**端點**: `POST /api/mobile/line-test-message/:tenantId`

**參數**:
- `tenantId`: 租戶ID

**請求體**:
```json
{
  "message": "測試訊息",
  "userId": "user123"
}
```

**請求範例**:
```swift
LineAPIClient.shared.sendTestMessage(
    tenantId: "company_a",
    message: "測試訊息",
    userId: "user123"
) { result in
    switch result {
    case .success(let response):
        print("發送成功: \(response.message ?? "")")
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

**回應格式**:
```json
{
  "success": true,
  "message": "測試訊息發送成功"
}
```

### 5. 獲取統計資料

**端點**: `GET /api/mobile/line-stats/:tenantId`

**參數**:
- `tenantId`: 租戶ID

**請求範例**:
```swift
LineAPIClient.shared.getLineStats(tenantId: "company_a") { result in
    switch result {
    case .success(let response):
        print("總對話數: \(response.stats.totalConversations)")
        print("總訊息數: \(response.stats.totalMessages)")
        print("今日對話: \(response.stats.todayConversations)")
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

**回應格式**:
```json
{
  "success": true,
  "data": {
    "tenantId": "company_a",
    "stats": {
      "totalConversations": 100,
      "totalMessages": 500,
      "todayConversations": 5,
      "averageMessagesPerConversation": 5.0,
      "lastActivity": "2025-01-01T00:00:00.000Z"
    }
  }
}
```

### 6. 搜尋對話記錄

**端點**: `GET /api/mobile/search-conversations/:tenantId`

**參數**:
- `tenantId`: 租戶ID
- `query`: 搜尋關鍵字
- `page`: 頁碼 (預設: 1)
- `limit`: 每頁數量 (預設: 20)

**請求範例**:
```swift
LineAPIClient.shared.searchConversations(
    tenantId: "company_a",
    query: "價格",
    page: 1,
    limit: 20
) { result in
    switch result {
    case .success(let response):
        print("搜尋結果: \(response.results.count) 個")
        for result in response.results {
            print("對話ID: \(result.id)")
        }
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

**回應格式**:
```json
{
  "success": true,
  "data": {
    "query": "價格",
    "results": [
      {
        "id": "line_conv_001",
        "sourceId": "user123",
        "matchingMessages": 2,
        "lastMessage": {
          "content": "價格是多少？",
          "role": "user",
          "timestamp": "2025-01-01T00:00:00.000Z"
        },
        "createdAt": "2025-01-01T00:00:00.000Z",
        "updatedAt": "2025-01-01T00:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

## 錯誤處理

### 錯誤回應格式
```json
{
  "success": false,
  "error": "錯誤訊息"
}
```

### 常見錯誤碼
- `400`: 請求參數錯誤
- `404`: 找不到指定資源
- `500`: 伺服器內部錯誤

### Swift 錯誤處理
```swift
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .noData:
            return "沒有收到資料"
        case .decodingError:
            return "資料解析錯誤"
        case .serverError(let message):
            return message
        }
    }
}
```

## 使用範例

### 完整的 iOS 應用範例

```swift
import SwiftUI

struct ContentView: View {
    @State private var integrations: [LineIntegration] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List(integrations, id: \.tenantId) { integration in
                NavigationLink(destination: ConversationsView(tenantId: integration.tenantId)) {
                    VStack(alignment: .leading) {
                        Text(integration.tenantName)
                            .font(.headline)
                        Text("狀態: \(integration.status)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("LINE 整合")
            .onAppear {
                loadIntegrations()
            }
        }
    }
    
    private func loadIntegrations() {
        isLoading = true
        LineManager.shared.fetchIntegrations { integrations in
            self.integrations = integrations ?? []
            self.isLoading = false
        }
    }
}
```

## 注意事項

1. **網路安全**: 在生產環境中請使用 HTTPS
2. **錯誤處理**: 所有網路請求都應該有適當的錯誤處理
3. **分頁**: 大量資料請使用分頁功能避免效能問題
4. **快取**: 考慮實作本地快取機制提升使用者體驗
5. **重新整理**: 實作下拉重新整理功能

## 部署注意事項

1. 將 `baseURL` 替換為實際的生產環境網址
2. 確保伺服器已正確設定 CORS
3. 測試所有 API 端點在生產環境中的功能
4. 監控 API 使用量和效能 