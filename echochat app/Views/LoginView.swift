//
//  LoginView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData
import UIKit

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
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
    
    // 註冊驗證碼相關狀態
    @State private var showingVerificationCode = false
    @State private var verificationCode = ""
    @State private var isSendingCode = false
    @State private var registrationEmail = ""
    @State private var registrationUsername = ""
    @State private var registrationPassword = ""
    @State private var registrationCompanyName = ""
    @State private var confirmPassword = ""
    
    // 使用 @AppStorage 來記住帳號密碼
    @AppStorage("savedUsername") private var savedUsername = ""
    @AppStorage("savedPassword") private var savedPassword = ""
    @AppStorage("rememberCredentials") private var savedRememberCredentials = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 淺藍色漸層背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.7, green: 0.8, blue: 0.95), // 淺藍色
                        Color(red: 0.5, green: 0.6, blue: 0.85)  // 深藍色
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
                                .foregroundColor(.white)
                            
                            // 應用程式名稱
                            Text("EchoChat")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // 副標題
                            Text("智能聊天機器人管理系統")
                                .font(.title3)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            // 描述文字
                            Text("提供強大的對話管理和知識庫功能，讓您的聊天機器人更加智能和人性化")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        
                        // 登入表單
                        VStack(spacing: 25) {
                            if isRegistering {
                                // 註冊步驟指示器
                                HStack(spacing: 20) {
                                    // 步驟 1：基本資料
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Text("1")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                        Text("基本資料")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    
                                    // 步驟 2：驗證碼
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Text("2")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white.opacity(0.7))
                                            )
                                        Text("驗證碼")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .padding(.bottom, 10)
                                
                                // 註冊表單標題
                                HStack {
                                    Text("基本資料")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.bottom, 5)
                                
                                // 註冊表單
                                VStack(spacing: 20) {
                                    CustomTextField(
                                        placeholder: "使用者名稱",
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
                                    
                                    CustomSecureField(
                                        placeholder: "確認密碼",
                                        text: $confirmPassword,
                                        icon: "lock"
                                    )
                                }
                            } else {
                                // 登入表單
                                VStack(spacing: 20) {
                                    CustomTextField(
                                        placeholder: "帳號",
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
                                            .foregroundColor(.white)
                                        
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
                                    } else if isRegistering {
                                        Text("下一步")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        Image(systemName: "arrow.right")
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.title3)
                                        Text("登入")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    isFormValid ? 
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.4, green: 0.2, blue: 0.8),
                                            Color(red: 0.6, green: 0.4, blue: 0.9)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(.systemGray3),
                                            Color(.systemGray3)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
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
                                .foregroundColor(.white)
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
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    Text("或")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                    
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.white.opacity(0.3))
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
                                .background(.white.opacity(0.3))
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isRegistering.toggle()
                                    clearForm()
                                }
                            }) {
                                Text(isRegistering ? "已有帳號?立即登入" : "沒有帳號？點擊註冊")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
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
            .sheet(isPresented: $showingVerificationCode) {
                VerificationCodeView(
                    email: registrationEmail,
                    onVerify: { code in
                        Task {
                            await handleVerificationCode(code)
                        }
                    }
                )
            }
            .onAppear {
                loadSavedCredentials()
            }
        }
    }
    
    private var isFormValid: Bool {
        if isRegistering {
            return !username.isEmpty && 
                   !email.isEmpty && 
                   !password.isEmpty && 
                   !confirmPassword.isEmpty && 
                   password.count >= 6 &&
                   password == confirmPassword
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
                    // 保存註冊資訊
                    registrationUsername = username
                    registrationEmail = email
                    registrationPassword = password
                    registrationCompanyName = companyName
                    
                    // 發送驗證碼
                    await MainActor.run {
                        isSendingCode = true
                    }
                    
                    do {
                        let success = try await authService.sendVerificationCode(email: email)
                        if success {
                            await MainActor.run {
                                showingVerificationCode = true
                                isSendingCode = false
                            }
                        } else {
                            await MainActor.run {
                                errorMessage = "發送驗證碼失敗"
                                showingError = true
                                isSendingCode = false
                            }
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showingError = true
                            isSendingCode = false
                        }
                    }
                } else {
                    let success = try await authService.login(
                        username: username,
                        password: password
                    )
                    
                    if success {
                        await MainActor.run {
                            print("✅ 登入成功！isAuthenticated: \(authService.isAuthenticated)")
                            
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
        confirmPassword = ""
    }
    
    private func handleVerificationCode(_ code: String) async {
        do {
            let success = try await authService.verifyCodeAndRegister(
                email: registrationEmail,
                code: code,
                username: registrationUsername,
                password: registrationPassword,
                companyName: registrationCompanyName
            )
            
            if success {
                await MainActor.run {
                    showingVerificationCode = false
                    clearForm()
                    isRegistering = false
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

// MARK: - 驗證碼輸入視圖
struct VerificationCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let email: String
    let onVerify: (String) -> Void
    
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // 淺藍色漸層背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.7, green: 0.8, blue: 0.95),
                        Color(red: 0.5, green: 0.6, blue: 0.85)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("驗證電子郵件")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("我們已將驗證碼發送到")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(email)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("請輸入驗證碼完成註冊")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    VStack(spacing: 20) {
                        CustomTextField(
                            placeholder: "驗證碼",
                            text: $verificationCode,
                            icon: "key"
                        )
                        
                        Button(action: {
                            if !verificationCode.isEmpty {
                                isLoading = true
                                onVerify(verificationCode)
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("驗證並註冊")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                verificationCode.isEmpty ? Color(.systemGray3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(verificationCode.isEmpty || isLoading)
                        
                        Button("重新發送驗證碼") {
                            // TODO: 重新發送驗證碼
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("錯誤", isPresented: $showingError) {
                Button("確定") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var forgotPasswordService = ForgotPasswordService.shared
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 淺藍色漸層背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.7, green: 0.8, blue: 0.95), // 淺藍色
                        Color(red: 0.5, green: 0.6, blue: 0.85)  // 深藍色
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // 標題和圖標
                        VStack(spacing: 20) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("忘記密碼")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // 步驟指示器
                            HStack(spacing: 20) {
                                ForEach(0..<3) { index in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(getStepColor(for: index))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Text("\(index + 1)")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                        Text(getStepTitle(for: index))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white.opacity(getStepOpacity(for: index)))
                                    }
                                }
                            }
                        }
                        
                        // 步驟內容
                        VStack(spacing: 25) {
                            switch forgotPasswordService.currentStep {
                            case .email:
                                emailStepView
                            case .verificationCode:
                                verificationCodeStepView
                            case .newPassword:
                                newPasswordStepView
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 50)
                }
            }
            .navigationTitle("重設密碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("成功", isPresented: $showingSuccessAlert) {
                Button("確定") {
                    dismiss()
                }
            } message: {
                Text(forgotPasswordService.successMessage ?? "操作成功")
            }
            .alert("錯誤", isPresented: $showingErrorAlert) {
                Button("確定") { }
            } message: {
                Text(forgotPasswordService.errorMessage ?? "發生錯誤")
            }
            .onAppear {
                forgotPasswordService.resetState()
            }
        }
    }
    
    // MARK: - 步驟視圖
    private var emailStepView: some View {
        VStack(spacing: 20) {
            Text("請輸入您的電子郵件地址")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("我們將發送驗證碼到您的郵箱")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            CustomTextField(
                placeholder: "電子郵件",
                text: $email,
                icon: "envelope",
                keyboardType: .emailAddress
            )
            
            Button(action: handleSendVerificationCode) {
                HStack {
                    if forgotPasswordService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("發送驗證碼")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    !email.isEmpty && !forgotPasswordService.isLoading ?
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemGray3), Color(.systemGray3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(email.isEmpty || forgotPasswordService.isLoading)
        }
    }
    
    private var verificationCodeStepView: some View {
        VStack(spacing: 20) {
            Text("請輸入驗證碼")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("驗證碼已發送到 \(email)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            CustomTextField(
                placeholder: "6位數驗證碼",
                text: $verificationCode,
                icon: "key",
                keyboardType: .numberPad
            )
            
            Button(action: handleVerifyCode) {
                HStack {
                    if forgotPasswordService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("驗證")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    verificationCode.count == 6 && !forgotPasswordService.isLoading ?
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemGray3), Color(.systemGray3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(verificationCode.count != 6 || forgotPasswordService.isLoading)
            
            Button("重新發送驗證碼") {
                handleSendVerificationCode()
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .disabled(forgotPasswordService.isLoading)
        }
    }
    
    private var newPasswordStepView: some View {
        VStack(spacing: 20) {
            Text("設定新密碼")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("請輸入您的新密碼")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            CustomSecureField(
                placeholder: "新密碼",
                text: $newPassword,
                icon: "lock"
            )
            
            CustomSecureField(
                placeholder: "確認新密碼",
                text: $confirmPassword,
                icon: "lock"
            )
            
            Button(action: handleResetPassword) {
                HStack {
                    if forgotPasswordService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("重設密碼")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isPasswordValid && !forgotPasswordService.isLoading ?
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemGray3), Color(.systemGray3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!isPasswordValid || forgotPasswordService.isLoading)
        }
    }
    
    // MARK: - 輔助方法
    private var isPasswordValid: Bool {
        return newPassword.count >= 6 && newPassword == confirmPassword
    }
    
    private func getStepColor(for index: Int) -> Color {
        let currentIndex = getCurrentStepIndex()
        if index < currentIndex {
            return .green
        } else if index == currentIndex {
            return .blue
        } else {
            return .white.opacity(0.3)
        }
    }
    
    private func getStepOpacity(for index: Int) -> Double {
        let currentIndex = getCurrentStepIndex()
        if index <= currentIndex {
            return 1.0
        } else {
            return 0.7
        }
    }
    
    private func getStepTitle(for index: Int) -> String {
        switch index {
        case 0: return "郵箱"
        case 1: return "驗證"
        case 2: return "密碼"
        default: return ""
        }
    }
    
    private func getCurrentStepIndex() -> Int {
        switch forgotPasswordService.currentStep {
        case .email: return 0
        case .verificationCode: return 1
        case .newPassword: return 2
        }
    }
    
    // MARK: - 操作處理
    private func handleSendVerificationCode() {
        Task {
            let result = await forgotPasswordService.sendVerificationCode(email: email)
            
            await MainActor.run {
                switch result {
                case .success(_):
                    // 成功發送驗證碼後，不顯示成功提示，直接進入下一步
                    // 服務已經自動更新了 currentStep
                    break
                case .failure(_):
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func handleVerifyCode() {
        // 驗證碼格式檢查通過，進入下一步
        forgotPasswordService.currentStep = .newPassword
    }
    
    private func handleResetPassword() {
        Task {
            let result = await forgotPasswordService.resetPassword(
                email: email,
                code: verificationCode,
                newPassword: newPassword
            )
            
            await MainActor.run {
                switch result {
                case .success(_):
                    // 重設密碼成功後，顯示成功提示並關閉頁面
                    showingSuccessAlert = true
                case .failure(_):
                    showingErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService(modelContext: try! ModelContainer(for: User.self).mainContext))
} 