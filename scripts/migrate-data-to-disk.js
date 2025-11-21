#!/usr/bin/env node
/**
 * 將專案內的 data 資料夾內容搬移到 DATA_DIR（通常是 Render 的 Persistent Disk）。
 * - 預設只複製不存在的檔案，避免覆蓋已經在磁碟上的正式資料。
 * - 若需要強制覆蓋，可加上 --force 參數。
 */

const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const sourceDir = path.join(projectRoot, 'data');
const targetDir = process.env.DATA_DIR || path.join(projectRoot, 'data');
const force = process.argv.includes('--force');

function log(message) {
    console.log(`📦 [migrate-data] ${message}`);
}

function copyFileSafe(src, dest) {
    if (!force && fs.existsSync(dest)) {
        log(`跳過 ${path.basename(src)}，目的地已存在（若需覆蓋請加 --force）`);
        return;
    }

    if (force && fs.existsSync(dest)) {
        const backupPath = `${dest}.backup-${Date.now()}`;
        fs.copyFileSync(dest, backupPath);
        log(`已備份現有檔案到 ${backupPath}`);
    }

    fs.copyFileSync(src, dest);
    log(`已複製 ${path.basename(src)} → ${dest}`);
}

function main() {
    if (!fs.existsSync(sourceDir)) {
        console.error('❌ 找不到 source 資料夾:', sourceDir);
        process.exit(1);
    }

    if (sourceDir === targetDir) {
        log('DATA_DIR 與 source 相同，無需搬移。');
        process.exit(0);
    }

    fs.mkdirSync(targetDir, { recursive: true });
    const files = fs.readdirSync(sourceDir);

    if (!files.length) {
        log('source 資料夾為空，無需搬移。');
        process.exit(0);
    }

    files.forEach(file => {
        const srcPath = path.join(sourceDir, file);
        const destPath = path.join(targetDir, file);
        const stat = fs.statSync(srcPath);

        if (stat.isDirectory()) {
            fs.mkdirSync(destPath, { recursive: true });
            log(`建立資料夾 ${destPath}`);
        } else {
            copyFileSafe(srcPath, destPath);
        }
    });

    log('資料搬移完成 ✅');
}

main();

