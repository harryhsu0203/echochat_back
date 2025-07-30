//
//  PlanSelectionView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI

struct PlanSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanType = .professional
    
    enum PlanType: String, CaseIterable {
        case basic = "基礎版"
        case professional = "專業版"
        case enterprise = "企業版"
        
        var price: String {
            switch self {
            case .basic: return "$299"
            case .professional: return "$599"
            case .enterprise: return "$1,299"
            }
        }
        
        var features: [String] {
            switch self {
            case .basic:
                return [
                    "支援 2 個平台串接",
                    "每月 1,000 次對話",
                    "基礎 AI 訓練",
                    "標準客服時間",
                    "基礎數據分析",
                    "電子郵件支援",
                    "多語言支援 (中英文)",
                    "基礎知識庫管理"
                ]
            case .professional:
                return [
                    "支援 5 個平台串接",
                    "每月 5,000 次對話",
                    "進階 AI 訓練",
                    "24/7 客服支援",
                    "詳細數據分析",
                    "優先技術支援",
                    "自定義品牌設定",
                    "多語言支援 (中英日韓)",
                    "進階知識庫管理",
                    "情感分析功能",
                    "智能轉接人工"
                ]
            case .enterprise:
                return [
                    "無限平台串接",
                    "無限對話次數",
                    "客製化 AI 訓練",
                    "專屬客服經理",
                    "進階數據分析",
                    "24/7 專線支援",
                    "API 整合服務",
                    "專屬部署選項",
                    "全語言支援",
                    "企業級安全認證",
                    "客製化開發服務",
                    "專屬培訓課程"
                ]
            }
        }
        
        var isRecommended: Bool {
            return self == .professional
        }
        
        var buttonTitle: String {
            switch self {
            case .basic, .professional:
                return "選擇方案"
            case .enterprise:
                return "聯繫我們"
            }
        }
        
        var buttonStyle: ButtonStyle {
            switch self {
            case .basic, .professional:
                return .primary
            case .enterprise:
                return .outline
            }
        }
    }
    
    enum ButtonStyle {
        case primary
        case outline
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // 標題區域
                        VStack(spacing: 12) {
                            Text("選擇適合您的方案")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("靈活的訂閱方案，適合不同規模的企業\n2025年新價格，更優惠的成本效益與功能")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                        .padding(.top, 20)
                        
                        // 方案卡片
                        VStack(spacing: 20) {
                            ForEach(PlanType.allCases, id: \.self) { plan in
                                PlanCard(
                                    plan: plan,
                                    isSelected: selectedPlan == plan,
                                    onSelect: { selectedPlan = plan }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 確認按鈕
                        Button(action: {
                            // 處理方案變更邏輯
                            dismiss()
                        }) {
                            Text("確認變更方案")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("方案選擇")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("方案選擇")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("關閉") {
                    dismiss()
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
    }
}

struct PlanCard: View {
    let plan: PlanSelectionView.PlanType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 推薦標籤
            if plan.isRecommended {
                HStack {
                    Spacer()
                    Text("推薦")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .rotationEffect(.degrees(45))
                        .offset(x: 8, y: -8)
                }
            } else {
                Spacer()
                    .frame(height: 28)
            }
            
            // 方案標題
            Text(plan.rawValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // 價格
            VStack(spacing: 4) {
                Text(plan.price)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.9))
                
                Text("/月")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 功能列表
            VStack(alignment: .leading, spacing: 12) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                }
            }
            
            Spacer()
            
            // 按鈕
            Button(action: onSelect) {
                Text(plan.buttonTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(plan.buttonStyle == .primary ? .white : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        plan.buttonStyle == .primary ? 
                        Color.blue : 
                        Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: plan.buttonStyle == .outline ? 1 : 0)
                    )
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    PlanSelectionView()
} 