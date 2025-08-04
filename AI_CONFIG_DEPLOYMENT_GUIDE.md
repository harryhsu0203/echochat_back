# AI 助理配置功能部署指南

## 🔍 **問題分析**

您的 AI 助理配置功能目前**沒有與線上伺服器連結**，原因如下：

1. **線上伺服器缺少 AI 配置端點**：`simple_api_server.js` 中沒有 `/api/ai-assistant-config` 端點
2. **前端嘗試連接但失敗**：`AIAssistantConfigAPIService.swift` 嘗試連接但收到認證錯誤
3. **配置只存在本地**：AI 配置目前只存在 `UserDefaults` 中，沒有與線上伺服器同步

## 🛠️ **已修復的問題**

✅ **添加了完整的 AI 助理配置功能到線上伺服器**：

### 新增的 API 端點
- `GET /api/ai-assistant-config` - 獲取用戶的 AI 配置
- `POST /api/ai-assistant-config` - 更新用戶的 AI 配置
- `POST /api/ai-assistant-config/reset` - 重設為預設配置

### 新增的資料存儲
- `data/ai-config.json` - 存儲所有用戶的 AI 配置
- 持久化存儲，伺服器重啟後配置不會消失
- 每個用戶都有獨立的配置

### 新增的認證機制
- JWT 認證中間件 `authenticateJWT`
- 確保只有登入用戶才能存取自己的配置

### 預設 AI 配置
```json
{
  "aiServiceEnabled": true,
  "selectedAIModel": "客服專家",
  "maxTokens": 1000,
  "temperature": 0.7,
  "systemPrompt": "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。",
  "aiName": "EchoChat 助理",
  "aiPersonality": "友善、專業、耐心",
  "aiSpecialties": "產品諮詢、技術支援、訂單處理",
  "aiResponseStyle": "正式",
  "aiLanguage": "繁體中文",
  "aiAvatar": "robot",
  "maxContextLength": 10,
  "enableResponseFiltering": true,
  "enableSentimentAnalysis": true
}
```

## 🚀 **部署步驟**

### 步驟 1：更新 GitHub 倉庫
```bash
git add .
git commit -m "添加 AI 助理配置功能到線上伺服器"
git push origin main
```

### 步驟 2：在 Render 上重新部署
1. 前往 https://dashboard.render.com/
2. 選擇您的 `echochat-api` 服務
3. 點擊 "Manual Deploy" > "Deploy latest commit"
4. 等待部署完成

### 步驟 3：測試 AI 配置功能
部署完成後，測試以下端點：

```bash
# 1. 檢查資料庫狀態（包含 AI 配置數量）
curl -X GET "https://echochat-api.onrender.com/api/database-status"

# 2. 先登入獲取 token（使用您的帳號）
curl -X POST "https://echochat-api.onrender.com/api/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"shengkai1215@gmail.com","password":"your-password"}'

# 3. 獲取 AI 配置（使用上一步獲得的 token）
curl -X GET "https://echochat-api.onrender.com/api/ai-assistant-config" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# 4. 更新 AI 配置
curl -X POST "https://echochat-api.onrender.com/api/ai-assistant-config" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "aiName": "我的專屬助理",
    "aiPersonality": "幽默、專業、創意",
    "systemPrompt": "你是一個創意十足的助理，請用有趣的方式回答問題。"
  }'
```

## 📱 **前端功能**

部署完成後，您的 iOS 應用程式將能夠：

1. **自動同步配置**：打開 AI 助理配置頁面時自動從線上伺服器載入配置
2. **即時保存**：修改配置後自動保存到線上伺服器
3. **離線支援**：網路斷線時使用本地配置，連線後自動同步
4. **多設備同步**：在不同設備上登入同一帳號，配置會自動同步

## 🔧 **技術架構**

### 資料流程
```
iOS App → AIAssistantConfigAPIService → 線上伺服器 → data/ai-config.json
```

### 認證流程
```
1. 用戶登入 → 獲取 JWT Token
2. 存取 AI 配置 → 在請求標頭中帶上 Bearer Token
3. 伺服器驗證 Token → 返回對應用戶的配置
```

### 同步機制
```
1. 應用啟動時檢查網路狀態
2. 網路正常時從線上載入配置
3. 配置變更時立即同步到線上
4. 網路斷線時使用本地快取
```

## ✅ **預期結果**

部署完成後，您應該看到：

1. **資料庫狀態端點**顯示 AI 配置數量
2. **AI 配置端點**正常回應（需要有效 token）
3. **iOS 應用**能夠正常同步 AI 配置
4. **多設備**配置自動同步

## 🎯 **立即行動**

請按照上述步驟更新線上伺服器，這樣您的 AI 助理配置功能就能完全正常運作，並且支援多設備同步！ 