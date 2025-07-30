//
//  GoogleAuthService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftUI

class GoogleAuthService: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var currentUser: GoogleUser?
    
    init() {
        // 簡化版本，不依賴外部SDK
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
        
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // 模擬Google登入成功
        let mockUser = GoogleUser(
            id: "google_\(UUID().uuidString)",
            email: "user@gmail.com",
            name: "Google用戶",
            givenName: "Google",
            familyName: "用戶",
            profileImageURL: nil
        )
        
        await MainActor.run {
            self.currentUser = mockUser
            self.isSignedIn = true
        }
        
        return mockUser
    }
    
    func signOut() {
        Task { @MainActor in
            self.currentUser = nil
            self.isSignedIn = false
        }
    }
    
    func restoreSignIn() async throws -> GoogleUser? {
        // 簡化版本，不實現恢復登入
        return nil
    }
}

struct GoogleUser {
    let id: String
    let email: String
    let name: String
    let givenName: String?
    let familyName: String?
    let profileImageURL: URL?
    
    init(id: String, email: String, name: String, givenName: String?, familyName: String?, profileImageURL: URL?) {
        self.id = id
        self.email = email
        self.name = name
        self.givenName = givenName
        self.familyName = familyName
        self.profileImageURL = profileImageURL
    }
}

enum GoogleAuthError: Error, LocalizedError {
    case presentationError
    case signInFailed(String)
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .presentationError:
            return "無法顯示登入視窗"
        case .signInFailed(let message):
            return "Google登入失敗: \(message)"
        case .configurationError:
            return "Google服務配置錯誤"
        }
    }
}

// Google登入按鈕組件
struct GoogleSignInButton: View {
    let action: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            isLoading = true
            action()
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("使用Google登入")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// 真實Google登入按鈕（需要SDK）
struct RealGoogleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text("使用Google登入")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red)
            .cornerRadius(12)
        }
    }
} 