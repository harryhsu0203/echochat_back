/*
  用途: 將 database.json 內的 line_api_settings 既有明文 Channel Token/Secret 轉為 AES-256-GCM 加密格式
  需求: 環境變數 LINE_SECRET_KEY
  執行: NODE_ENV=production LINE_SECRET_KEY="your-strong-secret" node migrate-line-tokens.js
*/
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function getEncryptionKey() {
  const secret = process.env.LINE_SECRET_KEY;
  if (!secret || secret.length < 10) {
    console.error('缺少或無效的 LINE_SECRET_KEY，無法進行加密遷移');
    process.exit(1);
  }
  return crypto.createHash('sha256').update(secret).digest();
}

function encryptSensitive(plainText) {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(String(plainText), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `v1:gcm:${iv.toString('base64')}:${tag.toString('base64')}:${enc.toString('base64')}`;
}

function isEncrypted(value) {
  return typeof value === 'string' && value.startsWith('v1:gcm:');
}

async function main() {
  const dataDir = process.env.DATA_DIR || path.join(__dirname, 'data');
  const dataFile = path.join(dataDir, 'database.json');

  if (!fs.existsSync(dataFile)) {
    console.error('找不到資料檔:', dataFile);
    process.exit(1);
  }

  const raw = fs.readFileSync(dataFile, 'utf8');
  const db = JSON.parse(raw);
  const list = db.line_api_settings || [];

  let changed = 0;
  for (const rec of list) {
    if (rec.channel_access_token && !isEncrypted(rec.channel_access_token)) {
      rec.channel_access_token = encryptSensitive(rec.channel_access_token);
      changed++;
    }
    if (rec.channel_secret && !isEncrypted(rec.channel_secret)) {
      rec.channel_secret = encryptSensitive(rec.channel_secret);
      changed++;
    }
  }

  if (changed > 0) {
    fs.writeFileSync(dataFile, JSON.stringify(db, null, 2));
    console.log(`完成，加密更新 ${changed} 個欄位`);
  } else {
    console.log('無需更新，所有欄位皆為加密格式或為空');
  }
}

main().catch(err => {
  console.error('遷移失敗:', err);
  process.exit(1);
});

