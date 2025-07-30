//
//  LoginView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @StateObject private var authService: AuthService
    @StateObject private var googleAuthService = GoogleAuthService()
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var companyName = ""
    @State private var isRegistering = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingForgotPassword = false
    @State private var rememberCredentials = false
    
    // 使用 @AppStorage 來記住帳號密碼
    @AppStorage("savedUsername") private var savedUsername = ""
    @AppStorage("savedPassword") private var savedPassword = ""
    @AppStorage("rememberCredentials") private var savedRememberCredentials = false
    
    init(modelContext: ModelContext) {
        _authService = StateObject(wrappedValue: AuthService(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 柔和漸層背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Logo和標題區域
                        VStack(spacing: 25) {
                            // 機器人圖標
                            Image(systemName: "robot")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            // 應用程式名稱
                            Text("EchoChat")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            // 副標題
                            Text("智能聊天機器人管理系統")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            // 描述文字
                            Text("提供強大的對話管理和知識庫功能，讓您的聊天機器人更加智能和人性化")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        
                        // 登入表單
                        VStack(spacing: 25) {
                            if isRegistering {
                                // 註冊表單
                                VStack(spacing: 20) {
                                    CustomTextField(
                                        placeholder: "用戶名",
                                        text: $username,
                                        icon: "person"
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "電子郵件",
                                        text: $email,
                                        icon: "envelope",
                                        keyboardType: .emailAddress
                                    )
                                    
                                    CustomSecureField(
                                        placeholder: "密碼",
                                        text: $password,
                                        icon: "lock"
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "公司名稱",
                                        text: $companyName,
                                        icon: "building.2"
                                    )
                                }
                            } else {
                                // 登入表單
                                VStack(spacing: 20) {
                                    CustomTextField(
                                        placeholder: "用戶名",
                                        text: $username,
                                        icon: "person"
                                    )
                                    
                                    CustomSecureField(
                                        placeholder: "密碼",
                                        text: $password,
                                        icon: "lock"
                                    )
                                    
                                    // 記住帳號密碼選項
                                    HStack {
                                        Toggle("記住帳號密碼", isOn: $rememberCredentials)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            
                            // 登入/註冊按鈕
                            Button(action: handleSubmit) {
                                HStack {
                                    if authService.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: isRegistering ? "person.badge.plus" : "person.fill")
                                            .font(.title3)
                                    }
                                    
                                    Text(isRegistering ? "註冊" : "登入")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    isFormValid ? 
                                    Color.blue :
                                    Color(.systemGray3)
                                )
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || authService.isLoading)
                            
                            // 忘記密碼
                            if !isRegistering {
                                Button("忘記密碼？") {
                                    showingForgotPassword = true
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // 分隔線和Google登入
                        if !isRegistering {
                            VStack(spacing: 20) {
                                // 分隔線
                                HStack {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color(.systemGray4))
                                    
                                    Text("或")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 10)
                                    
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color(.systemGray4))
                                }
                                
                                // Google登入按鈕
                                GoogleSignInButton {
                                    handleGoogleSignIn()
                                }
                                .padding(.horizontal, 30)
                            }
                        }
                        
                        // 切換登入/註冊
                        VStack(spacing: 15) {
                            Divider()
                                .background(Color(.systemGray4))
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isRegistering.toggle()
                                    clearForm()
                                }
                            }) {
                                Text(isRegistering ? "已有帳號？點擊登入" : "沒有帳號？點擊註冊")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // 預設帳號提示
                        if !isRegistering {
                            VStack(spacing: 12) {
                                Text("預設帳號")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 6) {
                                    Text("管理員: admin / admin123")
                                    Text("操作員: operator / operator123")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 50)
                }
            }
            .alert("錯誤", isPresented: $showingError) {
                Button("確定") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
            .onAppear {
                loadSavedCredentials()
            }
        }
    }
    
    private var isFormValid: Bool {
        if isRegistering {
            return !username.isEmpty && !email.isEmpty && !password.isEmpty && !companyName.isEmpty && password.count >= 6
        } else {
            return !username.isEmpty && !password.isEmpty
        }
    }
    
    private func loadSavedCredentials() {
        if savedRememberCredentials {
            username = savedUsername
            password = savedPassword
            rememberCredentials = true
        }
    }
    
    private func handleSubmit() {
        Task {
            do {
                if isRegistering {
                    let success = try await authService.register(
                        username: username,
                        email: email,
                        password: password,
                        companyName: companyName
                    )
                    
                    if success {
                        clearForm()
                    }
                } else {
                    let success = try await authService.login(
                        username: username,
                        password: password
                    )
                    
                    if success {
                        // 保存或清除記住的帳號密碼
                        if rememberCredentials {
                            savedUsername = username
                            savedPassword = password
                            savedRememberCredentials = true
                        } else {
                            savedUsername = ""
                            savedPassword = ""
                            savedRememberCredentials = false
                        }
                        
                        clearForm()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            do {
                let googleUser = try await googleAuthService.signIn()
                let success = try await authService.loginWithGoogle(googleUser)
                
                if success {
                    await MainActor.run {
                        clearForm()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func clearForm() {
        if !rememberCredentials {
            username = ""
            password = ""
        }
        email = ""
        companyName = ""
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 柔和漸層背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("忘記密碼")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("請輸入您的電子郵件地址，我們將發送重設密碼的連結給您。")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 25) {
                        CustomTextField(
                            placeholder: "電子郵件",
                            text: $email,
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        
                        Button("發送重設連結") {
                            showingAlert = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            !email.isEmpty ?
                            Color.blue :
                            Color(.systemGray3)
                        )
                        .cornerRadius(12)
                        .disabled(email.isEmpty)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("重設密碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert("重設連結已發送", isPresented: $showingAlert) {
                Button("確定") {
                    dismiss()
                }
            } message: {
                Text("如果該電子郵件地址已註冊，您將收到重設密碼的連結。")
            }
        }
    }
}

#Preview {
    LoginView(modelContext: try! ModelContainer(for: User.self).mainContext)
} 