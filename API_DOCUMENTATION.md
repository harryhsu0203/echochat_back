# EchoChat API 文檔 - iOS 原生 App 串接指南

## 📱 基本資訊

- **Base URL**: `https://your-api-url.onrender.com/api` (生產環境)
- **Base URL**: `http://localhost:3000/api` (開發環境)
- **Content-Type**: `application/json`
- **認證方式**: JWT Bearer Token

## 🔐 認證相關

### 1. 用戶登入
**POST** `/login`

**請求參數:**
```json
{
  "username": "string",
  "password": "string"
}
```

**成功回應:**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "sunnyharry1",
    "name": "系統管理員",
    "role": "admin"
  }
}
```

**錯誤回應:**
```json
{
  "success": false,
  "error": "用戶名或密碼錯誤"
}
```

### 1.1. Google 登入
**POST** `/auth/google`

**請求參數:**
```json
{
  "idToken": "google-id-token"
}
```

**成功回應:**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 2,
    "username": "user123",
    "name": "John Doe",
    "role": "user",
    "email": "user@gmail.com",
    "picture": "https://lh3.googleusercontent.com/...",
    "loginMethod": "google"
  }
}
```

**錯誤回應:**
```json
{
  "success": false,
  "error": "Google 登入驗證失敗"
}
```

### 2. 發送電子郵件驗證碼
**POST** `/send-verification-code`

**請求參數:**
```json
{
  "email": "user@example.com"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "驗證碼已發送到您的電子郵件",
  "code": "123456"  // 郵件服務不可用時會返回驗證碼
}
```

### 3. 驗證電子郵件驗證碼
**POST** `/verify-code`

**請求參數:**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "電子郵件驗證成功"
}
```

### 4. 用戶註冊
**POST** `/register`

**請求參數:**
```json
{
  "username": "string",
  "email": "user@example.com",
  "password": "string"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "註冊成功"
}
```

### 5. 忘記密碼
**POST** `/forgot-password`

**請求參數:**
```json
{
  "email": "user@example.com"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "驗證碼已發送到您的電子郵件",
  "code": "123456"  // 郵件服務不可用時會返回驗證碼
}
```

### 6. 重設密碼
**POST** `/reset-password`

**請求參數:**
```json
{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "newpassword123"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "密碼重設成功"
}
```

## 👤 用戶管理

### 7. 獲取當前用戶資訊
**GET** `/me`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "sunnyharry1",
    "name": "系統管理員",
    "role": "admin"
  }
}
```

### 8. 獲取個人資料
**GET** `/profile`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "profile": {
    "id": 1,
    "username": "sunnyharry1",
    "name": "系統管理員",
    "role": "admin"
  }
}
```

### 9. 更新個人資料
**POST** `/profile`

**Headers:**
```
Authorization: Bearer <token>
```

**請求參數:**
```json
{
  "name": "新顯示名稱"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "個人資料更新成功"
}
```

### 10. 更改密碼
**POST** `/change-password`

**Headers:**
```
Authorization: Bearer <token>
```

**請求參數:**
```json
{
  "currentPassword": "舊密碼",
  "newPassword": "新密碼"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "密碼更改成功"
}
```

### 11. 刪除帳號
**POST** `/delete-account`

**Headers:**
```
Authorization: Bearer <token>
```

**請求參數:**
```json
{
  "password": "確認密碼"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "帳號已刪除"
}
```

## 🤖 AI 聊天功能

### 12. 發送聊天訊息
**POST** `/chat`

**Headers:**
```
Authorization: Bearer <token>
```

**請求參數:**
```json
{
  "message": "用戶訊息",
  "conversationId": "可選，對話ID"
}
```

**成功回應:**
```json
{
  "success": true,
  "response": "AI 回應",
  "conversationId": "conv_123456",
  "timestamp": "2025-01-03T15:30:00.000Z"
}
```

### 13. 獲取對話歷史
**GET** `/conversations`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "conversations": [
    {
      "id": "conv_123456",
      "platform": "app",
      "messages": [
        {
          "role": "user",
          "content": "用戶訊息",
          "timestamp": "2025-01-03T15:30:00.000Z"
        },
        {
          "role": "assistant",
          "content": "AI 回應",
          "timestamp": "2025-01-03T15:30:05.000Z"
        }
      ],
      "createdAt": "2025-01-03T15:30:00.000Z",
      "updatedAt": "2025-01-03T15:30:05.000Z"
    }
  ]
}
```

### 14. 獲取特定對話
**GET** `/conversations/{conversationId}`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "conversation": {
    "id": "conv_123456",
    "platform": "app",
    "messages": [...],
    "createdAt": "2025-01-03T15:30:00.000Z",
    "updatedAt": "2025-01-03T15:30:05.000Z"
  }
}
```

### 15. 刪除對話
**DELETE** `/conversations/{conversationId}`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "message": "對話已刪除"
}
```

## ⚙️ AI 助理配置

### 16. 獲取 AI 助理配置
**GET** `/ai-assistant-config`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "config": {
    "assistant_name": "AI 美髮助理",
    "llm": "gpt-4o-mini",
    "use_case": "customer-service",
    "description": "我是您的專業美髮助理，很高興為您服務！"
  }
}
```

### 17. 更新 AI 助理配置
**POST** `/ai-assistant-config`

**Headers:**
```
Authorization: Bearer <token>
```

**請求參數:**
```json
{
  "assistant_name": "新助理名稱",
  "llm": "gpt-4o-mini",
  "use_case": "customer-service",
  "description": "新的助理描述"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "AI 助理配置已更新"
}
```

### 18. 重設 AI 助理配置
**POST** `/ai-assistant-config/reset`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "message": "AI 助理配置已重設為預設值"
}
```

### 19. 獲取可用的 AI 模型
**GET** `/ai-models`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "models": [
    {
      "id": "gpt-4o-mini",
      "name": "GPT-4o Mini",
      "description": "快速且經濟實惠的模型"
    },
    {
      "id": "gpt-4o",
      "name": "GPT-4o",
      "description": "功能最強大的模型"
    }
  ]
}
```

## 📱 LINE 機器人整合

### 20. 獲取 LINE Token
**GET** `/line-token`

**Headers:**
```
Authorization: Bearer <token>
```

**成功回應:**
```json
{
  "success": true,
  "lineConfig": {
    "channelAccessToken": "LINE_CHANNEL_ACCESS_TOKEN",
    "channelSecret": "LINE_CHANNEL_SECRET"
  }
}
```

### 21. 更新 LINE Token
**POST** `/line-token`

**Headers:**
```
Authorization: Bearer <token>
```

**請求參數:**
```json
{
  "channelAccessToken": "新的 LINE Channel Access Token",
  "channelSecret": "新的 LINE Channel Secret"
}
```

**成功回應:**
```json
{
  "success": true,
  "message": "LINE 配置已更新"
}
```

## 🔍 系統功能

### 22. 健康檢查
**GET** `/health`

**成功回應:**
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2025-01-03T15:30:00.000Z",
  "version": "1.0.0"
}
```

## 📋 iOS 串接範例

### Swift 網路請求範例

```swift
import Foundation

class EchoChatAPI {
    static let shared = EchoChatAPI()
    private let baseURL = "https://your-api-url.onrender.com/api"
    private var authToken: String?
    
    // 登入
    func login(username: String, password: String, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(LoginResponse.self, from: data)
                    self.authToken = response.token
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // 發送聊天訊息
    func sendMessage(_ message: String, conversationId: String? = nil, completion: @escaping (Result<ChatResponse, Error>) -> Void) {
        guard let token = authToken else {
            completion(.failure(APIError.noAuthToken))
            return
        }
        
        let url = URL(string: "\(baseURL)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = ["message": message]
        if let conversationId = conversationId {
            body["conversationId"] = conversationId
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// 回應模型
struct LoginResponse: Codable {
    let success: Bool
    let token: String
    let user: User
}

struct User: Codable {
    let id: Int
    let username: String
    let name: String
    let role: String
}

struct ChatResponse: Codable {
    let success: Bool
    let response: String
    let conversationId: String
    let timestamp: String
}

enum APIError: Error {
    case noAuthToken
    case invalidResponse
}
```

### 使用範例

```swift
// 登入
EchoChatAPI.shared.login(username: "sunnyharry1", password: "gele1227") { result in
    switch result {
    case .success(let response):
        print("登入成功: \(response.user.name)")
    case .failure(let error):
        print("登入失敗: \(error)")
    }
}

// 發送聊天訊息
EchoChatAPI.shared.sendMessage("你好，我想詢問染髮的價格") { result in
    switch result {
    case .success(let response):
        print("AI 回應: \(response.response)")
    case .failure(let error):
        print("發送失敗: \(error)")
    }
}
```

## ⚠️ 注意事項

1. **認證**: 除了登入、註冊、忘記密碼等公開端點外，其他 API 都需要在 Header 中帶入 JWT Token
2. **錯誤處理**: 所有 API 都會返回統一的錯誤格式
3. **郵件服務**: 電子郵件驗證碼功能在郵件服務不可用時會直接返回驗證碼
4. **CORS**: API 已配置支援 iOS App 的跨域請求
5. **Rate Limiting**: API 有速率限制，請避免過於頻繁的請求

## 🔧 環境變數設定

確保以下環境變數已正確設定：
- `JWT_SECRET`: JWT 密鑰
- `OPENAI_API_KEY`: OpenAI API 金鑰
- `EMAIL_USER`: 電子郵件帳號
- `EMAIL_PASS`: 電子郵件密碼
- `LINE_CHANNEL_ACCESS_TOKEN`: LINE 機器人 Token
- `LINE_CHANNEL_SECRET`: LINE 機器人 Secret
- `GOOGLE_CLIENT_ID`: Google OAuth 客戶端 ID 