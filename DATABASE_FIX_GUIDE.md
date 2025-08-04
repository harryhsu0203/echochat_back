# 資料庫問題修復指南

## 🔍 問題分析

根據您的描述，線上伺服器存在以下問題：

1. **資料不一致**：註冊時顯示「已被註冊」，忘記密碼時顯示「未註冊」
2. **使用記憶體存儲**：伺服器重啟後資料消失
3. **缺少持久化資料庫**：沒有真正的資料庫存儲

## 🛠️ 解決方案

### 1. 已修復的問題

✅ **添加了持久化資料存儲**
- 使用 JSON 檔案存儲用戶資料
- 使用 JSON 檔案存儲驗證碼
- 伺服器重啟後資料不會消失

✅ **添加了忘記密碼功能**
- `/api/forgot-password` - 發送密碼重設驗證碼
- `/api/reset-password` - 重設密碼
- 統一的錯誤訊息

✅ **添加了資料庫狀態檢查**
- `/api/database-status` - 檢查資料庫狀態
- 顯示用戶數量和詳細資訊

### 2. 需要部署的檔案

需要更新以下檔案到線上伺服器：

1. **`simple_api_server.js`** - 主要伺服器檔案
2. **`package.json`** - 確保依賴正確
3. **`render.yaml`** - 部署配置

### 3. 部署步驟

#### 步驟 1：更新 GitHub 倉庫
```bash
git add .
git commit -m "修復資料庫問題：添加持久化存儲和忘記密碼功能"
git push origin main
```

#### 步驟 2：在 Render 上重新部署
1. 前往 https://dashboard.render.com/
2. 選擇您的 `echochat-api` 服務
3. 點擊 "Manual Deploy" > "Deploy latest commit"
4. 等待部署完成

#### 步驟 3：測試功能
部署完成後，測試以下端點：

```bash
# 檢查資料庫狀態
curl -X GET "https://echochat-api.onrender.com/api/database-status"

# 測試忘記密碼（已註冊的用戶）
curl -X POST "https://echochat-api.onrender.com/api/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{"email":"shengkai1215@gmail.com"}'

# 測試忘記密碼（未註冊的用戶）
curl -X POST "https://echochat-api.onrender.com/api/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{"email":"nonexistent@example.com"}'
```

## 📊 預期結果

修復後，您應該看到：

1. **一致的錯誤訊息**：
   - 註冊時：`"此電子郵件已被註冊"`
   - 忘記密碼時：`"此電子郵件未註冊"`

2. **持久化資料**：
   - 伺服器重啟後用戶資料不會消失
   - 資料庫狀態端點顯示正確的用戶數量

3. **完整的忘記密碼功能**：
   - 可以發送密碼重設驗證碼
   - 可以重設密碼

## 🔧 技術細節

### 資料存儲結構
```
data/
├── users.json          # 用戶資料
└── verification.json   # 驗證碼資料
```

### 新增的 API 端點
- `GET /api/database-status` - 檢查資料庫狀態
- `POST /api/forgot-password` - 發送密碼重設驗證碼
- `POST /api/reset-password` - 重設密碼

### 資料持久化
- 使用 `fs.promises` 進行檔案操作
- 自動創建 `data` 目錄
- 伺服器啟動時自動載入資料
- 資料變更時自動保存

## 🚀 立即行動

請按照上述步驟更新線上伺服器，這樣就能解決資料不一致的問題，並提供完整的用戶管理功能。 