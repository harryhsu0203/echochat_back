#!/bin/bash

# Xcode 建置後自動同步腳本
# 在 Xcode 中設定為 Build Phase 執行

# 獲取專案根目錄
PROJECT_DIR="${SRCROOT}"
cd "$PROJECT_DIR"

# 執行自動同步腳本
if [ -f "scripts/auto-sync.sh" ]; then
    chmod +x scripts/auto-sync.sh
    ./scripts/auto-sync.sh "Xcode 建置更新: $(date '+%Y-%m-%d %H:%M:%S')"
else
    echo "警告: 找不到自動同步腳本 scripts/auto-sync.sh"
fi 