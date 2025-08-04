# iOS Google 登入整合指南

## 📱 檔案清單

請將以下檔案加入您的 iOS 專案：

1. **`EchoChatAPIClient.swift`** - API 客戶端類別
2. **`GoogleSignIn_Manager.swift`** - Google Sign-In 管理器
3. **`LoginViewController_Google.swift`** - 登入頁面（包含 Google 登入）
4. **`AppDelegate_Google_Setup.swift`** - AppDelegate 設定

## 🔧 安裝步驟

### 1. 安裝 Google Sign-In SDK

#### 使用 CocoaPods（推薦）
```ruby
# Podfile
pod 'GoogleSignIn'
```

執行安裝：
```bash
pod install
```

#### 使用 Swift Package Manager
1. 在 Xcode 中選擇您的專案
2. 前往「Package Dependencies」
3. 點擊「+」按鈕
4. 輸入：`https://github.com/google/GoogleSignIn-iOS`
5. 選擇版本並加入

### 2. Google Cloud Console 設定

1. **前往 Google Cloud Console**
   - 網址：https://console.cloud.google.com/
   - 登入您的 Google 帳號

2. **創建或選擇專案**
   - 點擊頂部的專案選擇器
   - 選擇現有專案或創建新專案

3. **啟用 Google+ API**
   - 前往「API 和服務」>「程式庫」
   - 搜尋「Google+ API」並啟用

4. **創建 OAuth 2.0 客戶端 ID**
   - 前往「API 和服務」>「憑證」
   - 點擊「建立憑證」>「OAuth 2.0 用戶端 ID」
   - 選擇「iOS」應用程式類型
   - 輸入您的 Bundle ID（例如：`com.yourcompany.yourapp`）

5. **下載 GoogleService-Info.plist**
   - 下載生成的 `GoogleService-Info.plist` 檔案
   - 將檔案拖拽到 Xcode 專案中

### 3. iOS 專案設定

#### 在 Info.plist 中加入 URL Scheme
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

**注意：** 將 `YOUR_CLIENT_ID` 替換為您的實際客戶端 ID（從 GoogleService-Info.plist 中獲取）

### 4. 更新 AppDelegate

將 `AppDelegate_Google_Setup.swift` 的內容複製到您的 `AppDelegate.swift` 中。

### 5. 創建登入頁面

將 `LoginViewController_Google.swift` 的內容複製到您的登入頁面中。

### 6. 設定 Storyboard

在 Storyboard 中創建登入頁面，並連接以下 UI 元件：

#### 必需的 UI 元件：
- `logoImageView` (UIImageView)
- `titleLabel` (UILabel)
- `usernameTextField` (UITextField)
- `passwordTextField` (UITextField)
- `loginButton` (UIButton)
- `googleSignInButton` (GIDSignInButton)
- `activityIndicator` (UIActivityIndicatorView)
- `statusLabel` (UILabel)
- `registerButton` (UIButton)
- `forgotPasswordButton` (UIButton)

#### 連接 Actions：
- `loginButtonTapped`
- `googleSignInButtonTapped`
- `registerButtonTapped`
- `forgotPasswordButtonTapped`

## 🚀 使用方式

### 基本使用

```swift
// 在您的 ViewController 中
import GoogleSignIn

class YourViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 配置 Google Sign-In
        GoogleSignInManager.shared.configure()
    }
    
    @IBAction func googleSignInTapped(_ sender: Any) {
        GoogleSignInManager.shared.signIn(presenting: self) { result in
            switch result {
            case .success(let user):
                // 獲取 ID Token
                if let idToken = user.idToken {
                    // 使用 EchoChat API 登入
                    EchoChatAPIClient.shared.loginWithGoogle(idToken: idToken) { result in
                        switch result {
                        case .success(let response):
                            print("登入成功：\(response.user.name)")
                        case .failure(let error):
                            print("登入失敗：\(error.localizedDescription)")
                        }
                    }
                }
                
            case .failure(let error):
                print("Google 登入失敗：\(error.localizedDescription)")
            }
        }
    }
}
```

### 檢查登入狀態

```swift
// 檢查是否已登入
if GoogleSignInManager.shared.isSignedIn() {
    print("用戶已登入 Google")
}

// 獲取當前用戶
if let user = GoogleSignInManager.shared.getCurrentUser() {
    print("用戶名稱：\(user.displayName)")
    print("用戶郵箱：\(user.email)")
}
```

### 登出

```swift
// 登出 Google
GoogleSignInManager.shared.signOut()

// 登出 EchoChat
EchoChatAPIClient.shared.logout()
```

## 🔍 測試

### 1. 編譯測試
確保專案可以正常編譯，沒有錯誤。

### 2. 功能測試
1. 啟動應用程式
2. 點擊 Google 登入按鈕
3. 選擇 Google 帳號
4. 確認成功登入並獲取用戶資訊

### 3. 錯誤處理測試
1. 測試網路連線中斷的情況
2. 測試無效的 ID Token
3. 測試伺服器錯誤回應

## 🛠 故障排除

### 常見問題

1. **編譯錯誤：找不到 GoogleSignIn 模組**
   - 確保已正確安裝 GoogleSignIn SDK
   - 重新執行 `pod install` 或重新加入 SPM 套件

2. **GoogleService-Info.plist 找不到**
   - 確保檔案已加入專案
   - 檢查檔案是否在正確的 Bundle 中

3. **URL Scheme 錯誤**
   - 檢查 Info.plist 中的 URL Scheme 設定
   - 確保 CLIENT_ID 正確

4. **登入失敗**
   - 檢查 Google Cloud Console 設定
   - 確認 Bundle ID 與 OAuth 客戶端 ID 匹配
   - 檢查網路連線

### 除錯技巧

1. **啟用詳細日誌**
```swift
// 在 AppDelegate 中
GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
    if let error = error {
        print("Google Sign-In 錯誤：\(error)")
    }
}
```

2. **檢查網路請求**
```swift
// 在 EchoChatAPIClient 中啟用除錯
print("API 請求：\(endpoint)")
print("請求內容：\(body)")
```

## 📞 支援

如果遇到問題，請檢查：

1. Google Cloud Console 設定
2. iOS 專案設定
3. 網路連線
4. 伺服器端 API 狀態

## 🔐 安全性注意事項

1. **不要將敏感資訊硬編碼**
2. **使用 HTTPS 連線**
3. **妥善處理用戶 Token**
4. **定期更新 SDK 版本**
5. **遵循 Apple 和 Google 的安全準則** 