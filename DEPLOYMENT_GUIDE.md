# EchoChat API 部署指南

## 🚀 部署到 Render

### 步驟 1: 準備 GitHub 倉庫

1. **建立新的 GitHub 倉庫**
   ```bash
   git init
   git add .
   git commit -m "Initial commit: EchoChat API"
   git branch -M main
   git remote add origin https://github.com/your-username/echochat-api.git
   git push -u origin main
   ```

### 步驟 2: 在 Render 部署

1. **登入 Render**
   - 前往 https://render.com
   - 使用 GitHub 帳號登入

2. **建立新服務**
   - 點擊 "New +"
   - 選擇 "Web Service"
   - 連接您的 GitHub 倉庫

3. **配置服務**
   - **Name**: `echochat-api`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: `Starter` (或 Free)

### 步驟 3: 設定環境變數

在 Render 服務設定中，添加以下環境變數：

| 變數名稱 | 值 | 說明 |
|---------|-----|------|
| `NODE_ENV` | `production` | 環境模式 |
| `JWT_SECRET` | (自動生成) | JWT 密鑰 |
| `PORT` | `10000` | 伺服器端口 |
| `DATA_DIR` | `/opt/render/project/src/data` | 資料目錄 |
| `LINE_CHANNEL_ACCESS_TOKEN` | (可選，系統預設) | LINE 機器人 Token |
| `LINE_CHANNEL_SECRET` | (可選，系統預設) | LINE 機器人 Secret |
| `OPENAI_API_KEY` | (您的 OpenAI Key) | OpenAI API 金鑰 |
| `EMAIL_USER` | `echochatsup@gmail.com` | 電子郵件帳號 |
| `EMAIL_PASS` | (您的 Email 密碼) | 電子郵件密碼 |
| `GOOGLE_APPLICATION_CREDENTIALS` | `/opt/render/project/src/credentials/google-vision-credentials.json` | Google Vision 憑證路徑 |

### 步驟 4: 部署

1. 點擊 "Create Web Service"
2. 等待部署完成
3. 獲取您的 API URL (例如: `https://echochat-api.onrender.com`)

## 🔧 本地開發

### 安裝依賴
```bash
npm install
```

### 設定環境變數
```bash
cp env.example .env
# 編輯 .env 檔案
```

### 啟動開發伺服器
```bash
npm run dev
```

### 測試 API
```bash
# 健康檢查
curl http://localhost:3000/api/health

# 登入測試
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sunnyharry1","password":"admin123"}'
```

## 📋 API 端點測試

### 健康檢查
```bash
curl https://your-api-url.onrender.com/api/health
```

### 登入
```bash
curl -X POST https://your-api-url.onrender.com/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sunnyharry1","password":"admin123"}'
```

### 獲取用戶資訊
```bash
curl -X GET https://your-api-url.onrender.com/api/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 🔗 前端整合

### 更新 API 配置

在您的前端專案中，更新 `public/js/api-config.js`：

```javascript
const API_CONFIG = {
    development: 'http://localhost:3000/api',
    production: 'https://your-api-url.onrender.com/api',  // 替換為您的 Render URL
    staging: 'https://your-staging-url.onrender.com/api'
};
```

### 測試前端連接

1. 更新前端 API 配置
2. 部署前端到 Vercel/Netlify
3. 測試登入功能

## 🛠️ 故障排除

### 常見問題

1. **部署失敗**
   - 檢查 `package.json` 中的依賴
   - 確認 `render.yaml` 配置正確
   - 查看 Render 日誌

2. **CORS 錯誤**
   - 確認前端域名已加入 CORS 設定
   - 檢查 `server.js` 中的 CORS 配置

3. **環境變數問題**
   - 確認所有必要的環境變數已設定
   - 檢查變數名稱是否正確

4. **資料庫問題**
   - 確認 `data/` 目錄存在
   - 檢查檔案權限

### 日誌查看

在 Render 控制台中：
1. 點擊您的服務
2. 前往 "Logs" 標籤
3. 查看即時日誌

## 📞 支援

如有問題，請檢查：
1. Render 服務狀態
2. 環境變數設定
3. API 端點回應
4. 前端 CORS 設定 