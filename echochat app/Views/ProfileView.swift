//
//  ProfileView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @StateObject private var authService: AuthService
    @State private var showingLogoutAlert = false
    @State private var showingChangePassword = false
    @State private var showingEditProfile = false
    
    init(modelContext: ModelContext) {
        _authService = StateObject(wrappedValue: AuthService(modelContext: modelContext))
    }
    
    var body: some View {
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
            
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 25) {
                    // 用戶資訊區塊
                    VStack(spacing: 20) {
                        // 用戶頭像和基本資訊
                        VStack(spacing: 15) {
                            // 頭像
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                )
                            
                            // 用戶資訊
                            VStack(spacing: 8) {
                                Text(authService.currentUser?.username ?? "")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(authService.currentUser?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let companyName = authService.currentUser?.companyName {
                                    Text(companyName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 角色標籤
                            if let role = authService.currentUser?.role {
                                Text(role.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 30)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    
                    // 權限資訊
                    VStack(spacing: 15) {
                        HStack {
                            Text("權限")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(authService.currentUser?.role.permissions ?? [], id: \.self) { permission in
                                PermissionCard(permission: permission)
                            }
                        }
                    }
                    
                    // 帳號管理
                    VStack(spacing: 15) {
                        HStack {
                            Text("帳號管理")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        VStack(spacing: 12) {
                            ProfileActionButton(
                                title: "編輯個人資料",
                                icon: "person.crop.circle",
                                color: .blue
                            ) {
                                showingEditProfile = true
                            }
                            
                            ProfileActionButton(
                                title: "變更密碼",
                                icon: "lock.rotation",
                                color: .orange
                            ) {
                                showingChangePassword = true
                            }
                        }
                    }
                    
                    // 系統資訊
                    VStack(spacing: 15) {
                        HStack {
                            Text("系統資訊")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        VStack(spacing: 12) {
                            InfoRow(title: "應用程式版本", value: "1.0.0")
                            InfoRow(title: "登入時間", value: authService.currentUser?.lastLoginTime?.formatted() ?? "未知")
                            InfoRow(title: "帳號建立時間", value: authService.currentUser?.createdAt.formatted() ?? "未知")
                        }
                    }
                    
                    // 登出
                    VStack(spacing: 15) {
                        ProfileActionButton(
                            title: "登出",
                            icon: "rectangle.portrait.and.arrow.right",
                            color: .red
                        ) {
                            showingLogoutAlert = true
                        }
                    }
                    
                    // 底部間距
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.visible)
        }
        .navigationTitle("個人資料")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(authService: authService)
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView(authService: authService)
        }
        .alert("確認登出", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("登出", role: .destructive) {
                authService.logout()
            }
        } message: {
            Text("確定要登出嗎？")
        }
    }
}

struct PermissionCard: View {
    let permission: Permission
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            Text(permission.displayName)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ProfileActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct EditProfileView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var companyName = ""
    @State private var phoneNumber = ""
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
                
                ScrollView {
                    VStack(spacing: 25) {
                        VStack(spacing: 20) {
                            CustomTextField(
                                placeholder: "公司名稱",
                                text: $companyName,
                                icon: "building.2"
                            )
                            
                            CustomTextField(
                                placeholder: "電話號碼",
                                text: $phoneNumber,
                                icon: "phone"
                            )
                        }
                        .padding(.horizontal, 30)
                        
                        Button("儲存變更") {
                            Task {
                                await authService.updateUserProfile(
                                    companyName: companyName.isEmpty ? nil : companyName,
                                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
                                )
                                showingAlert = true
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                }
            }
            .navigationTitle("編輯個人資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert("儲存成功", isPresented: $showingAlert) {
                Button("確定") {
                    dismiss()
                }
            } message: {
                Text("個人資料已成功更新")
            }
            .onAppear {
                companyName = authService.currentUser?.companyName ?? ""
                phoneNumber = authService.currentUser?.phoneNumber ?? ""
            }
        }
    }
}

struct ChangePasswordView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    
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
                    VStack(spacing: 25) {
                        VStack(spacing: 20) {
                            HStack {
                                Text("變更密碼")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(spacing: 15) {
                                CustomSecureField(
                                    placeholder: "當前密碼",
                                    text: $currentPassword,
                                    icon: "lock"
                                )
                                
                                CustomSecureField(
                                    placeholder: "新密碼",
                                    text: $newPassword,
                                    icon: "lock.shield"
                                )
                                
                                CustomSecureField(
                                    placeholder: "確認新密碼",
                                    text: $confirmPassword,
                                    icon: "lock.shield"
                                )
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        VStack(spacing: 15) {
                            Text("密碼必須至少包含6個字符")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("變更密碼") {
                                changePassword()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isFormValid ?
                                Color.blue :
                                Color(.systemGray3)
                            )
                            .cornerRadius(12)
                            .disabled(!isFormValid)
                            .padding(.horizontal, 30)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                }
            }
            .navigationTitle("變更密碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert("錯誤", isPresented: $showingError) {
                Button("確定") { }
            } message: {
                Text(errorMessage)
            }
            .alert("密碼變更成功", isPresented: $showingSuccess) {
                Button("確定") {
                    dismiss()
                }
            } message: {
                Text("您的密碼已成功變更")
            }
        }
    }
    
    private var isFormValid: Bool {
        return !currentPassword.isEmpty && 
               !newPassword.isEmpty && 
               !confirmPassword.isEmpty && 
               newPassword.count >= 6 && 
               newPassword == confirmPassword
    }
    
    private func changePassword() {
        Task {
            do {
                let success = try await authService.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                
                await MainActor.run {
                    if success {
                        showingSuccess = true
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
}



#Preview {
    ProfileView(modelContext: try! ModelContainer(for: User.self).mainContext)
} 