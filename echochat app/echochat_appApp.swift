//
//  echochat_appApp.swift
//  echochat app
//
//  Created by 徐明漢 on 2025/7/28.
//

import SwiftUI
import SwiftData

@main
struct echochat_appApp: App {
    let modelContainer: ModelContainer
    @StateObject private var settingsManager = AppSettingsManager.shared
    
    init() {
        do {
            let schema = Schema([
                ChatMessage.self,
                Conversation.self,
                LineMessage.self,
                LineConversation.self,
                User.self,
                Channel.self,
                AIConfiguration.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .preferredColorScheme(settingsManager.currentColorScheme)
                .environmentObject(settingsManager)
        }
        .modelContainer(modelContainer)
    }
}
