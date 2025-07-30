//
//  AuthenticatedView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct AuthenticatedView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService: AuthService
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
    init(modelContext: ModelContext) {
        _authService = StateObject(wrappedValue: AuthService(modelContext: modelContext))
    }
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if hasSeenWelcome {
                    MainTabView()
                } else {
                    WelcomeView()
                }
            } else {
                LoginView(modelContext: modelContext)
            }
        }
        .environmentObject(authService)
    }
}

#Preview {
    AuthenticatedView(modelContext: try! ModelContainer(for: User.self).mainContext)
} 