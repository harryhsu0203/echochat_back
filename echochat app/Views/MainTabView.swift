//
//  MainTabView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject private var authService: AuthService
    @State private var selectedTab = 0
    
    // Tab 切換管理器
    @StateObject private var tabManager = TabManager()
    
    var body: some View {
        ZStack {
            // 背景只忽略 safe area，內容保持在上層
            Color.primaryBackground
                .ignoresSafeArea()

            // 主要內容區域
            ZStack {
                TabView(selection: $selectedTab) {
                    NavigationView {
                        HomeView()
                    }
                    .tag(0)
                    
                    NavigationView {
                        ConversationListView()
                    }
                    .tag(1)
                    
                    NavigationView {
                        ChannelManagementView()
                    }
                    .tag(2)
                    
                    NavigationView {
                        AIAssistantConfigView()
                    }
                    .tag(3)
                    
                    NavigationView {
                        BillingSystemView()
                    }
                    .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 自定義超緊湊TabBar
                VStack {
                    Spacer()
                    CustomUltraCompactTabBar(selectedTab: $selectedTab)
                }
            }

            // Debug 標記：確認內容有 render
            VStack {
                Text("DEBUG VIEW LOADED")
                    .foregroundColor(.red)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
        .environmentObject(tabManager)
        .onReceive(tabManager.$targetTab) { targetTab in
            if let targetTab = targetTab {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = targetTab
                }
                tabManager.targetTab = nil
            }
        }
    }
}

// Tab 切換管理器
class TabManager: ObservableObject {
    @Published var targetTab: Int? = nil
    
    func switchToTab(_ tab: Int) {
        targetTab = tab
    }
}

struct CustomUltraCompactTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabItems = [
        (icon: "house.fill", title: "首頁"),
        (icon: "bubble.left.and.bubble.right.fill", title: "對話"),
        (icon: "antenna.radiowaves.left.and.right", title: "頻道管理"),
        (icon: "brain.head.profile", title: "AI助理"),
        (icon: "dollarsign.circle.fill", title: "帳務系統")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabItems.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: tabItems[index].icon)
                            .font(.system(size: 18))
                            .foregroundColor(selectedTab == index ? Color.warmAccent : Color.secondaryText)
                            .scaleEffect(selectedTab == index ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                        
                        Text(tabItems[index].title)
                            .font(.system(size: 10, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? Color.warmAccent : Color.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        selectedTab == index ? 
                        Color.warmAccent.opacity(0.08) : 
                        Color.clear
                    )
                    .cornerRadius(6)
                }
            }
        }
        .background(Color.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.2)
                .foregroundColor(Color(.systemGray6))
                , alignment: .top
        )
        .frame(height: 44)
        .padding(.horizontal, 8)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: LineMessage.self, inMemory: true)
} 