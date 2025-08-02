//
//  AuthenticatedView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct AuthenticatedView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
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
                        .environmentObject(authService)
                } else {
                    WelcomeView()
                        .environmentObject(authService)
                }
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .onAppear {
            print("📱 AuthenticatedView 載入，認證狀態: \(authService.isAuthenticated)")
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            print("🔄 認證狀態變更: \(isAuthenticated)")
        }
    }
}

#Preview {
    AuthenticatedView(modelContext: try! ModelContainer(for: User.self).mainContext)
} 