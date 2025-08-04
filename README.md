# EchoChat iOS 應用程式

一個功能完整的 iOS 聊天應用程式，整合了 Line 訊息管理和 AI 助手功能。

## 🚀 功能特色

- **Line 訊息管理**: 整合 Line Webhook，自動接收和管理客戶訊息
- **AI 助手**: 智能回覆建議和自動化客服
- **用戶認證**: 支援 Google Sign-In 和本地帳號管理
- **多角色權限**: 管理員和操作員不同權限等級
- **即時通知**: 新訊息通知和狀態更新
- **響應式設計**: 支援深色模式和自適應佈局

## �� 系統需求

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0+

## 🛠️ 安裝與設定

### 1. 開啟專案

```bash
# 使用 Xcode 開啟專案
open "echochat app.xcodeproj"
```

### 2. 安裝依賴

專案使用 Swift Package Manager 管理依賴，Xcode 會自動下載：

- Google Sign-In SDK
- SwiftData (內建)
- SwiftUI (內建)

### 3. 設定 Google Sign-In

1. 在 [Google Cloud Console](https://console.cloud.google.com/) 建立專案
2. 啟用 Google Sign-In API
3. 下載 `GoogleService-Info.plist` 並放入專案根目錄
4. 參考 `GOOGLE_SETUP.md` 進行詳細設定

### 4. 設定 Line Webhook

1. 在 Line Developers Console 建立 Channel
2. 設定 Webhook URL
3. 參考 `LINE_API_SETUP.md` 進行詳細設定

## 🔧 後端 API 功能

### 認證系統
- `POST /api/login` - 用戶登入
- `POST /api/register` - 用戶註冊
- `POST /api/forgot-password` - 忘記密碼
- `POST /api/reset-password` - 重設密碼
- `POST /api/auth/google` - Google 登入

### 聊天功能
- `POST /api/chat` - 發送聊天訊息
- `GET /api/conversations` - 獲取對話歷史
- `GET /api/conversations/:id` - 獲取特定對話

### 管理功能
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
| `GOOGLE_CLIENT_ID` | Google OAuth 客戶端 ID | ❌ |
| `LINE_CHANNEL_ACCESS_TOKEN` | LINE 頻道存取權杖 | ❌ |
| `LINE_CHANNEL_SECRET` | LINE 頻道密鑰 | ❌ |
| `OPENAI_API_KEY` | OpenAI API 金鑰 | ❌ |
| `EMAIL_USER` | 電子郵件帳號 | ❌ |
| `EMAIL_PASS` | 電子郵件密碼 | ❌ |

## 🔧 開發環境設定

### 預設帳號

系統提供兩個預設帳號用於測試：

- **管理員**: `admin` / `admin123`
- **操作員**: `operator` / `operator123`

### 建置專案

```bash
# 使用 Xcode
open "echochat app.xcodeproj"

# 或使用命令列
xcodebuild -project "echochat app.xcodeproj" -scheme "echochat app" -destination "platform=iOS Simulator,name=iPhone 15" build
```

## 📁 專案結構

```
echochat-app/
├── echochat app/                 # 主要應用程式
│   ├── Models/                   # 資料模型
│   │   ├── User.swift
│   │   ├── ChatMessage.swift
│   │   ├── LineMessage.swift
│   │   ├── Channel.swift
│   │   └── AIConfiguration.swift
│   ├── Services/                 # 服務層
│   │   ├── AuthService.swift
│   │   ├── LineService.swift
│   │   ├── AIService.swift
│   │   └── AppSettingsManager.swift
│   ├── Views/                    # 視圖層
│   │   ├── LoginView.swift
│   │   ├── MainTabView.swift
│   │   ├── LineDashboardView.swift
│   │   ├── ChatView.swift
│   │   └── ...
│   └── echochat_appApp.swift     # 應用程式入口
├── echochat appTests/            # 單元測試
├── echochat appUITests/          # UI 測試
├── API_PROGRESS_FEATURE.md       # API 功能說明
├── GOOGLE_SETUP.md              # Google 設定指南
├── GOOGLE_SIGNIN_SETUP.md       # Google 登入設定
├── SYSTEM_SETTINGS_GUIDE.md     # 系統設定指南
└── README.md                    # 專案說明
```

## 🧪 測試

```bash
# 執行單元測試
xcodebuild -project "echochat app.xcodeproj" -scheme "echochat app" -destination "platform=iOS Simulator,name=iPhone 15" test

# 執行 UI 測試
xcodebuild -project "echochat app.xcodeproj" -scheme "echochat app" -destination "platform=iOS Simulator,name=iPhone 15" test -only-testing:echochat_appUITests
```

## 🔐 安全性

- `GoogleService-Info.plist` 包含敏感資訊，請妥善保管
- 敏感資訊使用環境變數或安全儲存
- 所有 API 金鑰都經過加密處理

## 資料庫

使用 JSON 檔案儲存資料，位於 `data/database.json`。

## 📄 授權

本專案採用 MIT 授權條款。

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📞 支援

如有問題，請：
1. 查看設定文件
2. 檢查系統需求
3. 聯繫開發團隊

---

**EchoChat** - 讓聊天更智能，讓客服更高效！ 
