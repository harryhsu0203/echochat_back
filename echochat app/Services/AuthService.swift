//
//  AuthService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData
import CryptoKit

// MARK: - 認證模式
enum AuthMode {
    case local      // 本地認證（開發/測試用）
    case remote     // 遠端 API 認證（生產環境）
}

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isOnline = false
    
    private let modelContext: ModelContext
    private let apiService = APIService.shared
    private let authMode: AuthMode
    
    init(modelContext: ModelContext, authMode: AuthMode = .remote) {
        self.modelContext = modelContext
        self.authMode = authMode
        checkSavedLogin()
        checkNetworkStatus()
    }
    
    // 檢查是否有保存的登入狀態
    private func checkSavedLogin() {
        if let savedUserId = UserDefaults.standard.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: savedUserId) {
            // 從資料庫查詢用戶
            Task { @MainActor in
                do {
                    let descriptor = FetchDescriptor<User>(predicate: #Predicate<User> { user in
                        user.id == userId
                    })
                    let users = try modelContext.fetch(descriptor)
                    
                    if let user = users.first {
                        self.currentUser = user
                        self.isAuthenticated = true
                    } else {
                        // 用戶不存在，清除保存的ID
                        UserDefaults.standard.removeObject(forKey: "currentUserId")
                    }
                } catch {
                    print("Error fetching saved user: \(error)")
                    // 發生錯誤時清除保存的ID
                    UserDefaults.standard.removeObject(forKey: "currentUserId")
                }
            }
        }
    }
    
    // 檢查網路狀態
    private func checkNetworkStatus() {
        Task {
            let isOnline = await apiService.checkNetworkConnection()
            await MainActor.run {
                self.isOnline = isOnline
            }
        }
    }
    
    // 登入
    func login(username: String, password: String) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        switch authMode {
        case .remote:
            return try await loginWithAPI(username: username, password: password)
        case .local:
            return try await loginLocally(username: username, password: password)
        }
    }
    
    // 遠端 API 登入
    private func loginWithAPI(username: String, password: String) async throws -> Bool {
        do {
            let (user, token) = try await apiService.login(username: username, password: password)
            
            // 在主執行緒上保存用戶到本地資料庫
            await MainActor.run {
                modelContext.insert(user)
                try? modelContext.save()
                
                self.currentUser = user
                self.isAuthenticated = true
                self.isOnline = true
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        } catch {
            // 如果 API 登入失敗，嘗試本地登入作為備用
            if isOnline {
                throw error
            } else {
                return try await loginLocally(username: username, password: password)
            }
        }
    }
    
    // 本地登入
    private func loginLocally(username: String, password: String) async throws -> Bool {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let hashedPassword = hashPassword(password)
        
        // 預設管理員帳號
        if username == "admin" && password == "admin123" {
            await MainActor.run {
                let user = User(
                    username: username,
                    email: "admin@echochat.com",
                    passwordHash: hashedPassword,
                    role: .admin
                )
                user.companyName = "EchoChat 公司"
                user.lastLoginTime = Date()
                
                // 保存用戶到資料庫
                modelContext.insert(user)
                try? modelContext.save()
                
                self.currentUser = user
                self.isAuthenticated = true
                self.isOnline = false
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        }
        
        // 預設操作員帳號
        if username == "operator" && password == "operator123" {
            await MainActor.run {
                let user = User(
                    username: username,
                    email: "operator@echochat.com",
                    passwordHash: hashedPassword,
                    role: .operator_role
                )
                user.companyName = "EchoChat 公司"
                user.lastLoginTime = Date()
                
                // 保存用戶到資料庫
                modelContext.insert(user)
                try? modelContext.save()
                
                self.currentUser = user
                self.isAuthenticated = true
                self.isOnline = false
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        }
        
        throw AuthError.invalidCredentials
    }
    
    // Google登入
    func loginWithGoogle(_ googleUser: GoogleUser) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 檢查是否已存在Google用戶
        let existingUser = try? modelContext.fetch(FetchDescriptor<User>()).first { user in
            user.email == googleUser.email
        }
        
        if let existingUser = existingUser {
            // 更新現有用戶的登入時間
            existingUser.lastLoginTime = Date()
            
            await MainActor.run {
                self.currentUser = existingUser
                self.isAuthenticated = true
                UserDefaults.standard.set(existingUser.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        } else {
            // 創建新的Google用戶
            let newUser = User(
                username: googleUser.name,
                email: googleUser.email,
                passwordHash: "", // Google用戶不需要密碼
                role: .manager // 預設為經理角色
            )
            newUser.companyName = "Google用戶"
            newUser.lastLoginTime = Date()
            
            // 保存到資料庫
            modelContext.insert(newUser)
            
            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
                UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        }
    }
    
    // 註冊
    func register(username: String, email: String, password: String, companyName: String) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        switch authMode {
        case .remote:
            return try await registerWithAPI(username: username, email: email, password: password, companyName: companyName)
        case .local:
            return try await registerLocally(username: username, email: email, password: password, companyName: companyName)
        }
    }
    
    // 遠端 API 註冊
    private func registerWithAPI(username: String, email: String, password: String, companyName: String) async throws -> Bool {
        do {
            let success = try await apiService.register(username: username, email: email, password: password)
            
            if success {
                // 註冊成功，但需要驗證碼驗證
                // 這裡可以觸發發送驗證碼的流程
                await MainActor.run {
                    self.isOnline = true
                }
                
                return true
            } else {
                throw AuthError.serverError
            }
        } catch {
            // 如果 API 註冊失敗，嘗試本地註冊作為備用
            if isOnline {
                throw error
            } else {
                return try await registerLocally(username: username, email: email, password: password, companyName: companyName)
            }
        }
    }
    
    // 本地註冊
    private func registerLocally(username: String, email: String, password: String, companyName: String) async throws -> Bool {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // 檢查用戶名是否已存在
        if username == "admin" || username == "operator" {
            throw AuthError.usernameExists
        }
        
        let hashedPassword = hashPassword(password)
        let user = User(
            username: username,
            email: email,
            passwordHash: hashedPassword,
            role: .manager
        )
        user.companyName = companyName
        user.lastLoginTime = Date()
        
        // 保存到資料庫
        modelContext.insert(user)
        try modelContext.save()
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.isOnline = false
            UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
        }
        
        return true
    }
    
    // 發送驗證碼
    func sendVerificationCode(email: String) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        switch authMode {
        case .remote:
            return try await apiService.sendVerificationCode(email: email)
        case .local:
            // 本地模式模擬發送驗證碼
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return true
        }
    }
    
    // 驗證碼驗證並註冊
    func verifyCodeAndRegister(email: String, code: String, username: String, password: String, companyName: String) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        switch authMode {
        case .remote:
            // 先驗證碼，再註冊
            let token = try await apiService.verifyCode(email: email, code: code)
            
            // 使用驗證碼獲得的 token 進行註冊
            let success = try await apiService.register(username: username, email: email, password: password)
            
            if success {
                // 保存 token
                UserDefaults.standard.set(token, forKey: "authToken")
                
                // 創建本地用戶
                let user = User(
                    username: username,
                    email: email,
                    passwordHash: "",
                    role: .manager
                )
                user.companyName = companyName
                user.lastLoginTime = Date()
                
                await MainActor.run {
                    modelContext.insert(user)
                    try? modelContext.save()
                    
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.isOnline = true
                    UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
                }
                
                return true
            } else {
                throw AuthError.serverError
            }
            
        case .local:
            return try await registerLocally(username: username, email: email, password: password, companyName: companyName)
        }
    }
    
    // 登出
    func logout() async {
        if authMode == .remote && isOnline {
            do {
                try await apiService.logout()
            } catch {
                print("API logout failed: \(error)")
            }
        }
        
        currentUser = nil
        isAuthenticated = false
        isOnline = false
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
    
    // 檢查權限
    func hasPermission(_ permission: Permission) -> Bool {
        guard let user = currentUser else { return false }
        return user.role.permissions.contains(permission)
    }
    
    // 密碼雜湊
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // 驗證密碼
    func verifyPassword(_ password: String, against hash: String) -> Bool {
        let hashedPassword = hashPassword(password)
        return hashedPassword == hash
    }
    
    // 同步用戶資料
    func syncUserProfile() async throws {
        guard authMode == .remote && isOnline else { return }
        
        do {
            let updatedUser = try await apiService.syncUserProfile()
            
            // 更新本地用戶資料
            if let currentUser = currentUser {
                currentUser.username = updatedUser.username
                currentUser.email = updatedUser.email
                currentUser.role = updatedUser.role
                currentUser.lastLoginTime = updatedUser.lastLoginTime
                
                try modelContext.save()
            }
        } catch {
            print("Failed to sync user profile: \(error)")
            throw error
        }
    }
    
    // 更新用戶資訊
    func updateUserProfile(companyName: String?, phoneNumber: String?) async {
        guard let user = currentUser else { return }
        
        user.companyName = companyName
        user.phoneNumber = phoneNumber
        
        // 保存到本地資料庫
        try? modelContext.save()
        
        // 如果線上，同步到後端
        if authMode == .remote && isOnline {
            do {
                let success = try await apiService.updateUserProfile(name: companyName, email: user.email)
                
                if success {
                    print("User profile updated on server successfully")
                }
            } catch {
                print("Failed to update user profile on server: \(error)")
            }
        }
    }
    
    // 變更密碼
    func changePassword(currentPassword: String, newPassword: String) async throws -> Bool {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }
        
        // 如果是遠端模式且線上，使用 API
        if authMode == .remote && isOnline {
            do {
                return try await apiService.changePassword(oldPassword: currentPassword, newPassword: newPassword)
            } catch {
                print("Failed to change password via API: \(error)")
                // 如果 API 失敗，回退到本地驗證
            }
        }
        
        // 本地驗證
        if !verifyPassword(currentPassword, against: user.passwordHash) {
            throw AuthError.invalidCredentials
        }
        
        // 更新密碼
        user.passwordHash = hashPassword(newPassword)
        
        // 保存到資料庫
        try modelContext.save()
        
        return true
    }
    
    // 驗證碼驗證
    func verifyCode(email: String, code: String) async throws -> Bool {
        guard authMode == .remote && isOnline else {
            throw AuthError.networkError
        }
        
        do {
            let token = try await apiService.verifyCode(email: email, code: code)
            
            // 驗證成功，同步用戶資料
            let user = try await apiService.syncUserProfile()
            
            // 保存用戶到本地資料庫
            modelContext.insert(user)
            try modelContext.save()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isOnline = true
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        } catch {
            throw error
        }
    }
    
    // 刪除帳號
    func deleteAccount(password: String) async throws -> Bool {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }
        
        // 如果是遠端模式且線上，使用 API
        if authMode == .remote && isOnline {
            do {
                let success = try await apiService.deleteAccount(password: password)
                
                if success {
                    // 清除本地資料
                    await logout()
                }
                
                return success
            } catch {
                print("Failed to delete account via API: \(error)")
                // 如果 API 失敗，回退到本地驗證
            }
        }
        
        // 本地驗證
        if !verifyPassword(password, against: user.passwordHash) {
            throw AuthError.invalidCredentials
        }
        
        // 刪除本地用戶
        modelContext.delete(user)
        try modelContext.save()
        
        await logout()
        
        return true
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case usernameExists
    case userNotFound
    case networkError
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "用戶名或密碼錯誤"
        case .usernameExists:
            return "用戶名已存在"
        case .userNotFound:
            return "用戶不存在"
        case .networkError:
            return "網路連線錯誤"
        case .serverError:
            return "伺服器錯誤"
        }
    }
} 