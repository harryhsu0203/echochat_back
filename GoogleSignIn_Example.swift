import Foundation
import UIKit
import GoogleSignIn

// MARK: - Google 登入範例

class GoogleSignInManager {
    static let shared = GoogleSignInManager()
    
    private init() {}
    
    /// 配置 Google Sign-In
    func configure() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ 無法找到 GoogleService-Info.plist 或 CLIENT_ID")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign-In 配置完成")
    }
    
    /// 檢查是否已登入
    func isSignedIn() -> Bool {
        return GIDSignIn.sharedInstance.hasPreviousSignIn()
    }
    
    /// 恢復登入狀態
    func restoreSignIn(completion: @escaping (Result<GIDGoogleUser, Error>) -> Void) {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = user {
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法恢復登入狀態"])))
            }
        }
    }
    
    /// 執行 Google 登入
    func signIn(presenting viewController: UIViewController, completion: @escaping (Result<GIDGoogleUser, Error>) -> Void) {
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let result = result {
                completion(.success(result.user))
            } else {
                completion(.failure(NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "登入失敗"])))
            }
        }
    }
    
    /// 登出
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        print("✅ Google 登出完成")
    }
    
    /// 撤銷存取權限
    func disconnect(completion: @escaping (Error?) -> Void) {
        GIDSignIn.sharedInstance.disconnect { error in
            completion(error)
        }
    }
}

// MARK: - 整合 EchoChat API 的 Google 登入

class GoogleLoginViewController: UIViewController {
    
    @IBOutlet weak var googleSignInButton: GIDSignInButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        GoogleSignInManager.shared.configure()
    }
    
    private func setupUI() {
        googleSignInButton.style = .wide
        activityIndicator.isHidden = true
        statusLabel.text = "點擊下方按鈕使用 Google 帳號登入"
    }
    
    @IBAction func googleSignInButtonTapped(_ sender: GIDSignInButton) {
        performGoogleSignIn()
    }
    
    private func performGoogleSignIn() {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        statusLabel.text = "正在登入..."
        
        GoogleSignInManager.shared.signIn(presenting: self) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.activityIndicator.isHidden = true
                
                switch result {
                case .success(let user):
                    self?.handleGoogleSignInSuccess(user)
                    
                case .failure(let error):
                    self?.handleGoogleSignInError(error)
                }
            }
        }
    }
    
    private func handleGoogleSignInSuccess(_ user: GIDGoogleUser) {
        guard let idToken = user.idToken?.tokenString else {
            showAlert(title: "登入失敗", message: "無法獲取 Google ID Token")
            return
        }
        
        statusLabel.text = "正在驗證..."
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
        // 使用 EchoChat API 進行 Google 登入
        EchoChatAPIClient.shared.loginWithGoogle(idToken: idToken) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.activityIndicator.isHidden = true
                
                switch result {
                case .success(let response):
                    self?.handleAPILoginSuccess(response)
                    
                case .failure(let error):
                    self?.handleAPILoginError(error)
                }
            }
        }
    }
    
    private func handleAPILoginSuccess(_ response: LoginResponse) {
        // 儲存用戶資訊
        UserDefaults.standard.set(response.token, forKey: "authToken")
        UserDefaults.standard.set(response.user.id, forKey: "userId")
        UserDefaults.standard.set(response.user.name, forKey: "userName")
        UserDefaults.standard.set(response.user.email, forKey: "userEmail")
        UserDefaults.standard.set(response.user.picture, forKey: "userPicture")
        UserDefaults.standard.set("google", forKey: "loginMethod")
        
        statusLabel.text = "登入成功！"
        
        // 顯示成功訊息
        showAlert(title: "登入成功", message: "歡迎回來，\(response.user.name)！") { _ in
            self.navigateToMainScreen()
        }
    }
    
    private func handleAPILoginError(_ error: EchoChatAPIError) {
        statusLabel.text = "登入失敗"
        showAlert(title: "登入失敗", message: error.localizedDescription)
    }
    
    private func handleGoogleSignInError(_ error: Error) {
        statusLabel.text = "Google 登入失敗"
        showAlert(title: "Google 登入失敗", message: error.localizedDescription)
    }
    
    private func navigateToMainScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController")
        mainVC.modalPresentationStyle = .fullScreen
        present(mainVC, animated: true)
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default, handler: completion))
        present(alert, animated: true)
    }
}

// MARK: - App Delegate 整合

extension AppDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 配置 Google Sign-In
        GoogleSignInManager.shared.configure()
        
        // 檢查登入狀態
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            // 已登入，直接進入主畫面
            showMainScreen()
        } else {
            // 未登入，顯示登入畫面
            showLoginScreen()
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // 處理 Google Sign-In 回調
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - 設定頁面 Google 登出

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var logoutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadUserProfile()
    }
    
    private func setupUI() {
        userImageView.layer.cornerRadius = userImageView.frame.width / 2
        userImageView.clipsToBounds = true
        logoutButton.layer.cornerRadius = 8
    }
    
    private func loadUserProfile() {
        // 載入本地儲存的用戶資訊
        if let name = UserDefaults.standard.string(forKey: "userName") {
            userNameLabel.text = name
        }
        
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            userEmailLabel.text = email
        }
        
        if let pictureURL = UserDefaults.standard.string(forKey: "userPicture"),
           let url = URL(string: pictureURL) {
            loadImage(from: url)
        }
        
        // 如果是 Google 登入，也從 API 獲取最新資訊
        if UserDefaults.standard.string(forKey: "loginMethod") == "google" {
            EchoChatAPIClient.shared.getProfile { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        if let user = response.data {
                            self?.userNameLabel.text = user.name
                            self?.userEmailLabel.text = user.email
                            if let pictureURL = user.picture, let url = URL(string: pictureURL) {
                                self?.loadImage(from: url)
                            }
                        }
                    case .failure(let error):
                        print("載入用戶資料失敗: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.userImageView.image = image
                }
            }
        }.resume()
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
        // 清除本地儲存的資料
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userPicture")
        UserDefaults.standard.removeObject(forKey: "loginMethod")
        
        // 清除 API 客戶端的 Token
        EchoChatAPIClient.shared.logout()
        
        // 如果是 Google 登入，也要登出 Google
        if UserDefaults.standard.string(forKey: "loginMethod") == "google" {
            GoogleSignInManager.shared.signOut()
        }
        
        // 導航回登入畫面
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
        loginVC.modalPresentationStyle = .fullScreen
        present(loginVC, animated: true)
    }
}

// MARK: - 使用說明

/*
 使用步驟：
 
 1. 安裝 Google Sign-In SDK：
    pod 'GoogleSignIn'
 
 2. 在 Google Cloud Console 創建 OAuth 2.0 客戶端 ID：
    - 前往 https://console.cloud.google.com/
    - 創建新專案或選擇現有專案
    - 啟用 Google+ API
    - 在憑證頁面創建 OAuth 2.0 客戶端 ID
    - 下載 GoogleService-Info.plist 並加入專案
 
 3. 在 Info.plist 中加入 URL Scheme：
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
 
 4. 在 AppDelegate 中配置：
    - 在 didFinishLaunchingWithOptions 中調用 GoogleSignInManager.shared.configure()
    - 實作 application(_:open:options:) 方法
 
 5. 使用 GoogleSignInManager 進行登入：
    GoogleSignInManager.shared.signIn(presenting: self) { result in
        // 處理登入結果
    }
 
 注意事項：
 - 確保 GoogleService-Info.plist 已正確加入專案
 - 在生產環境中需要設定正確的 Bundle ID
 - 記得處理登出和撤銷存取權限
 - 考慮實作自動登入恢復功能
 */ 