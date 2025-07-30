# EchoChat iOS 應用程式

一個功能完整的 iOS 聊天應用程式，整合了 Line 訊息管理和 AI 助手功能。

## 🚀 功能特色

- **Line 訊息管理**: 整合 Line Webhook，自動接收和管理客戶訊息
- **AI 助手**: 智能回覆建議和自動化客服
- **用戶認證**: 支援 Google Sign-In 和本地帳號管理
- **多角色權限**: 管理員和操作員不同權限等級
- **即時通知**: 新訊息通知和狀態更新
- **響應式設計**: 支援深色模式和自適應佈局

## 📱 系統需求

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0+

## 🛠️ 安裝與設定

### 1. 克隆專案

```bash
git clone <your-github-repo-url>
cd echochat-app
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
3. 參考 `API_PROGRESS_FEATURE.md` 進行詳細設定

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

## 🔄 自動同步系統

專案已設定自動同步到 GitHub 的功能：

### GitHub Actions

- 自動建置和測試
- 支援 main 和 develop 分支
- 建置結果會上傳為 artifacts

### 自動同步腳本

#### 手動同步

```bash
# 使用預設提交訊息
./scripts/auto-sync.sh

# 使用自訂提交訊息
./scripts/auto-sync.sh "修復登入問題"
```

#### Xcode 自動同步

1. 在 Xcode 中開啟專案
2. 選擇專案 → Build Phases
3. 點擊 "+" → New Run Script Phase
4. 設定腳本路徑：`${SRCROOT}/scripts/xcode-sync.sh`
5. 確保在 "Copy Bundle Resources" 之後執行

### 設定 GitHub 遠端倉庫

```bash
# 添加遠端倉庫
git remote add origin <your-github-repo-url>

# 推送到 GitHub
git push -u origin main
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
├── scripts/                      # 自動化腳本
│   ├── auto-sync.sh             # 自動同步腳本
│   └── xcode-sync.sh            # Xcode 建置後腳本
├── .github/workflows/            # GitHub Actions
│   └── ios.yml                  # iOS 建置工作流程
├── .gitignore                   # Git 忽略檔案
└── README.md                    # 專案說明
```

## 🧪 測試

```bash
# 執行單元測試
xcodebuild -project "echochat app.xcodeproj" -scheme "echochat app" -destination "platform=iOS Simulator,name=iPhone 15" test

# 執行 UI 測試
xcodebuild -project "echochat app.xcodeproj" -scheme "echochat app" -destination "platform=iOS Simulator,name=iPhone 15" test -only-testing:echochat_appUITests
```

## 📋 開發工作流程

1. **開發新功能**
   ```bash
   git checkout -b feature/new-feature
   # 進行開發...
   ./scripts/auto-sync.sh "新增功能: 描述"
   ```

2. **修復問題**
   ```bash
   git checkout -b fix/bug-description
   # 修復問題...
   ./scripts/auto-sync.sh "修復問題: 描述"
   ```

3. **合併到主分支**
   ```bash
   git checkout main
   git merge feature/new-feature
   ./scripts/auto-sync.sh "合併功能分支"
   ```

## 🔐 安全性

- `GoogleService-Info.plist` 已加入 `.gitignore`
- 敏感資訊使用環境變數或安全儲存
- 所有 API 金鑰都經過加密處理

## 📄 授權

本專案採用 MIT 授權條款。

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📞 支援

如有問題，請：
1. 查看 [Issues](../../issues)
2. 參考設定文件
3. 聯繫開發團隊

---

**EchoChat** - 讓聊天更智能，讓客服更高效！ 