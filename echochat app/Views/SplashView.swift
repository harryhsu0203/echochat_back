//
//  SplashView.swift
//  echochat app
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // 紫色漸層背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.2, blue: 0.8), // 深紫色
                        Color(red: 0.6, green: 0.4, blue: 0.9), // 中紫色
                        Color(red: 0.8, green: 0.6, blue: 1.0)  // 淺紫色
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 機器人圖標
                    Image(systemName: "robot")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    // 應用程式名稱
                    Text("EchoChat")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    // 副標題
                    Text("智能聊天機器人管理系統")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    // 描述文字
                    Text("提供強大的對話管理和知識庫功能，讓您的聊天機器人更加智能和人性化")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    Spacer()
                    
                    // 載入指示器
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .opacity(opacity)
                }
                .padding()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2)) {
                    self.size = 1.0
                    self.opacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
} 