//
//  HomeView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject private var authService: AuthService
    @State private var selectedFeature: HomeFeature?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 歡迎區域
                welcomeSection
                
                // 快速功能區域
                quickFeaturesSection
                
                // 統計概覽區域
                statsOverviewSection
                
                // 最近活動區域
                recentActivitySection
            }
            .padding()
        }
        .navigationTitle("首頁")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemBackground))
        .sheet(item: $selectedFeature) { feature in
            featureDestination(for: feature)
        }
    }
    
    // MARK: - 歡迎區域
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("歡迎回來")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(authService.currentUser?.username ?? "用戶")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.warmAccent)
                }
                
                Spacer()
                
                // 用戶頭像
                Circle()
                    .fill(Color.warmAccent.gradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    )
            }
            
            Text("今天是美好的一天，讓我們開始管理您的聊天機器人吧！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - 快速功能區域
    private var quickFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速功能")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(HomeFeature.allCases, id: \.self) { feature in
                    QuickFeatureCard(feature: feature) {
                        selectedFeature = feature
                    }
                }
            }
        }
    }
    
    // MARK: - 統計概覽區域
    private var statsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("統計概覽")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                HomeStatCard(title: "總對話數", value: "1,234", icon: "bubble.left.and.bubble.right", color: .blue)
                HomeStatCard(title: "活躍用戶", value: "567", icon: "person.2.fill", color: .green)
                HomeStatCard(title: "回應準確率", value: "98.5%", icon: "checkmark.circle.fill", color: .orange)
                HomeStatCard(title: "今日訊息", value: "89", icon: "message.fill", color: .purple)
            }
        }
    }
    
    // MARK: - 最近活動區域
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近活動")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    ActivityRow(
                        icon: "bubble.left.fill",
                        title: "新對話開始",
                        subtitle: "用戶詢問產品資訊",
                        time: "\(index + 1) 分鐘前",
                        color: .blue
                    )
                }
            }
        }
    }
    
    // MARK: - 功能導航
    @ViewBuilder
    private func featureDestination(for feature: HomeFeature) -> some View {
        switch feature {
        case .conversations:
            ConversationListView()
        case .channels:
            ChannelManagementView()
        case .aiAssistant:
            AIAssistantConfigView()
        case .billing:
            BillingSystemView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - 快速功能卡片
struct QuickFeatureCard: View {
    let feature: HomeFeature
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: feature.icon)
                    .font(.title2)
                    .foregroundColor(feature.color)
                    .frame(width: 40, height: 40)
                    .background(feature.color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 統計卡片
struct HomeStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 活動行
struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - 首頁功能枚舉
enum HomeFeature: String, CaseIterable, Identifiable {
    case conversations = "conversations"
    case channels = "channels"
    case aiAssistant = "aiAssistant"
    case billing = "billing"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .conversations:
            return "對話管理"
        case .channels:
            return "頻道管理"
        case .aiAssistant:
            return "AI助理"
        case .billing:
            return "帳務系統"
        case .settings:
            return "系統設定"
        }
    }
    
    var icon: String {
        switch self {
        case .conversations:
            return "bubble.left.and.bubble.right.fill"
        case .channels:
            return "antenna.radiowaves.left.and.right"
        case .aiAssistant:
            return "brain.head.profile"
        case .billing:
            return "dollarsign.circle.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .conversations:
            return .blue
        case .channels:
            return .green
        case .aiAssistant:
            return .orange
        case .billing:
            return .purple
        case .settings:
            return .gray
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
            .environmentObject(AuthService(modelContext: try! ModelContainer(for: User.self).mainContext))
    }
} 