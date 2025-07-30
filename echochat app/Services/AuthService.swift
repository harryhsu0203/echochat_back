//
//  AuthService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData
import CryptoKit

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkSavedLogin()
    }
    
    // 檢查是否有保存的登入狀態
    private func checkSavedLogin() {
        if let savedUserId = UserDefaults.standard.string(forKey: "currentUserId"),
           let _ = UUID(uuidString: savedUserId) {
            // 這裡應該從資料庫查詢用戶
            // 目前簡化處理
            isAuthenticated = true
        }
    }
    
    // 登入
    func login(username: String, password: String) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 這裡應該與後端API驗證
        // 目前使用本地驗證
        let hashedPassword = hashPassword(password)
        
        // 預設管理員帳號
        if username == "admin" && password == "admin123" {
            let user = User(
                username: username,
                email: "admin@echochat.com",
                passwordHash: hashedPassword,
                role: .admin
            )
            user.companyName = "EchoChat 公司"
            user.lastLoginTime = Date()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        }
        
        // 預設操作員帳號
        if username == "operator" && password == "operator123" {
            let user = User(
                username: username,
                email: "operator@echochat.com",
                passwordHash: hashedPassword,
                role: .operator_role
            )
            user.companyName = "EchoChat 公司"
            user.lastLoginTime = Date()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            return true
        }
        
        throw AuthError.invalidCredentials
    }
    
    // Google登入
    func loginWithGoogle(_ googleUser: GoogleUser) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
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
        isLoading = true
        defer { isLoading = false }
        
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
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
        }
        
        return true
    }
    
    // 登出
    func logout() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "currentUserId")
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
    
    // 更新用戶資訊
    func updateUserProfile(companyName: String?, phoneNumber: String?) async {
        guard let user = currentUser else { return }
        
        user.companyName = companyName
        user.phoneNumber = phoneNumber
        
        // 保存到資料庫
        try? modelContext.save()
    }
    
    // 變更密碼
    func changePassword(currentPassword: String, newPassword: String) async throws -> Bool {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }
        
        // 驗證當前密碼
        if !verifyPassword(currentPassword, against: user.passwordHash) {
            throw AuthError.invalidCredentials
        }
        
        // 更新密碼
        user.passwordHash = hashPassword(newPassword)
        
        // 保存到資料庫
        try modelContext.save()
        
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