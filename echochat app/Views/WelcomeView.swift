//
//  WelcomeView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import UIKit

struct WelcomeView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("apiKey") private var apiKey = ""
    
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
            
            VStack(spacing: 0) {
                // 導航欄
                HStack {
                    // 左側 Logo
                    HStack(spacing: 8) {
                        Image(systemName: "robot")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("EchoChat")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // 右側導航連結
                    HStack(spacing: 20) {
                        Text("功能特色")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("統計數據")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("管理登入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // 主要內容區域
                VStack(spacing: 30) {
                    // 機器人圖示
                    Image(systemName: "robot")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    // 應用程式名稱
                    Text("EchoChat")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // 標語
                    Text("智能聊天機器人管理系統")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // 描述文字
                    Text("提供強大的對話管理和知識庫功能，讓您的聊天機器人更加智能和人性化")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // 按鈕區域
                    VStack(spacing: 15) {
                        // 主要按鈕 - 管理登入
                        Button(action: {
                            hasSeenWelcome = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                Text("管理登入")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // 次要按鈕 - 了解更多
                        Button(action: {
                            // 了解更多功能
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                Text("了解更多")
                                    .font(.headline)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    WelcomeView()
} 