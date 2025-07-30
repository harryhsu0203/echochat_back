#!/bin/bash

# EchoChat 自動同步腳本
# 用於自動提交和推送程式碼到 GitHub

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

# 檢查 Git 狀態
check_git_status() {
    if ! git status --porcelain | grep -q .; then
        log_warning "沒有變更需要提交"
        return 1
    fi
    return 0
}

# 獲取變更摘要
get_changes_summary() {
    git status --porcelain | head -5 | sed 's/^/  /'
    if [ $(git status --porcelain | wc -l) -gt 5 ]; then
        echo "  ... 還有更多變更"
    fi
}

# 自動提交
auto_commit() {
    local commit_message="$1"
    
    if [ -z "$commit_message" ]; then
        commit_message="自動更新: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    log_info "正在提交變更..."
    log_info "變更摘要:"
    get_changes_summary
    
    git add .
    git commit -m "$commit_message"
    
    log_success "變更已提交: $commit_message"
}

# 推送到遠端
push_to_remote() {
    local branch="${1:-main}"
    
    log_info "正在推送到遠端倉庫..."
    
    if git push origin "$branch"; then
        log_success "成功推送到 GitHub"
    else
        log_error "推送失敗"
        return 1
    fi
}

# 檢查遠端倉庫
check_remote() {
    if ! git remote get-url origin > /dev/null 2>&1; then
        log_error "未設定遠端倉庫 'origin'"
        log_info "請先設定 GitHub 遠端倉庫:"
        log_info "git remote add origin <your-github-repo-url>"
        return 1
    fi
    
    log_info "遠端倉庫: $(git remote get-url origin)"
}

# 主函數
main() {
    log_info "開始 EchoChat 自動同步..."
    
    # 檢查遠端倉庫
    if ! check_remote; then
        exit 1
    fi
    
    # 檢查是否有變更
    if ! check_git_status; then
        exit 0
    fi
    
    # 自動提交
    auto_commit "$1"
    
    # 推送到遠端
    if push_to_remote; then
        log_success "自動同步完成！"
    else
        log_error "自動同步失敗"
        exit 1
    fi
}

# 顯示使用說明
show_usage() {
    echo "EchoChat 自動同步腳本"
    echo ""
    echo "用法:"
    echo "  $0 [commit_message]"
    echo ""
    echo "參數:"
    echo "  commit_message    可選的提交訊息"
    echo ""
    echo "範例:"
    echo "  $0                    # 使用預設提交訊息"
    echo "  $0 '修復登入問題'      # 使用自訂提交訊息"
}

# 檢查參數
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# 執行主函數
main "$1" 