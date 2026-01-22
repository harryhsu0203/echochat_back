//
//  AISettings.swift
//  echochat app
//
//  Created by AI Assistant on 2026/1/22.
//

import Foundation

struct AISettings: Codable, Equatable {
    var defaultModel: String
    var fallbackModel: String?
    var autoEscalateEnabled: Bool
    var escalateKeywords: [String]

    enum CodingKeys: String, CodingKey {
        case defaultModel = "default_model"
        case fallbackModel = "fallback_model"
        case autoEscalateEnabled = "auto_escalate_enabled"
        case escalateKeywords = "escalate_keywords"
    }
}

struct AISettingsResponse: Codable {
    let success: Bool
    let settings: AISettings?
    let error: String?
}


