import UIKit
import GoogleSignIn

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 配置 Google Sign-In
        GoogleSignInManager.shared.configure()
        
        // 檢查是否已登入
        checkLoginStatus()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // 處理 Google Sign-In 回調
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - 登入狀態檢查
    private func checkLoginStatus() {
        let defaults = UserDefaults.standard
        let isLoggedIn = defaults.bool(forKey: "isLoggedIn")
        
        if isLoggedIn {
            // 檢查 Token 是否有效
            if let token = defaults.string(forKey: "authToken") {
                EchoChatAPIClient.shared.authToken = token
                
                // 驗證 Token 有效性
                EchoChatAPIClient.shared.getCurrentUser { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(_):
                            // Token 有效，直接進入主畫面
                            self?.showMainScreen()
                        case .failure(_):
                            // Token 無效，清除資料並顯示登入畫面
                            self?.clearUserData()
                            self?.showLoginScreen()
                        }
                    }
                }
            } else {
                showLoginScreen()
            }
        } else {
            showLoginScreen()
        }
    }
    
    // MARK: - 畫面導航
    private func showMainScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController") {
            window?.rootViewController = mainVC
        }
    }
    
    private func showLoginScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") {
            let navController = UINavigationController(rootViewController: loginVC)
            window?.rootViewController = navController
        }
    }
    
    // MARK: - 資料清理
    private func clearUserData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "authToken")
        defaults.removeObject(forKey: "userId")
        defaults.removeObject(forKey: "username")
        defaults.removeObject(forKey: "userName")
        defaults.removeObject(forKey: "userEmail")
        defaults.removeObject(forKey: "userPicture")
        defaults.removeObject(forKey: "loginMethod")
        defaults.set(false, forKey: "isLoggedIn")
        
        // 清除 EchoChat API 客戶端的 Token
        EchoChatAPIClient.shared.logout()
        
        // 清除 Google Sign-In 狀態
        GoogleSignInManager.shared.signOut()
    }
} 