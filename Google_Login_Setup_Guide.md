# Google 登入設定指南

## 🚀 快速開始

### 1. 後端設定

#### 1.1 安裝依賴
```bash
npm install google-auth-library
```

#### 1.2 設定環境變數
在 `.env` 檔案中加入：
```env
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
```

#### 1.3 在 Google Cloud Console 創建 OAuth 2.0 客戶端 ID

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
   - 選擇應用程式類型：
     - **Web 應用程式**（用於後端 API）
     - **iOS**（用於 iOS App）
     - **Android**（用於 Android App）

5. **設定授權的重新導向 URI**
   - 對於 Web 應用程式：`http://localhost:3000/api/auth/google/callback`
   - 對於生產環境：`https://your-domain.com/api/auth/google/callback`

6. **獲取客戶端 ID**
   - 複製生成的客戶端 ID
   - 將其設定為 `GOOGLE_CLIENT_ID` 環境變數

### 2. iOS 設定

#### 2.1 安裝 Google Sign-In SDK

**使用 CocoaPods：**
```ruby
# Podfile
pod 'GoogleSignIn'
```

然後執行：
```bash
pod install
```

**使用 Swift Package Manager：**
1. 在 Xcode 中選擇您的專案
2. 前往「Package Dependencies」
3. 點擊「+」按鈕
4. 輸入：`https://github.com/google/GoogleSignIn-iOS`
5. 選擇版本並加入

#### 2.2 下載 GoogleService-Info.plist

1. 在 Google Cloud Console 中創建 iOS 應用程式
2. 輸入您的 Bundle ID（例如：`com.yourcompany.yourapp`）
3. 下載 `GoogleService-Info.plist` 檔案
4. 將檔案拖拽到 Xcode 專案中

#### 2.3 設定 URL Scheme

在 `Info.plist` 中加入：
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

#### 2.4 更新 AppDelegate

```swift
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 配置 Google Sign-In
        GoogleSignInManager.shared.configure()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // 處理 Google Sign-In 回調
        return GIDSignIn.sharedInstance.handle(url)
    }
}
```

### 3. 測試 Google 登入

#### 3.1 後端測試

```bash
# 啟動伺服器
node server.js

# 測試 Google 登入 API
curl -X POST http://localhost:3000/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken":"your-google-id-token"}'
```

#### 3.2 iOS 測試

```swift
// 測試 Google 登入
GoogleSignInManager.shared.signIn(presenting: self) { result in
    switch result {
    case .success(let user):
        print("✅ Google 登入成功: \(user.profile?.name ?? "Unknown")")
        
        // 使用 EchoChat API 進行登入
        if let idToken = user.idToken?.tokenString {
            EchoChatAPIClient.shared.loginWithGoogle(idToken: idToken) { result in
                switch result {
                case .success(let response):
                    print("✅ API 登入成功: \(response.user.name)")
                case .failure(let error):
                    print("❌ API 登入失敗: \(error.localizedDescription)")
                }
            }
        }
        
    case .failure(let error):
        print("❌ Google 登入失敗: \(error.localizedDescription)")
    }
}
```

## 🔧 常見問題

### Q: 如何獲取 Google ID Token？
A: 在 iOS 中，使用 Google Sign-In SDK 登入成功後，可以從 `user.idToken?.tokenString` 獲取。

### Q: 如何處理 Google 登入錯誤？
A: 常見錯誤包括：
- **網路錯誤**：檢查網路連接
- **憑證錯誤**：確認 GoogleService-Info.plist 正確
- **Bundle ID 錯誤**：確認 Bundle ID 與 Google Cloud Console 設定一致

### Q: 如何測試 Google 登入？
A: 在開發階段，您可以使用測試帳號。在生產環境中，需要將應用程式提交給 Google 審核。

### Q: 如何處理登出？
A: 需要同時登出 Google 和清除本地 Token：
```swift
// 登出 Google
GoogleSignInManager.shared.signOut()

// 清除本地資料
UserDefaults.standard.removeObject(forKey: "authToken")
EchoChatAPIClient.shared.logout()
```

## 📱 完整實作範例

### 登入頁面
```swift
class LoginViewController: UIViewController {
    
    @IBOutlet weak var googleSignInButton: GIDSignInButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGoogleSignIn()
    }
    
    private func setupGoogleSignIn() {
        googleSignInButton.style = .wide
        googleSignInButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
    }
    
    @objc private func googleSignInTapped() {
        GoogleSignInManager.shared.signIn(presenting: self) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.handleGoogleSignInSuccess(user)
                case .failure(let error):
                    self?.showAlert(title: "登入失敗", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func handleGoogleSignInSuccess(_ user: GIDGoogleUser) {
        guard let idToken = user.idToken?.tokenString else {
            showAlert(title: "錯誤", message: "無法獲取 Google ID Token")
            return
        }
        
        // 使用 API 進行登入
        EchoChatAPIClient.shared.loginWithGoogle(idToken: idToken) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // 儲存用戶資訊
                    UserDefaults.standard.set(response.token, forKey: "authToken")
                    UserDefaults.standard.set(response.user.name, forKey: "userName")
                    UserDefaults.standard.set("google", forKey: "loginMethod")
                    
                    // 導航到主畫面
                    self?.navigateToMainScreen()
                    
                case .failure(let error):
                    self?.showAlert(title: "登入失敗", message: error.localizedDescription)
                }
            }
        }
    }
}
```

### 設定頁面
```swift
class SettingsViewController: UIViewController {
    
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var logoutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadUserProfile()
    }
    
    private func loadUserProfile() {
        // 載入用戶資訊
        if let name = UserDefaults.standard.string(forKey: "userName") {
            userNameLabel.text = name
        }
        
        // 如果是 Google 登入，載入頭像
        if UserDefaults.standard.string(forKey: "loginMethod") == "google",
           let pictureURL = UserDefaults.standard.string(forKey: "userPicture"),
           let url = URL(string: pictureURL) {
            loadImage(from: url)
        }
    }
    
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "確認登出", message: "確定要登出嗎？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "登出", style: .destructive) { _ in
            self.performLogout()
        })
        present(alert, animated: true)
    }
    
    private func performLogout() {
        // 登出 Google
        GoogleSignInManager.shared.signOut()
        
        // 清除本地資料
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "loginMethod")
        
        // 清除 API Token
        EchoChatAPIClient.shared.logout()
        
        // 導航回登入畫面
        navigateToLoginScreen()
    }
}
```

## 🔒 安全性注意事項

1. **保護客戶端 ID**：不要在客戶端程式碼中暴露敏感資訊
2. **驗證 ID Token**：後端必須驗證 Google ID Token
3. **HTTPS**：生產環境必須使用 HTTPS
4. **Token 過期**：定期檢查和更新 Token
5. **錯誤處理**：妥善處理各種錯誤情況

## 📞 支援

如果遇到問題，請檢查：
1. Google Cloud Console 設定是否正確
2. Bundle ID 是否匹配
3. GoogleService-Info.plist 是否正確加入專案
4. 網路連接是否正常
5. 環境變數是否正確設定

更多詳細資訊請參考：
- [Google Sign-In iOS 文檔](https://developers.google.com/identity/sign-in/ios)
- [Google Auth Library Node.js 文檔](https://github.com/googleapis/google-auth-library-nodejs) 