//
//  BillingSystemView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import SwiftData
import UIKit

// 格式化最後活動時間
func formatLastActivity(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    if let date = formatter.date(from: dateString) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "剛剛"
        } else if timeInterval < 3600 {
            return "\(Int(timeInterval / 60))分鐘前"
        } else if timeInterval < 86400 {
            return "\(Int(timeInterval / 3600))小時前"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
    }
    return "未知"
}

struct BillingSystemView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject private var authService: AuthService
    @StateObject private var billingService = BillingAPIService.shared
    
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingUsageDetails = false
    @State private var selectedCustomer: CustomerUsage?
    @State private var showingPlanSelection = false
    
    // 資料狀態
    @State private var billingOverview: BillingOverview?
    @State private var usageData: [UsageRecord] = []
    @State private var customers: [CustomerUsage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                    OverviewCard(overview: billingOverview, isLoading: isLoading)
                    
                    // 時間範圍選擇器
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                    
                    // 使用量統計
                    UsageStatisticsView(timeRange: selectedTimeRange, usageData: usageData)
                    
                    // 客戶使用量列表
                    if !customers.isEmpty {
                        CustomerUsageListView(
                            timeRange: selectedTimeRange,
                            customers: customers,
                            onCustomerTap: { customer in
                                selectedCustomer = customer
                                showingUsageDetails = true
                            }
                        )
                    } else if isLoading {
                        ProgressView("載入客戶資料...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("暫無客戶資料")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
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
        .onAppear {
            loadBillingData()
        }
        .refreshable {
            await refreshBillingData()
        }
    }
    
    // MARK: - 資料載入方法
    private func loadBillingData() {
        Task {
            await refreshBillingData()
        }
    }
    
    private func refreshBillingData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let overviewTask = billingService.getBillingOverview()
            async let usageTask = billingService.getUsageStatistics(timeRange: selectedTimeRange.rawValue)
            async let customersTask = billingService.getCustomerUsage(timeRange: selectedTimeRange.rawValue)
            
            let (overview, usage, customersList) = try await (overviewTask, usageTask, customersTask)
            
            await MainActor.run {
                self.billingOverview = overview
                self.usageData = usage
                self.customers = customersList
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    

}

// 總覽卡片
struct OverviewCard: View {
    let overview: BillingOverview?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("載入中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else if let overview = overview {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("總使用量")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(overview.totalUsage.apiCalls)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("API 呼叫")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("目前方案")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(overview.currentPlan)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("Next: \(formatDate(overview.nextBillingDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack {
                    StatItem(title: "對話數", value: "\(overview.totalUsage.conversations)", icon: "bubble.left.and.bubble.right.fill", color: .green)
                    Spacer()
                    StatItem(title: "訊息數", value: "\(overview.totalUsage.messages)", icon: "message.fill", color: .blue)
                    Spacer()
                    StatItem(title: "使用率", value: "\(Int(overview.usage.conversations))%", icon: "chart.pie.fill", color: .orange)
                }
            } else {
                Text("無法載入帳務資料")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
        return "N/A"
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
    let usageData: [UsageRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用量趨勢")
                .font(.headline)
                .foregroundColor(.primary)
            
            if usageData.isEmpty {
                Text("暫無使用量資料")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // 簡化的圖表
                VStack(spacing: 12) {
                    HStack {
                        Text("API 呼叫次數")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(usageData.last?.apiCalls ?? 0)")
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
                        Text("對話數量")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(usageData.last?.conversations ?? 0)")
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
}

// 客戶使用量列表
struct CustomerUsageListView: View {
    let timeRange: BillingSystemView.TimeRange
    let customers: [CustomerUsage]
    let onCustomerTap: (CustomerUsage) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("客戶使用量")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(customers, id: \.id) { customer in
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
                    
                    Text("\(customer.conversations) 個對話")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(customer.apiCalls)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("API calls")
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
                        DetailRow(title: "API 呼叫次數", value: "\(customer.apiCalls)", icon: "cpu.fill", color: .blue)
                        DetailRow(title: "對話數量", value: "\(customer.conversations)", icon: "bubble.left.and.bubble.right.fill", color: .green)
                        DetailRow(title: "訊息數量", value: "\(customer.messages)", icon: "message.fill", color: .orange)
                        DetailRow(title: "最後活動", value: formatLastActivity(customer.lastActivity), icon: "clock.fill", color: .purple)
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



#Preview {
    BillingSystemView()
        .environmentObject(AuthService(modelContext: try! ModelContainer(for: User.self).mainContext))
} 