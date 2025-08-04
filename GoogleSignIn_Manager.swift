import Foundation
import GoogleSignIn
import UIKit

// MARK: - Google Sign-In 管理器
class GoogleSignInManager {
    static let shared = GoogleSignInManager()
    private init() {}
    
    // MARK: - 配置
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
    
    // MARK: - 登入
    func signIn(presenting viewController: UIViewController, completion: @escaping (Result<GIDGoogleUser, Error>) -> Void) {
        guard let windowScene = viewController.view.window?.windowScene else {
            completion(.failure(GoogleSignInError.noWindowScene))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(GoogleSignInError.noUser))
                return
            }
            
            completion(.success(user))
        }
    }
    
    // MARK: - 登出
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        print("✅ Google Sign-In 登出完成")
    }
    
    // MARK: - 檢查登入狀態
    func isSignedIn() -> Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    // MARK: - 獲取當前用戶
    func getCurrentUser() -> GIDGoogleUser? {
        return GIDSignIn.sharedInstance.currentUser
    }
    
    // MARK: - 恢復登入狀態
    func restorePreviousSignIn(completion: @escaping (Result<GIDGoogleUser, Error>) -> Void) {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = user else {
                completion(.failure(GoogleSignInError.noUser))
                return
            }
            
            completion(.success(user))
        }
    }
    
    // MARK: - 撤銷存取權限
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
        GIDSignIn.sharedInstance.disconnect { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

// MARK: - Google Sign-In 錯誤類型
enum GoogleSignInError: Error, LocalizedError {
    case noWindowScene
    case noUser
    case noIdToken
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .noWindowScene:
            return "無法獲取視窗場景"
        case .noUser:
            return "無法獲取用戶資訊"
        case .noIdToken:
            return "無法獲取 ID Token"
        case .configurationError:
            return "Google Sign-In 配置錯誤"
        }
    }
}

// MARK: - Google 用戶資訊擴展
extension GIDGoogleUser {
    var displayName: String {
        return profile?.name ?? "未知用戶"
    }
    
    var email: String {
        return profile?.email ?? ""
    }
    
    var profileImageURL: URL? {
        return profile?.imageURL(withDimension: 100)
    }
    
    var idToken: String? {
        return idToken?.tokenString
    }
} 