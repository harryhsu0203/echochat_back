//
//  UserAccountService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData
import CryptoKit

// MARK: - 用戶帳號服務
class UserAccountService: ObservableObject {
    private let apiService = APIService.shared
    private let modelContext: ModelContext
    
    @Published var isSyncing = false
    @Published var syncError: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - 用戶註冊與後端同步
    func registerUserWithBackend(username: String, email: String, password: String, companyName: String) async throws -> User {
        print("🔄 開始註冊用戶並同步到後端...")
        
        // 1. 先發送驗證碼
        let verificationSent = try await sendVerificationCode(email: email)
        guard verificationSent else {
            throw UserAccountError.verificationFailed
        }
        
        // 2. 等待用戶輸入驗證碼（這裡需要UI配合）
        // 實際應用中，這應該在UI層處理
        // 注意：這裡應該等待驗證碼驗證完成後再繼續
        
        // 3. 使用後端 API 註冊
        let registerSuccess = try await apiService.register(username: username, email: email, password: password)
        guard registerSuccess else {
            throw UserAccountError.verificationFailed
        }
        
        // 4. 創建本地用戶
        let hashedPassword = hashPassword(password)
        let user = User(
            username: username,
            email: email,
            passwordHash: hashedPassword,
            role: .manager
        )
        user.companyName = companyName
        user.lastLoginTime = Date()
        user.createdAt = Date()
        
        // 5. 保存到本地資料庫
        modelContext.insert(user)
        try modelContext.save()
        
        print("✅ 用戶註冊並同步成功")
        return user
    }
    
    // MARK: - 用戶登入與後端同步
    func loginUserWithBackend(username: String, password: String) async throws -> User {
        print("🔄 開始登入用戶並同步到後端...")
        
        // 1. 嘗試後端登入
        do {
            let (user, token) = try await apiService.login(username: username, password: password)
            
            // 2. 保存用戶到本地資料庫
            await MainActor.run {
                modelContext.insert(user)
                try? modelContext.save()
                
                // 保存認證token
                UserDefaults.standard.set(token, forKey: "authToken")
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            }
            
            print("✅ 後端登入成功")
            return user
            
        } catch {
            print("⚠️ 後端登入失敗，嘗試本地登入: \(error)")
            
            // 3. 如果後端失敗，嘗試本地登入
            return try await loginUserLocally(username: username, password: password)
        }
    }
    
    // MARK: - 本地登入
    private func loginUserLocally(username: String, password: String) async throws -> User {
        let hashedPassword = hashPassword(password)
        
        // 查詢本地用戶
        let descriptor = FetchDescriptor<User>(predicate: #Predicate<User> { user in
            user.username == username
        })
        
        let users = try modelContext.fetch(descriptor)
        guard let user = users.first else {
            throw UserAccountError.userNotFound
        }
        
        // 驗證密碼
        guard verifyPassword(password, against: user.passwordHash) else {
            throw UserAccountError.invalidCredentials
        }
        
        // 更新登入時間
        user.lastLoginTime = Date()
        try modelContext.save()
        
        // 保存用戶ID
        UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
        
        print("✅ 本地登入成功")
        return user
    }
    
    // MARK: - 同步用戶資料到後端
    func syncUserToBackend(_ user: User) async throws {
        print("🔄 同步用戶資料到後端...")
        // 目前後端僅提供更新 name 與 email 的端點
        do {
            let success = try await apiService.updateUserProfile(
                name: user.companyName ?? user.username,
                email: user.email
            )
            if success {
                print("✅ 用戶資料同步成功")
            } else {
                print("⚠️ 用戶資料同步失敗")
            }
        } catch {
            print("❌ 用戶資料同步錯誤: \(error)")
            throw UserAccountError.syncFailed
        }
    }
    
    // MARK: - 從後端同步用戶資料
    func syncUserFromBackend(userId: String) async throws -> User? {
        print("🔄 從後端同步用戶資料...")
        do {
            // 後端提供的是「目前使用者」的資料端點
            let backendUser = try await apiService.syncUserProfile()
            
            // 檢查本地是否已存在此用戶（用傳入的 userId 對應本地）
            let descriptor = FetchDescriptor<User>(predicate: #Predicate<User> { user in
                user.id.uuidString == userId
            })
            let users = try modelContext.fetch(descriptor)
            
            if let existingUser = users.first {
                existingUser.username = backendUser.username
                existingUser.email = backendUser.email
                existingUser.companyName = backendUser.companyName
                existingUser.phoneNumber = backendUser.phoneNumber
                existingUser.isActive = backendUser.isActive
                existingUser.lastLoginTime = backendUser.lastLoginTime
                try modelContext.save()
                print("✅ 現有用戶資料已更新")
                return existingUser
            } else {
                let newUser = User(
                    username: backendUser.username,
                    email: backendUser.email,
                    passwordHash: "",
                    role: backendUser.role
                )
                newUser.id = UUID(uuidString: userId) ?? UUID()
                newUser.companyName = backendUser.companyName
                newUser.phoneNumber = backendUser.phoneNumber
                newUser.isActive = backendUser.isActive
                newUser.lastLoginTime = backendUser.lastLoginTime
                newUser.createdAt = backendUser.createdAt
                modelContext.insert(newUser)
                try modelContext.save()
                print("✅ 新用戶已從後端同步")
                return newUser
            }
        } catch {
            print("❌ 從後端同步用戶資料失敗: \(error)")
            throw UserAccountError.syncFailed
        }
    }
    
    // MARK: - 更新用戶資料
    func updateUserProfile(_ user: User) async throws {
        print("🔄 更新用戶資料...")
        
        // 更新本地資料庫
        try modelContext.save()
        
        // 同步到後端
        try await syncUserToBackend(user)
        
        print("✅ 用戶資料更新成功")
    }
    
    // MARK: - 刪除用戶帳號
    func deleteUserAccount(_ user: User, password: String) async throws {
        print("🔄 刪除用戶帳號...")
        
        // 驗證密碼
        guard verifyPassword(password, against: user.passwordHash) else {
            throw UserAccountError.invalidCredentials
        }
        
        // 嘗試從後端刪除
        do {
            let success = try await apiService.deleteAccount(password: password)
            if success {
                print("✅ 後端帳號刪除成功")
            }
        } catch {
            print("⚠️ 後端帳號刪除失敗: \(error)")
        }
        
        // 刪除本地資料
        modelContext.delete(user)
        try modelContext.save()
        
        // 清除認證資料
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        
        print("✅ 本地帳號刪除成功")
    }
    
    // MARK: - 發送驗證碼
    private func sendVerificationCode(email: String) async throws -> Bool {
        return try await apiService.sendVerificationCode(email: email)
    }
    
    // MARK: - 驗證碼驗證
    func verifyCode(email: String, code: String) async throws -> Bool {
        do {
            let token = try await apiService.verifyCode(email: email, code: code)
            // 持久化 token（APIService 已處理保存，這裡不重複保存）
            return !token.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - 密碼雜湊
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 密碼驗證
    private func verifyPassword(_ password: String, against hash: String) -> Bool {
        let hashedPassword = hashPassword(password)
        return hashedPassword == hash
    }
    
    // MARK: - 檢查用戶是否存在
    func checkUserExists(username: String) async throws -> Bool {
        // 先檢查本地
        let descriptor = FetchDescriptor<User>(predicate: #Predicate<User> { user in
            user.username == username
        })
        let users = try modelContext.fetch(descriptor)
        if !users.isEmpty {
            return true
        }
        // 目前無對應後端端點，先返回 false
        return false
    }
    
    // MARK: - 獲取當前用戶
    func getCurrentUser() -> User? {
        guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<User>(predicate: #Predicate<User> { user in
            user.id == userId
        })
        
        do {
            let users = try modelContext.fetch(descriptor)
            return users.first
        } catch {
            print("❌ 獲取當前用戶失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - 登出
    func logout() {
        // 清除認證資料
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        
        print("✅ 用戶已登出")
    }
}



// MARK: - 用戶帳號錯誤
enum UserAccountError: Error, LocalizedError {
    case userNotFound
    case invalidCredentials
    case verificationFailed
    case syncFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "用戶不存在"
        case .invalidCredentials:
            return "用戶名或密碼錯誤"
        case .verificationFailed:
            return "驗證碼發送失敗"
        case .syncFailed:
            return "資料同步失敗"
        case .networkError:
            return "網路連接錯誤"
        }
    }
}
