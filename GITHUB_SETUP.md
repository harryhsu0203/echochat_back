# GitHub 設定指南

## 🚀 推送程式碼到 GitHub

### 方法一：使用 GitHub CLI（推薦）

1. **安裝 GitHub CLI**
   ```bash
   # macOS
   brew install gh
   
   # 或從官網下載：https://cli.github.com/
   ```

2. **登入 GitHub**
   ```bash
   gh auth login
   ```

3. **創建倉庫並推送**
   ```bash
   gh repo create echochat-api --public --source=. --remote=origin --push
   ```

### 方法二：手動創建倉庫

1. **在 GitHub 網站創建新倉庫**
   - 前往 https://github.com/new
   - 倉庫名稱：`echochat-api`
   - 選擇 Public 或 Private
   - **不要**初始化 README、.gitignore 或 license

2. **添加遠端倉庫**
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/echochat-api.git
   ```

3. **推送程式碼**
   ```bash
   git branch -M main
   git push -u origin main
   ```

### 方法三：使用 SSH（推薦用於開發）

1. **生成 SSH 金鑰**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **添加 SSH 金鑰到 GitHub**
   - 複製公鑰：`cat ~/.ssh/id_ed25519.pub`
   - 前往 GitHub Settings > SSH and GPG keys
   - 點擊 "New SSH key"

3. **使用 SSH 推送**
   ```bash
   git remote add origin git@github.com:YOUR_USERNAME/echochat-api.git
   git push -u origin main
   ```

## 📋 推送的內容

### ✅ 已包含的功能
- **Google 登入功能**
  - 後端 Google OAuth API
  - iOS Google Sign-In 整合
  - 完整的設定指南
- **用戶管理系統**
  - 傳統登入/註冊
  - 忘記密碼功能
  - JWT 認證
- **AI 聊天功能**
  - OpenAI 整合
  - 對話歷史管理
- **LINE 機器人整合**
  - Webhook 處理
  - Token 管理
- **完整的 API 文檔**
  - 22 個 API 端點
  - iOS 串接範例
  - 快速開始指南

### 🔒 已排除的敏感資訊
- `.env` 檔案
- 實際的 Google Vision 憑證
- 實際的資料庫檔案
- 包含真實密碼的檔案

### 📁 新增的檔案
- `API_DOCUMENTATION.md` - 完整 API 文檔
- `EchoChatAPIClient.swift` - iOS API 客戶端
- `GoogleSignIn_Example.swift` - Google 登入範例
- `Google_Login_Setup_Guide.md` - Google 登入設定指南
- `iOS_Quick_Start_Guide.md` - iOS 快速開始指南
- `iOS_Usage_Examples.swift` - iOS 使用範例
- `credentials/google-vision-credentials.json.example` - 憑證範例
- `data/database.json.example` - 資料庫範例

## 🔧 後續步驟

### 1. 設定環境變數
在 GitHub 倉庫的 Settings > Secrets and variables > Actions 中設定：
- `GOOGLE_CLIENT_ID`
- `JWT_SECRET`
- `OPENAI_API_KEY`
- `EMAIL_USER`
- `EMAIL_PASS`

### 2. 部署到 Render
1. 在 Render 連接 GitHub 倉庫
2. 設定環境變數
3. 部署應用程式

### 3. 更新 iOS 專案
1. 下載 `EchoChatAPIClient.swift`
2. 按照 `Google_Login_Setup_Guide.md` 設定 Google 登入
3. 更新 API Base URL

## 📞 支援

如果遇到問題：
1. 檢查 `.gitignore` 是否正確排除敏感檔案
2. 確認環境變數已正確設定
3. 檢查 GitHub 倉庫權限設定
4. 確認 SSH 金鑰或 Personal Access Token 已設定

## 🔗 相關連結

- [GitHub CLI 文檔](https://cli.github.com/)
- [GitHub SSH 設定](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Render 部署指南](https://render.com/docs/deploy-node-express-app) 