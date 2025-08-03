#!/bin/bash

# EchoChat API 快速部署腳本

echo "🚀 EchoChat API 部署腳本"
echo "=========================="

# 檢查是否在正確的目錄
if [ ! -f "package.json" ]; then
    echo "❌ 錯誤：請在 echochat-api 目錄中執行此腳本"
    exit 1
fi

# 檢查 Git 是否已初始化
if [ ! -d ".git" ]; then
    echo "📦 初始化 Git 倉庫..."
    git init
    git add .
    git commit -m "Initial commit: EchoChat API"
    echo "✅ Git 倉庫已初始化"
else
    echo "📝 更新 Git 倉庫..."
    git add .
    git commit -m "Update: $(date)"
    echo "✅ Git 倉庫已更新"
fi

# 檢查是否有遠端倉庫
if ! git remote get-url origin > /dev/null 2>&1; then
    echo "🔗 請設定 GitHub 遠端倉庫："
    echo "git remote add origin https://github.com/your-username/echochat-api.git"
    echo "git push -u origin main"
else
    echo "📤 推送到 GitHub..."
    git push origin main
    echo "✅ 已推送到 GitHub"
fi

echo ""
echo "🎯 下一步："
echo "1. 前往 https://render.com"
echo "2. 建立新的 Web Service"
echo "3. 連接您的 GitHub 倉庫"
echo "4. 設定環境變數"
echo "5. 部署服務"
echo ""
echo "📋 詳細步驟請參考 DEPLOYMENT_GUIDE.md" 