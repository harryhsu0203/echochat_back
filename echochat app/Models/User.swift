//
//  User.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var username: String
    var email: String
    var passwordHash: String
    var role: UserRole
    var isActive: Bool
    var lastLoginTime: Date?
    var createdAt: Date
    var companyName: String?
    var phoneNumber: String?
    
    init(username: String, email: String, passwordHash: String, role: UserRole = .admin) {
        self.id = UUID()
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.role = role
        self.isActive = true
        self.lastLoginTime = nil
        self.createdAt = Date()
        self.companyName = nil
        self.phoneNumber = nil
    }
}

enum UserRole: String, CaseIterable, Codable {
    case admin = "admin"
    case manager = "manager"
    case operator_role = "operator"
    
    var displayName: String {
        switch self {
        case .admin:
            return "管理員"
        case .manager:
            return "經理"
        case .operator_role:
            return "操作員"
        }
    }
    
    var permissions: [Permission] {
        switch self {
        case .admin:
            return Permission.allCases
        case .manager:
            return [.viewMessages, .approveMessages, .editResponses, .viewReports, .manageSettings]
        case .operator_role:
            return [.viewMessages, .approveMessages, .editResponses]
        }
    }
}

enum Permission: String, CaseIterable, Codable {
    case viewMessages = "view_messages"
    case approveMessages = "approve_messages"
    case editResponses = "edit_responses"
    case deleteMessages = "delete_messages"
    case viewReports = "view_reports"
    case manageSettings = "manage_settings"
    case manageUsers = "manage_users"
    
    var displayName: String {
        switch self {
        case .viewMessages:
            return "查看訊息"
        case .approveMessages:
            return "核准訊息"
        case .editResponses:
            return "編輯回應"
        case .deleteMessages:
            return "刪除訊息"
        case .viewReports:
            return "查看報表"
        case .manageSettings:
            return "管理設定"
        case .manageUsers:
            return "管理用戶"
        }
    }
} 

 