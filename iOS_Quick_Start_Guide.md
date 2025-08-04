# iOS 快速開始指南 - EchoChat API 整合

## 🚀 快速開始

### 1. 準備工作

1. **確保 API 伺服器正在運行**
   ```bash
   # 本地開發
   http://localhost:3000/api
   
   # 生產環境
   https://your-api-url.onrender.com/api
   ```

2. **下載必要檔案**
   - `EchoChatAPIClient.swift` - API 客戶端類別
   - `API_DOCUMENTATION.md` - 完整 API 文檔

### 2. 加入專案

1. **將 `EchoChatAPIClient.swift` 加入您的 iOS 專案**
   - 在 Xcode 中右鍵點擊專案
   - 選擇 "Add Files to [專案名稱]"
   - 選擇 `EchoChatAPIClient.swift`

2. **設定 Base URL**
   ```swift
   // 在 EchoChatAPIClient.swift 中修改
   init(baseURL: String = "https://your-api-url.onrender.com/api") {
       self.baseURL = baseURL
   }
   ```

### 3. 基本使用

#### 傳統登入功能
```swift
import Foundation

class LoginViewController: UIViewController {
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        EchoChatAPIClient.shared.login(username: "sunnyharry1", password: "gele1227") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("登入成功: \(response.user.name)")
                    // 儲存 Token
                    UserDefaults.standard.set(response.token, forKey: "authToken")
                    
                case .failure(let error):
                    print("登入失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}
```

#### Google 登入功能
```swift
import GoogleSignIn

class LoginViewController: UIViewController {
    
    @IBOutlet weak var googleSignInButton: GIDSignInButton!
    
    @IBAction func googleSignInButtonTapped(_ sender: GIDSignInButton) {
        GoogleSignInManager.shared.signIn(presenting: self) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    // 獲取 Google ID Token
                    if let idToken = user.idToken?.tokenString {
                        // 使用 EchoChat API 進行 Google 登入
                        EchoChatAPIClient.shared.loginWithGoogle(idToken: idToken) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let response):
                                    print("Google 登入成功: \(response.user.name)")
                                    // 儲存 Token 和用戶資訊
                                    UserDefaults.standard.set(response.token, forKey: "authToken")
                                    UserDefaults.standard.set(response.user.email, forKey: "userEmail")
                                    UserDefaults.standard.set("google", forKey: "loginMethod")
                                    
                                case .failure(let error):
                                    print("Google 登入失敗: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("Google 登入失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}
```

#### 聊天功能
```swift
class ChatViewController: UIViewController {
    
    func sendMessage(_ message: String) {
        EchoChatAPIClient.shared.sendMessage(message) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("AI 回應: \(response.response)")
                    
                case .failure(let error):
                    print("發送失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}
```

### 4. 完整功能實作

#### 用戶認證流程
```swift
// 1. 檢查登入狀態
if EchoChatAPIClient.shared.isLoggedIn {
    // 已登入，進入主畫面
    navigateToMainScreen()
} else {
    // 未登入，顯示登入畫面
    showLoginScreen()
}

// 2. 登入
EchoChatAPIClient.shared.login(username: username, password: password) { result in
    // 處理登入結果
}

// 3. 登出
EchoChatAPIClient.shared.logout()
UserDefaults.standard.removeObject(forKey: "authToken")
```

#### 註冊流程
```swift
// 完整註冊流程（包含電子郵件驗證）
EchoChatAPIClient.shared.registerFlow(username: username, email: email, password: password) { result in
    DispatchQueue.main.async {
        switch result {
        case .success(_):
            showAlert(title: "註冊成功", message: "請使用新帳號登入")
            
        case .failure(let error):
            showAlert(title: "註冊失敗", message: error.localizedDescription)
        }
    }
}
```

#### 忘記密碼流程
```swift
// 完整忘記密碼流程
EchoChatAPIClient.shared.forgotPasswordFlow(email: email) { result in
    DispatchQueue.main.async {
        switch result {
        case .success(_):
            showAlert(title: "密碼重設成功", message: "請使用新密碼登入")
            
        case .failure(let error):
            showAlert(title: "密碼重設失敗", message: error.localizedDescription)
        }
    }
}
```

### 5. 錯誤處理

```swift
enum EchoChatAPIError: Error, LocalizedError {
    case noAuthToken
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case notFound
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAuthToken:
            return "未提供認證 Token"
        case .unauthorized:
            return "認證失敗，請重新登入"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .validationError(let message):
            return "驗證錯誤: \(message)"
        default:
            return "未知錯誤"
        }
    }
}
```

### 6. 網路狀態監控

```swift
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    
    var isConnected: Bool = false
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if self?.isConnected == true {
                    print("網路已連接")
                } else {
                    print("網路已斷開")
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
}

// 在 AppDelegate 中啟動監控
NetworkMonitor.shared.startMonitoring()
```

### 7. 最佳實踐

#### 載入狀態管理
```swift
class BaseViewController: UIViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    func showLoading() {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false
    }
    
    func hideLoading() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        view.isUserInteractionEnabled = true
    }
}
```

#### Token 管理
```swift
class TokenManager {
    static let shared = TokenManager()
    
    private let tokenKey = "authToken"
    
    var currentToken: String? {
        get {
            return UserDefaults.standard.string(forKey: tokenKey)
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }
    
    var isLoggedIn: Bool {
        return currentToken != nil
    }
    
    func logout() {
        currentToken = nil
        EchoChatAPIClient.shared.logout()
    }
}
```

#### 統一錯誤處理
```swift
extension UIViewController {
    
    func handleAPIError(_ error: EchoChatAPIError) {
        switch error {
        case .unauthorized:
            // 清除登入狀態並導航到登入畫面
            TokenManager.shared.logout()
            navigateToLogin()
            
        case .networkError:
            showAlert(title: "網路錯誤", message: "請檢查網路連接")
            
        case .validationError(let message):
            showAlert(title: "驗證錯誤", message: message)
            
        default:
            showAlert(title: "錯誤", message: error.localizedDescription)
        }
    }
    
    private func navigateToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
        loginVC.modalPresentationStyle = .fullScreen
        present(loginVC, animated: true)
    }
}
```

### 8. 測試

#### 健康檢查
```swift
// 測試 API 連接
EchoChatAPIClient.shared.healthCheck { result in
    switch result {
    case .success(let response):
        print("API 健康狀態: \(response.data?["status"] ?? "unknown")")
        
    case .failure(let error):
        print("API 連接失敗: \(error.localizedDescription)")
    }
}
```

#### 測試登入
```swift
// 使用預設管理員帳號測試
EchoChatAPIClient.shared.login(username: "sunnyharry1", password: "gele1227") { result in
    switch result {
    case .success(let response):
        print("✅ 登入測試成功")
        print("用戶: \(response.user.name)")
        print("角色: \(response.user.role)")
        
    case .failure(let error):
        print("❌ 登入測試失敗: \(error.localizedDescription)")
    }
}
```

### 9. 常見問題

#### Q: 如何處理 Token 過期？
A: API 客戶端會自動處理 401 錯誤，您只需要在收到 `.unauthorized` 錯誤時清除本地 Token 並導航到登入畫面。

#### Q: 如何處理網路錯誤？
A: 實作網路狀態監控，在網路斷開時顯示適當的提示訊息。

#### Q: 如何實作自動登入？
A: 在 App 啟動時檢查本地儲存的 Token，如果存在則直接進入主畫面。

#### Q: 如何處理電子郵件驗證？
A: 在開發環境中，驗證碼會直接返回在 API 回應中。在生產環境中，用戶需要檢查電子郵件。

### 10. 部署注意事項

1. **更新 Base URL**: 確保使用正確的生產環境 API URL
2. **設定環境變數**: 確保所有必要的環境變數已正確設定
3. **測試所有功能**: 在部署前測試所有 API 端點
4. **錯誤處理**: 確保所有錯誤情況都有適當的處理
5. **網路狀態**: 實作網路狀態監控和離線處理

### 11. 支援

如果遇到問題，請檢查：
1. API 伺服器是否正在運行
2. 網路連接是否正常
3. Base URL 是否正確
4. 環境變數是否已設定
5. API 文檔中的錯誤代碼

更多詳細資訊請參考 `API_DOCUMENTATION.md`。 