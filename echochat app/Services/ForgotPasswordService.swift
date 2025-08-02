//
//  ForgotPasswordService.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - 忘記密碼 API 模型
struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ResetPasswordRequest: Codable {
    let email: String
    let code: String
    let newPassword: String
}

struct ForgotPasswordResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - 忘記密碼服務
class ForgotPasswordService: ObservableObject {
    static let shared = ForgotPasswordService()
    
    // API 端點設定
    private let baseURL = "https://ai-chatbot-umqm.onrender.com"
    
    @Published var isLoading = false
    @Published var currentStep: ForgotPasswordStep = .email
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    enum ForgotPasswordStep {
        case email
        case verificationCode
        case newPassword
    }
    
    private init() {}
    
    // MARK: - 發送驗證碼
    func sendVerificationCode(email: String) async -> Result<String, Error> {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/api/forgot-password") else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "無效的API網址"
            }
            return .failure(ForgotPasswordError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let body = ForgotPasswordRequest(email: email)
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "無效的伺服器回應"
                }
                return .failure(ForgotPasswordError.invalidResponse)
            }
            
            let apiResponse = try JSONDecoder().decode(ForgotPasswordResponse.self, from: data)
            
            await MainActor.run {
                self.isLoading = false
                
                if apiResponse.success {
                    self.successMessage = apiResponse.message
                    self.currentStep = .verificationCode
                } else {
                    self.errorMessage = apiResponse.error ?? "發送驗證碼失敗"
                }
            }
            
            if apiResponse.success {
                return .success(apiResponse.message ?? "驗證碼已發送")
            } else {
                return .failure(ForgotPasswordError.apiError(apiResponse.error ?? "發送驗證碼失敗"))
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "網路連接失敗"
            }
            return .failure(ForgotPasswordError.networkError(error))
        }
    }
    
    // MARK: - 重設密碼
    func resetPassword(email: String, code: String, newPassword: String) async -> Result<String, Error> {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/api/reset-password") else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "無效的API網址"
            }
            return .failure(ForgotPasswordError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let body = ResetPasswordRequest(email: email, code: code, newPassword: newPassword)
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "無效的伺服器回應"
                }
                return .failure(ForgotPasswordError.invalidResponse)
            }
            
            let apiResponse = try JSONDecoder().decode(ForgotPasswordResponse.self, from: data)
            
            await MainActor.run {
                self.isLoading = false
                
                if apiResponse.success {
                    self.successMessage = apiResponse.message
                    self.currentStep = .newPassword
                } else {
                    self.errorMessage = apiResponse.error ?? "重設密碼失敗"
                }
            }
            
            if apiResponse.success {
                return .success(apiResponse.message ?? "密碼重設成功")
            } else {
                return .failure(ForgotPasswordError.apiError(apiResponse.error ?? "重設密碼失敗"))
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "網路連接失敗"
            }
            return .failure(ForgotPasswordError.networkError(error))
        }
    }
    
    // MARK: - 重置狀態
    func resetState() {
        currentStep = .email
        errorMessage = nil
        successMessage = nil
        isLoading = false
    }
}

// MARK: - 錯誤類型
enum ForgotPasswordError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的API網址"
        case .invalidResponse:
            return "無效的伺服器回應"
        case .networkError(let error):
            return "網路連接失敗：\(error.localizedDescription)"
        case .apiError(let message):
            return message
        }
    }
} 