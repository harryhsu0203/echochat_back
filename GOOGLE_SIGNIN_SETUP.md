# Google登入完整設置指南

## 概述

本指南將幫助您在EchoChat應用程式中完整配置Google登入功能。目前應用程式使用模擬的Google登入功能，要啟用真實的Google登入，請按照以下步驟進行設置。

## 當前狀態

✅ **已完成的功能：**
- Google登入按鈕UI
- 模擬Google登入流程
- 用戶資料處理
- 錯誤處理

⚠️ **需要配置的部分：**
- Google Cloud Project設置
- 真實的Google Sign-In SDK
- OAuth 2.0憑證配置

## 步驟1：創建Google Cloud Project

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 創建新專案或選擇現有專案
3. 在左側選單中選擇「API和服務」→「啟用的API和服務」
4. 點擊「+ 啟用 API 和服務」
5. 搜尋並啟用以下API：
   - Google+ API
   - Google Sign-In API

## 步驟2：配置OAuth 2.0憑證

1. 在Google Cloud Console中，前往「API和服務」→「憑證」
2. 點擊「建立憑證」→「OAuth 2.0 用戶端 ID」
3. 選擇「iOS」應用程式類型
4. 輸入您的Bundle ID（例如：com.yourcompany.echochat-app）
5. 點擊「建立」
6. 下載生成的plist文件

## 步驟3：安裝Google Sign-In SDK

### 方法A：使用Swift Package Manager（推薦）

1. 在Xcode中，選擇您的專案
2. 點擊「Package Dependencies」標籤
3. 點擊「+」按鈕
4. 輸入URL：`https://github.com/google/GoogleSignIn-iOS.git`
5. 選擇版本（建議使用最新穩定版）
6. 選擇以下產品：
   - GoogleSignIn
   - GoogleSignInSwift

### 方法B：使用CocoaPods

1. 在專案根目錄創建Podfile文件
2. 添加以下內容：

```ruby
platform :ios, '17.0'

target 'echochat app' do
  use_frameworks!
  
  pod 'GoogleSignIn'
end
```

3. 在終端機中運行：
```bash
pod install
```

## 步驟4：配置專案設置

### 4.1 添加GoogleService-Info.plist

1. 將下載的plist文件重命名為 `GoogleService-Info.plist`
2. 將文件拖拽到Xcode專案中
3. 確保在「Add to target」對話框中選擇了您的應用程式目標

### 4.2 配置URL Schemes

1. 在Xcode中，選擇您的專案
2. 選擇您的目標
3. 點擊「Info」標籤
4. 展開「URL Types」
5. 點擊「+」按鈕
6. 在「URL Schemes」中輸入您的REVERSED_CLIENT_ID
   （從GoogleService-Info.plist中的REVERSED_CLIENT_ID獲取）

### 4.3 更新Info.plist

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

## 步驟5：更新代碼

### 5.1 替換GoogleAuthService

將 `GoogleAuthService.swift` 中的模擬代碼替換為真實的Google Sign-In實現：

```swift
import GoogleSignIn
import GoogleSignInSwift

class GoogleAuthService: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var currentUser: GoogleUser?
    
    init() {
        setupGoogleSignIn()
    }
    
    private func setupGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("無法載入Google服務配置")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        
        // 檢查是否有已登入的用戶
        if let user = GIDSignIn.sharedInstance.currentUser {
            self.currentUser = GoogleUser(from: user)
            self.isSignedIn = true
        }
    }
    
    func signIn() async throws -> GoogleUser {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw GoogleAuthError.presentationError
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = GoogleUser(from: result.user)
            
            await MainActor.run {
                self.currentUser = user
                self.isSignedIn = true
            }
            
            return user
        } catch {
            throw GoogleAuthError.signInFailed(error.localizedDescription)
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        
        Task { @MainActor in
            self.currentUser = nil
            self.isSignedIn = false
        }
    }
    
    func restoreSignIn() async throws -> GoogleUser? {
        do {
            let result = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let user = GoogleUser(from: result)
            
            await MainActor.run {
                self.currentUser = user
                self.isSignedIn = true
            }
            
            return user
        } catch {
            return nil
        }
    }
}

struct GoogleUser {
    let id: String
    let email: String
    let name: String
    let givenName: String?
    let familyName: String?
    let profileImageURL: URL?
    
    init(from user: GIDGoogleUser) {
        self.id = user.userID ?? ""
        self.email = user.profile?.email ?? ""
        self.name = user.profile?.name ?? ""
        self.givenName = user.profile?.givenName
        self.familyName = user.profile?.familyName
        self.profileImageURL = user.profile?.imageURL(withDimension: 100)
    }
}
```

### 5.2 更新AppDelegate（如果需要）

在 `App.swift` 中添加URL處理：

```swift
import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct echochat_appApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                ChatMessage.self,
                Conversation.self,
                LineMessage.self,
                LineConversation.self,
                User.self,
                Channel.self,
                AIConfiguration.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
```

## 步驟6：測試

1. 清理並重新建置專案
2. 運行應用程式
3. 在登入頁面點擊「使用Google登入」按鈕
4. 應該會彈出Google登入視窗
5. 選擇Google帳號並授權

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

4. **編譯錯誤**
   - 確保已正確安裝Google Sign-In SDK
   - 檢查import語句
   - 清理並重新建置專案

### 調試技巧

1. 在Xcode控制台中查看詳細錯誤訊息
2. 使用Google Cloud Console的API監控功能
3. 檢查網路請求是否成功
4. 使用Xcode的斷點調試功能

## 安全注意事項

- 永遠不要在客戶端代碼中硬編碼敏感資訊
- 使用適當的錯誤處理
- 考慮實現額外的安全措施，如雙因素認證
- 定期更新Google Sign-In SDK到最新版本
- 在生產環境中使用HTTPS

## 生產環境部署

1. 在Google Cloud Console中配置生產環境的OAuth憑證
2. 更新Bundle ID為生產版本
3. 測試所有功能
4. 提交到App Store

## 支援

如果您遇到問題，可以：

1. 查看 [Google Sign-In iOS 文檔](https://developers.google.com/identity/sign-in/ios)
2. 檢查 [Google Cloud Console](https://console.cloud.google.com/) 的錯誤日誌
3. 在 [Stack Overflow](https://stackoverflow.com/) 上搜尋相關問題 