//
//  ContentView.swift
//  echochat app
//
//  Created by 徐明漢 on 2025/7/28.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    
    var body: some View {
        AuthenticatedView(modelContext: modelContext)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ChatMessage.self, inMemory: true)
}
