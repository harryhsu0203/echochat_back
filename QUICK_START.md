# 🚀 EchoChat GitHub 工作區快速開始指南

## 📋 前置需求

1. **GitHub 帳號** - 如果沒有，請在 [GitHub](https://github.com) 註冊
2. **Git 設定** - 確保已安裝 Git 並設定用戶資訊

## 🎯 快速設定步驟

### 1. 設定 Git 用戶資訊（如果還沒設定）

```bash
git config --global user.name "您的姓名"
git config --global user.email "您的郵箱"
```

### 2. 在 GitHub 上建立倉庫

1. 登入 GitHub
2. 點擊右上角 "+" → "New repository"
3. 輸入倉庫名稱：`echochat-app`
4. 選擇 "Public" 或 "Private"
5. **不要**勾選 "Initialize this repository with a README"
6. 點擊 "Create repository"
7. 複製倉庫 URL（例如：`https://github.com/username/echochat-app.git`）

### 3. 使用自動設定腳本

```bash
# 執行 GitHub 設定腳本
./scripts/setup-github.sh https://github.com/username/echochat-app.git
```

腳本會自動：
- 檢查 Git 設定
- 設定遠端倉庫
- 提交所有程式碼
- 推送到 GitHub

### 4. 驗證設定

1. 在瀏覽器中開啟您的 GitHub 倉庫
2. 確認所有檔案都已上傳
3. 檢查 GitHub Actions 是否正常運行

## 🔄 使用自動同步功能

### 手動同步

```bash
# 使用預設提交訊息
./scripts/auto-sync.sh

# 使用自訂提交訊息
./scripts/auto-sync.sh "修復登入問題"
```

### Xcode 自動同步

1. 在 Xcode 中開啟專案
2. 選擇專案 → Build Phases
3. 點擊 "+" → New Run Script Phase
4. 設定腳本路徑：`${SRCROOT}/scripts/xcode-sync.sh`
5. 確保在 "Copy Bundle Resources" 之後執行

## 📁 專案結構

```
echochat-app/
├── .github/workflows/     # GitHub Actions 工作流程
├── scripts/               # 自動化腳本
│   ├── auto-sync.sh      # 自動同步腳本
│   ├── xcode-sync.sh     # Xcode 建置後腳本
│   └── setup-github.sh   # GitHub 設定腳本
├── echochat app/          # iOS 應用程式
└── README.md             # 專案說明
```

## 🛠️ 開發工作流程

### 日常開發

1. **開始開發**
   ```bash
   git checkout -b feature/new-feature
   # 進行開發...
   ```

2. **提交變更**
   ```bash
   ./scripts/auto-sync.sh "新增功能: 描述"
   ```

3. **合併到主分支**
   ```bash
   git checkout main
   git merge feature/new-feature
   ./scripts/auto-sync.sh "合併功能分支"
   ```

### 修復問題

```bash
git checkout -b fix/bug-description
# 修復問題...
./scripts/auto-sync.sh "修復問題: 描述"
```

## 🔧 故障排除

### 常見問題

1. **推送失敗**
   - 檢查網路連線
   - 確認 GitHub 倉庫存在
   - 確認有推送權限

2. **腳本權限錯誤**
   ```bash
   chmod +x scripts/*.sh
   ```

3. **Git 用戶資訊未設定**
   ```bash
   git config --global user.name "您的姓名"
   git config --global user.email "您的郵箱"
   ```

### 手動設定遠端倉庫

如果自動腳本失敗，可以手動設定：

```bash
# 添加遠端倉庫
git remote add origin https://github.com/username/echochat-app.git

# 推送到 GitHub
git push -u origin main
```

## 📞 支援

如果遇到問題：

1. 檢查 [README.md](README.md) 中的詳細說明
2. 查看 GitHub 倉庫的 Issues
3. 確認所有前置需求都已滿足

## 🎉 完成！

設定完成後，您就可以：

- ✅ 自動同步程式碼到 GitHub
- ✅ 使用 GitHub Actions 自動建置和測試
- ✅ 與團隊協作開發
- ✅ 追蹤程式碼變更歷史

**開始享受自動化的開發體驗吧！** 🚀 