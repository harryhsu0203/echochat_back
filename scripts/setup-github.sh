#!/bin/bash

# GitHub 設定腳本
# 幫助快速設定 GitHub 遠端倉庫

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查 Git 是否已初始化
check_git() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "此目錄不是 Git 倉庫"
        log_info "請先執行: git init"
        exit 1
    fi
}

# 檢查遠端倉庫
check_remote() {
    if git remote get-url origin > /dev/null 2>&1; then
        log_info "已設定遠端倉庫: $(git remote get-url origin)"
        return 0
    else
        return 1
    fi
}

# 設定遠端倉庫
setup_remote() {
    local repo_url="$1"
    
    if [ -z "$repo_url" ]; then
        log_error "請提供 GitHub 倉庫 URL"
        log_info "範例: https://github.com/username/echochat-app.git"
        exit 1
    fi
    
    log_info "正在設定遠端倉庫..."
    git remote add origin "$repo_url"
    log_success "遠端倉庫已設定: $repo_url"
}

# 推送到 GitHub
push_to_github() {
    log_info "正在推送到 GitHub..."
    
    # 檢查是否有未提交的變更
    if ! git diff-index --quiet HEAD --; then
        log_warning "發現未提交的變更，正在提交..."
        git add .
        git commit -m "初始提交: EchoChat iOS 應用程式"
    fi
    
    # 推送到 GitHub
    if git push -u origin main; then
        log_success "成功推送到 GitHub！"
    else
        log_error "推送失敗"
        log_info "請檢查："
        log_info "1. GitHub 倉庫是否存在"
        log_info "2. 是否有推送權限"
        log_info "3. 網路連線是否正常"
        exit 1
    fi
}

# 顯示使用說明
show_usage() {
    echo "GitHub 設定腳本"
    echo ""
    echo "用法:"
    echo "  $0 <github-repo-url>"
    echo ""
    echo "參數:"
    echo "  github-repo-url    GitHub 倉庫 URL"
    echo ""
    echo "範例:"
    echo "  $0 https://github.com/username/echochat-app.git"
    echo ""
    echo "注意:"
    echo "  1. 請先在 GitHub 上建立倉庫"
    echo "  2. 確保已設定 Git 用戶資訊"
    echo "  3. 確保有推送權限"
}

# 檢查 Git 用戶資訊
check_git_config() {
    local user_name=$(git config user.name)
    local user_email=$(git config user.email)
    
    if [ -z "$user_name" ] || [ -z "$user_email" ]; then
        log_warning "Git 用戶資訊未設定"
        log_info "請執行以下命令設定："
        log_info "git config --global user.name \"您的姓名\""
        log_info "git config --global user.email \"您的郵箱\""
        return 1
    fi
    
    log_info "Git 用戶資訊: $user_name <$user_email>"
    return 0
}

# 主函數
main() {
    log_info "開始設定 GitHub 工作區..."
    
    # 檢查參數
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    if [ -z "$1" ]; then
        log_error "請提供 GitHub 倉庫 URL"
        show_usage
        exit 1
    fi
    
    # 檢查 Git
    check_git
    
    # 檢查 Git 配置
    if ! check_git_config; then
        exit 1
    fi
    
    # 檢查是否已設定遠端倉庫
    if check_remote; then
        log_warning "遠端倉庫已存在"
        read -p "是否要重新設定？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote remove origin
            setup_remote "$1"
        else
            log_info "保持現有設定"
        fi
    else
        setup_remote "$1"
    fi
    
    # 推送到 GitHub
    push_to_github
    
    log_success "GitHub 工作區設定完成！"
    log_info ""
    log_info "下一步："
    log_info "1. 在 GitHub 上查看您的倉庫"
    log_info "2. 設定 GitHub Actions secrets（如需要）"
    log_info "3. 開始使用自動同步功能："
    log_info "   ./scripts/auto-sync.sh"
}

# 執行主函數
main "$1" 