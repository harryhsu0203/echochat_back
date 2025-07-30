//
//  BillingSystemView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData

struct BillingSystemView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingUsageDetails = false
    @State private var selectedCustomer: CustomerUsage?
    @State private var showingPlanSelection = false
    
    enum TimeRange: String, CaseIterable {
        case week = "本週"
        case month = "本月"
        case quarter = "本季"
        case year = "本年"
    }
    
    var body: some View {
        ZStack {
            // 柔和漸層背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // 總覽卡片
                    OverviewCard()
                    
                    // 時間範圍選擇器
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                    
                    // 使用量統計
                    UsageStatisticsView(timeRange: selectedTimeRange)
                    
                    // 客戶使用量列表
                    CustomerUsageListView(
                        timeRange: selectedTimeRange,
                        onCustomerTap: { customer in
                            selectedCustomer = customer
                            showingUsageDetails = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("帳務系統")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("變更方案") {
                    showingPlanSelection = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingUsageDetails) {
            if let customer = selectedCustomer {
                UsageDetailsView(customer: customer)
            }
        }
        .sheet(isPresented: $showingPlanSelection) {
            PlanSelectionView()
        }
    }
}

// 總覽卡片
struct OverviewCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總使用量")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("1,234,567")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("目前方案")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("專業版")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Pro Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                StatItem(title: "活躍客戶", value: "45", icon: "person.2.fill", color: .blue)
                Spacer()
                StatItem(title: "對話數", value: "1,234", icon: "bubble.left.and.bubble.right.fill", color: .green)
                Spacer()
                StatItem(title: "平均回應", value: "2.3s", icon: "clock.fill", color: .orange)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// 統計項目
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// 時間範圍選擇器
struct TimeRangeSelector: View {
    @Binding var selectedRange: BillingSystemView.TimeRange
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(BillingSystemView.TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedRange == range ? .semibold : .regular)
                        .foregroundColor(selectedRange == range ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedRange == range ? 
                            Color.blue : 
                            Color(.systemGray5)
                        )
                        .cornerRadius(20)
                }
            }
        }
    }
}

// 使用量統計視圖
struct UsageStatisticsView: View {
    let timeRange: BillingSystemView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用量趨勢")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 簡化的圖表
            VStack(spacing: 12) {
                HStack {
                    Text("Token 使用量")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("123,456")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // 簡化的進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * 0.75, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("費用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$12.34")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// 客戶使用量列表
struct CustomerUsageListView: View {
    let timeRange: BillingSystemView.TimeRange
    let onCustomerTap: (CustomerUsage) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("客戶使用量")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(sampleCustomerData, id: \.id) { customer in
                    CustomerUsageRow(customer: customer) {
                        onCustomerTap(customer)
                    }
                }
            }
        }
    }
}

// 客戶使用量行
struct CustomerUsageRow: View {
    let customer: CustomerUsage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 客戶頭像
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(customer.name.prefix(1)))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(customer.conversationCount) 個對話")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(customer.tokenUsage)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 使用量詳情視圖
struct UsageDetailsView: View {
    let customer: CustomerUsage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 客戶資訊
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(customer.name.prefix(1)))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            )
                        
                        Text(customer.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("客戶 ID: \(customer.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // 使用量詳情
                    VStack(spacing: 16) {
                        DetailRow(title: "總 Token 使用量", value: "\(customer.tokenUsage)", icon: "cpu.fill", color: .blue)
                        DetailRow(title: "對話數量", value: "\(customer.conversationCount)", icon: "bubble.left.and.bubble.right.fill", color: .green)
                        DetailRow(title: "平均回應時間", value: "\(customer.avgResponseTime)s", icon: "clock.fill", color: .orange)
                        DetailRow(title: "總費用", value: "$\(String(format: "%.2f", customer.cost))", icon: "dollarsign.circle.fill", color: .green)
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                .padding(20)
            }
        }
        .navigationTitle("使用量詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }
}

// 詳情行
struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// 客戶使用量數據模型
struct CustomerUsage {
    let id: String
    let name: String
    let tokenUsage: Int
    let conversationCount: Int
    let avgResponseTime: Double
    let cost: Double
}

// 範例數據
let sampleCustomerData = [
    CustomerUsage(id: "001", name: "張小明", tokenUsage: 45678, conversationCount: 23, avgResponseTime: 2.1, cost: 4.56),
    CustomerUsage(id: "002", name: "李小華", tokenUsage: 34567, conversationCount: 18, avgResponseTime: 1.8, cost: 3.45),
    CustomerUsage(id: "003", name: "王大明", tokenUsage: 23456, conversationCount: 15, avgResponseTime: 2.5, cost: 2.34),
    CustomerUsage(id: "004", name: "陳小美", tokenUsage: 12345, conversationCount: 12, avgResponseTime: 1.9, cost: 1.23),
    CustomerUsage(id: "005", name: "劉小強", tokenUsage: 9876, conversationCount: 8, avgResponseTime: 2.3, cost: 0.98)
]

#Preview {
    BillingSystemView()
        .environmentObject(AuthService(modelContext: try! ModelContainer(for: User.self).mainContext))
} 