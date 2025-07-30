# Google登入設置指南

## 1. 創建Google Cloud Project

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 創建新專案或選擇現有專案
3. 啟用 Google+ API 和 Google Sign-In API

## 2. 配置OAuth 2.0

1. 在Google Cloud Console中，前往「憑證」頁面
2. 點擊「建立憑證」→「OAuth 2.0 用戶端 ID」
3. 選擇「iOS」應用程式類型
4. 輸入您的Bundle ID（例如：com.yourcompany.echochat-app）
5. 下載生成的plist文件

## 3. 更新GoogleService-Info.plist

1. 將下載的plist文件重命名為 `GoogleService-Info.plist`
2. 將文件添加到Xcode專案中
3. 確保文件被包含在目標中

## 4. 安裝Google Sign-In SDK

### 使用Swift Package Manager

1. 在Xcode中，選擇您的專案
2. 點擊「Package Dependencies」標籤
3. 點擊「+」按鈕
4. 輸入URL：`https://github.com/google/GoogleSignIn-iOS.git`
5. 選擇版本（建議使用最新穩定版）
6. 選擇以下產品：
   - GoogleSignIn
   - GoogleSignInSwift

### 使用CocoaPods（可選）

如果您偏好使用CocoaPods，可以在Podfile中添加：

```ruby
pod 'GoogleSignIn'
```

然後運行 `pod install`

## 5. 配置URL Schemes

1. 在Xcode中，選擇您的專案
2. 選擇您的目標
3. 點擊「Info」標籤
4. 展開「URL Types」
5. 點擊「+」按鈕
6. 在「URL Schemes」中輸入您的REVERSED_CLIENT_ID
   （從GoogleService-Info.plist中獲取）

## 6. 更新Info.plist

在Info.plist中添加以下配置：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 7. 測試Google登入

1. 運行應用程式
2. 在登入頁面點擊「使用Google登入」按鈕
3. 應該會彈出Google登入視窗
4. 選擇Google帳號並授權

## 注意事項

- 確保您的Bundle ID與Google Cloud Console中配置的一致
- 在開發階段，您可能需要將測試設備的UDID添加到OAuth配置中
- 生產環境需要額外的配置和審核

## 故障排除

### 常見問題

1. **「無法載入Google服務配置」錯誤**
   - 確保GoogleService-Info.plist文件已正確添加到專案中
   - 檢查CLIENT_ID是否正確

2. **「無法顯示登入視窗」錯誤**
   - 檢查URL Schemes配置
   - 確保REVERSED_CLIENT_ID正確

3. **「Google登入失敗」錯誤**
   - 檢查網路連線
   - 確認Google Cloud Project配置正確
   - 檢查API是否已啟用

### 調試技巧

1. 在Xcode控制台中查看詳細錯誤訊息
2. 使用Google Cloud Console的API監控功能
3. 檢查網路請求是否成功

## 安全注意事項

- 永遠不要在客戶端代碼中硬編碼敏感資訊
- 使用適當的錯誤處理
- 考慮實現額外的安全措施，如雙因素認證
- 定期更新Google Sign-In SDK到最新版本 