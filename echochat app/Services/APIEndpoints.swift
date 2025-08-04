//
//  APIEndpoints.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - API 端點定義
struct APIEndpoints {
    // 用戶認證相關
    static let login = "/api/login"
    static let googleLogin = "/api/google-login"
    static let register = "/api/register"
    static let sendVerificationCode = "/api/send-verification-code"
    static let verifyCode = "/api/verify-code"
    static let changePassword = "/api/change-password"
    static let deleteAccount = "/api/delete-account"
    
    // 用戶資料相關
    static let userProfile = "/api/user/profile"
    static let updateProfile = "/api/user/update-profile"
    
    // 頻道管理相關
    static let createChannel = "/api/channels/create"
    static let updateChannel = "/api/channels/update"
    static let getUserChannels = "/api/channels/user"
    static let deleteChannel = "/api/channels/delete"
    static let testChannelConnection = "/api/channels/test-connection"
    
    // LINE API 相關
    static let lineApiSettings = "/api/line-api/settings"
    static let lineToken = "/api/line-token"
    static let webhookUrl = "/api/user/webhook-url"
    
    // 計費相關
    static let billingPlans = "/api/billing/plans"
    static let billingSubscription = "/api/billing/subscription"
    static let billingPayment = "/api/billing/payment"
    static let billingHistory = "/api/billing/history"
    
    // 系統相關
    static let health = "/api/health"
    static let systemSettings = "/api/system/settings"
    
    // AI 相關
    static let aiChat = "/api/ai/chat"
    static let aiConfig = "/api/ai/config"
    static let aiAssistantConfig = "/api/ai-assistant-config"
    static let aiAssistantConfigReset = "/api/ai-assistant-config/reset"
    static let aiModels = "/api/ai-models"
} 