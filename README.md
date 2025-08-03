# EchoChat API

EchoChat 後端 API 服務，提供聊天機器人、用戶管理、LINE 整合等功能。

## 功能特色

- 🔐 JWT 認證系統
- 💬 AI 聊天機器人
- 📱 LINE 機器人整合
- 👥 用戶管理系統
- 📧 電子郵件驗證
- 🔍 Google Vision API 整合
- 🛡️ 安全性防護 (Helmet, Rate Limiting)

## 快速開始

### 本地開發

1. 安裝依賴
```bash
npm install
```

2. 設定環境變數
```bash
cp .env.example .env
# 編輯 .env 檔案
```

3. 啟動開發伺服器
```bash
npm run dev
```

### 部署到 Render

1. 推送到 GitHub
2. 在 Render 連接 GitHub 倉庫
3. 設定環境變數
4. 部署

## API 端點

### 認證
- `POST /api/login` - 用戶登入
- `POST /api/register` - 用戶註冊
- `POST /api/forgot-password` - 忘記密碼
- `POST /api/reset-password` - 重設密碼

### 聊天
- `POST /api/chat` - 發送聊天訊息
- `GET /api/conversations` - 獲取對話歷史
- `GET /api/conversations/:id` - 獲取特定對話

### 管理
- `GET /api/me` - 獲取當前用戶資訊
- `PUT /api/profile` - 更新用戶資料
- `POST /api/change-password` - 更改密碼

### LINE Webhook
- `POST /api/webhook/line` - LINE 機器人 Webhook

## 環境變數

| 變數名稱 | 說明 | 必填 |
|---------|------|------|
| `NODE_ENV` | 環境模式 | ✅ |
| `PORT` | 伺服器端口 | ✅ |
| `JWT_SECRET` | JWT 密鑰 | ✅ |
| `LINE_CHANNEL_ACCESS_TOKEN` | LINE 頻道存取權杖 | ❌ |
| `LINE_CHANNEL_SECRET` | LINE 頻道密鑰 | ❌ |
| `OPENAI_API_KEY` | OpenAI API 金鑰 | ❌ |
| `EMAIL_USER` | 電子郵件帳號 | ❌ |
| `EMAIL_PASS` | 電子郵件密碼 | ❌ |

## 資料庫

使用 JSON 檔案儲存資料，位於 `data/database.json`。

## 授權

ISC License 