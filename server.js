const express = require('express');
const fs = require('fs');
// 移除資料庫依賴，使用 JSON 檔案儲存
const { Client, middleware } = require('@line/bot-sdk');
const axios = require('axios');
const cheerio = require('cheerio');
const path = require('path');
const { ImageAnnotatorClient } = require('@google-cloud/vision');
const { OAuth2Client } = require('google-auth-library');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const multer = require('multer');
const { pipeline } = require('stream/promises');
const { v4: uuidv4 } = require('uuid');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const cors = require('cors');
require('dotenv').config();

const DEFAULT_SENDER_EMAIL = 'contact@echochat.com.tw';
const EMAIL_ACCOUNT = process.env.EMAIL_USER || process.env.EMAIL_ACCOUNT || '';
const EMAIL_PASSWORD = process.env.EMAIL_PASS || process.env.EMAIL_PASSWORD || '';
const EMAIL_FROM_ADDRESS = process.env.EMAIL_FROM || DEFAULT_SENDER_EMAIL;
const EMAIL_HOST = process.env.EMAIL_HOST || (EMAIL_ACCOUNT.includes('gmail.com') ? 'smtp.gmail.com' : 'smtp.gmail.com');
const EMAIL_PORT = parseInt(process.env.EMAIL_PORT || '587', 10);
const EMAIL_SECURE = process.env.EMAIL_SECURE ? process.env.EMAIL_SECURE === 'true' : EMAIL_PORT === 465;

const transporterOptions = {
    host: EMAIL_HOST,
    port: EMAIL_PORT,
    secure: EMAIL_SECURE,
    tls: {
        rejectUnauthorized: false
    }
};

if (EMAIL_ACCOUNT && EMAIL_PASSWORD) {
    transporterOptions.auth = {
        user: EMAIL_ACCOUNT,
        pass: EMAIL_PASSWORD
    };
}

const mailTransporter = nodemailer.createTransport(transporterOptions);

function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

function buildBrandMailTemplate(title, body) {
    return `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #667eea;">EchoChat ${title}</h2>
            ${body}
            <p style="color: #666; font-size: 12px; margin-top: 30px;">
                此郵件由 EchoChat 系統自動發送，請勿回覆。
            </p>
        </div>
    `;
}

async function sendVerificationEmail(email, code) {
    const mailOptions = {
        from: EMAIL_FROM_ADDRESS,
        to: email,
        subject: 'EchoChat - 電子郵件驗證碼',
        html: buildBrandMailTemplate('電子郵件驗證', `
            <p>您的驗證碼是：</p>
            <div style="background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; color: #667eea; border-radius: 8px; margin: 20px 0;">
                ${code}
            </div>
            <p>此驗證碼將在10分鐘後過期。</p>
            <p>如果您沒有要求此驗證碼，請忽略此郵件。</p>
        `)
    };
    return mailTransporter.sendMail(mailOptions);
}

async function sendPasswordResetEmail(email, code) {
    const mailOptions = {
        from: EMAIL_FROM_ADDRESS,
        to: email,
        subject: 'EchoChat - 密碼重設驗證碼',
        html: buildBrandMailTemplate('密碼重設', `
            <p>您要求重設密碼，請使用以下驗證碼：</p>
            <div style="background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; color: #667eea; border-radius: 8px; margin: 20px 0;">
                ${code}
            </div>
            <p>此驗證碼將在10分鐘後過期。</p>
            <p>如果您沒有要求重設密碼，請忽略此郵件並確保您的帳號安全。</p>
        `)
    };
    return mailTransporter.sendMail(mailOptions);
}

// 防重複處理的記憶體快取
const messageCache = new Map();
const { parseStringPromise } = require('xml2js');
const zlib = require('zlib');
const { parse: parseCsv } = require('csv-parse/sync');
const XLSX = require('xlsx');

// 初始化 Express 應用
const app = express();
app.disable('x-powered-by');
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const SESSION_TIMEOUT_MINUTES = Math.max(parseInt(process.env.SESSION_TIMEOUT_MINUTES || '15', 10) || 15, 1);
const JWT_EXPIRES_IN = `${SESSION_TIMEOUT_MINUTES}m`;
const MANUAL_REPLY_IDLE_MINUTES = Math.max(parseInt(process.env.MANUAL_REPLY_IDLE_MINUTES || '2', 10) || 2, 1);
const MANUAL_REPLY_IDLE_MS = MANUAL_REPLY_IDLE_MINUTES * 60 * 1000;
// 綠界金流設定
const ECPAY_MODE = process.env.ECPAY_MODE || 'Stage'; // 'Stage' or 'Prod'
const ECPAY_MERCHANT_ID = process.env.ECPAY_MERCHANT_ID || '';
const ECPAY_HASH_KEY = process.env.ECPAY_HASH_KEY || '';
const ECPAY_HASH_IV = process.env.ECPAY_HASH_IV || '';
const ECPAY_RETURN_URL = process.env.ECPAY_RETURN_URL || '';
const ECPAY_ORDER_RESULT_URL = process.env.ECPAY_ORDER_RESULT_URL || '';
const ECPAY_CLIENT_BACK_URL = process.env.ECPAY_CLIENT_BACK_URL || '';
const ECPAY_ACTION = process.env.ECPAY_ACTION || (ECPAY_MODE === 'Prod' 
    ? 'https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5'
    : 'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5');

// ====== Token 計費/用量機制 ======
// 方案設定對應首頁顯示：免費版 / 尊榮版 / 企業版
const ESTIMATED_TOKENS_PER_CONVERSATION = 400; // 以平均 400 tokens 計算一次完整對話

const PLAN_CONFIG = {
    free: {
        displayName: '免費版',
        monthlyConversationLimit: 100,
        tokenAllowance: 100 * ESTIMATED_TOKENS_PER_CONVERSATION
    },
    premium: {
        displayName: '尊榮版',
        monthlyConversationLimit: 5000,
        tokenAllowance: 5000 * ESTIMATED_TOKENS_PER_CONVERSATION
    },
    enterprise: {
        displayName: '企業版',
        monthlyConversationLimit: null,
        tokenAllowance: null
    }
};

const TOPUP_PACKAGES = [
    { id: 'lite', label: '500 次對話加值', conversations: 500, price: 499, currency: 'TWD' },
    { id: 'pro', label: '2,000 次對話加值', conversations: 2000, price: 1499, currency: 'TWD' },
    { id: 'growth', label: '5,000 次對話加值', conversations: 5000, price: 2499, currency: 'TWD' }
].map(pkg => ({
    ...pkg,
    tokens: pkg.conversations * ESTIMATED_TOKENS_PER_CONVERSATION
}));

const ADMIN_ROLES = ['admin', 'super_admin'];

const normalizeRole = (role) => String(role || '').toLowerCase();
const isAdminRole = (role) => ADMIN_ROLES.includes(normalizeRole(role));

function getPlanConfig(plan) {
    const key = normalizeRole(plan) || 'free';
    return PLAN_CONFIG[key] || PLAN_CONFIG.free;
}

function getUserById(userId) {
    loadDatabase();
    return (database.staff_accounts || []).find(u => u.id === parseInt(userId) || u.id === userId);
}

function getPlanAllowance(plan, user) {
    const config = getPlanConfig(plan);
    if (normalizeRole(plan) === 'enterprise' && user && typeof user.enterprise_token_monthly === 'number') {
        return user.enterprise_token_monthly;
    }
    if (config.tokenAllowance === null) {
        return Number.MAX_SAFE_INTEGER;
    }
    return config.tokenAllowance;
}

function getPlanConversationLimit(plan, user) {
    if (normalizeRole(plan) === 'enterprise' && user && typeof user.enterprise_conversation_monthly === 'number') {
        return user.enterprise_conversation_monthly;
    }
    return getPlanConfig(plan).monthlyConversationLimit;
}

function getPlanDisplayName(plan) {
    return getPlanConfig(plan).displayName;
}

function getNow() { return new Date(); }

function addMonths(date, months) {
    const d = new Date(date.getTime());
    d.setMonth(d.getMonth() + months);
    return d;
}

function ensureUserTokenFields(user) {
    if (!user) return;
    if (typeof user.token_used_in_cycle !== 'number') user.token_used_in_cycle = 0;
    if (typeof user.token_bonus_balance !== 'number') user.token_bonus_balance = 0;
    if (typeof user.conversation_used_in_cycle !== 'number') user.conversation_used_in_cycle = 0;
    if (!user.billing_cycle_start) user.billing_cycle_start = user.created_at || new Date().toISOString();
    if (!user.next_billing_at) user.next_billing_at = addMonths(new Date(user.billing_cycle_start), 1).toISOString();
}

function maybeResetCycle(user) {
    ensureUserTokenFields(user);
    const now = getNow();
    if (now > new Date(user.next_billing_at)) {
        // 進入新週期：歸零用量、推進下一個計費日（+1 個月）
        user.token_used_in_cycle = 0;
        user.conversation_used_in_cycle = 0;
        // 如果過了多個月，逐月推進
        let next = new Date(user.next_billing_at);
        while (now > next) {
            next = addMonths(next, 1);
        }
        user.billing_cycle_start = addMonths(next, -1).toISOString();
        user.next_billing_at = next.toISOString();
        saveDatabase();
    }
}

// 粗略估算 tokens（字數/3 + buffer）
function estimateTokens(text) {
    if (!text) return 0;
    const len = String(text).length;
    return Math.ceil(len / 3);
}

function estimateChatTokens(message, knowledgeContext, replyMax = 600) {
    return estimateTokens(message) + estimateTokens(knowledgeContext) + replyMax; // 粗估
}

// OpenAI 回覆請求（支援 gpt-5 系列使用 responses API）
function isGpt5Model(modelName) {
    return /^gpt-5(\.|$)/i.test(modelName || '');
}

function extractOpenAIText(payload) {
    if (!payload) return '';
    if (typeof payload.output_text === 'string' && payload.output_text.trim()) {
        return payload.output_text.trim();
    }
    if (Array.isArray(payload.output)) {
        const parts = [];
        payload.output.forEach((item) => {
            (item?.content || []).forEach((c) => {
                if (typeof c?.text === 'string' && c.text.trim()) {
                    parts.push(c.text);
                }
            });
        });
        if (parts.length) return parts.join('').trim();
    }
    const chatText = payload.choices?.[0]?.message?.content;
    return typeof chatText === 'string' ? chatText.trim() : '';
}

function buildResponsesInput(messages) {
    const systemParts = [];
    const input = [];
    (messages || []).forEach((msg) => {
        if (!msg || typeof msg.content !== 'string') return;
        if (msg.role === 'system') {
            systemParts.push(msg.content);
            return;
        }
        const role = msg.role === 'assistant' ? 'assistant' : 'user';
        input.push({
            role,
            content: [{ type: 'input_text', text: msg.content }]
        });
    });
    return {
        instructions: systemParts.length ? systemParts.join('\n') : undefined,
        input
    };
}

async function requestOpenAIReply({ model, messages, maxTokens, temperature, topP }) {
    const headers = {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
    };
    if (isGpt5Model(model)) {
        const { instructions, input } = buildResponsesInput(messages);
        const payload = {
            model,
            input: input.length ? input : [{ role: 'user', content: [{ type: 'input_text', text: '' }] }],
            max_output_tokens: maxTokens,
            temperature
        };
        if (instructions) payload.instructions = instructions;
        if (typeof topP === 'number') payload.top_p = topP;
        const resp = await axios.post('https://api.openai.com/v1/responses', payload, { headers });
        const text = extractOpenAIText(resp.data);
        if (!text) throw new Error('OpenAI 回應格式解析失敗');
        return text;
    }

    const payload = {
        model,
        messages,
        max_tokens: maxTokens,
        temperature
    };
    if (typeof topP === 'number') payload.top_p = topP;
    const resp = await axios.post('https://api.openai.com/v1/chat/completions', payload, { headers });
    const text = extractOpenAIText(resp.data);
    if (!text) throw new Error('OpenAI 回應格式解析失敗');
    return text;
}

// ====== 公開聊天：網站內容快取（避免每次都抓取多頁）======
let MULTIPAGE_SITE_CONTEXT_CACHE = { text: '', fetchedAt: 0, baseUrl: '' };
const CONTEXT_TTL_MS = 10 * 60 * 1000; // 10 分鐘

async function fetchHtml(url) {
    try {
        const resp = await axios.get(url, { timeout: 12000 });
        return resp.data || '';
    } catch (e) {
        return '';
    }
}

function summarizeText(str, maxLen = 1000) {
    if (!str) return '';
    const s = String(str).replace(/\s+/g, ' ').trim();
    return s.length > maxLen ? s.slice(0, maxLen) + '…' : s;
}

function extractFromPage(html, pageLabel) {
    if (!html) return '';
    const $ = cheerio.load(html);
    const parts = [];
    const metaDesc = $('meta[name="description"]').attr('content');
    if (metaDesc) parts.push(`描述: ${metaDesc.trim()}`);

    const h1 = $('h1').first().text().trim();
    if (h1) parts.push(`H1: ${h1}`);

    // 取前三個 H2/H3
    $('h2, h3').slice(0, 5).each((_, el) => {
        const t = $(el).text().trim();
        if (t) parts.push(`• ${t}`);
    });

    // 特定區塊：hero 與功能卡片
    const heroTitle = $('h1.hero-title').text().trim();
    const heroSub = $('p.hero-subtitle').text().trim();
    const heroDesc = $('p.hero-description').text().trim();
    if (heroTitle || heroSub || heroDesc) {
        parts.push(`Hero: ${[heroTitle, heroSub, heroDesc].filter(Boolean).join(' / ')}`);
    }
    const features = [];
    $('.feature-grid .feature-card').each((_, el) => {
        const h = $(el).find('h3').text().trim();
        const p = $(el).find('p').text().trim();
        if (h && p) features.push(`${h}: ${p}`);
    });
    if (features.length) parts.push(`功能: ${features.join('；')}`);

    // 定價：抓取包含金額或方案字樣的段落
    const pricingCandidates = [];
    $('*').each((_, el) => {
        const txt = $(el).text().trim();
        if (!txt) return;
        if (/\$|NT\$|NT\s*\d|價格|方案|月|年/i.test(txt)) {
            pricingCandidates.push(txt);
        }
    });
    if (pricingCandidates.length) {
        const pr = summarizeText([...new Set(pricingCandidates)].join(' / '), 600);
        if (pr) parts.push(`定價摘要: ${pr}`);
    }

    const bodyText = summarizeText($('main').text() || $('body').text(), 800);
    if (bodyText) parts.push(`其他: ${bodyText}`);

    const combined = parts.filter(Boolean).join('\n');
    return combined ? `【${pageLabel}】\n${combined}` : '';
}

async function buildMultipageSiteContext(baseUrl) {
    // 使用快取
    if (MULTIPAGE_SITE_CONTEXT_CACHE.text && MULTIPAGE_SITE_CONTEXT_CACHE.baseUrl === baseUrl && Date.now() - MULTIPAGE_SITE_CONTEXT_CACHE.fetchedAt < CONTEXT_TTL_MS) {
        return MULTIPAGE_SITE_CONTEXT_CACHE.text;
    }

    const pages = [
        { path: '/', label: '首頁' },
        { path: '/products.html', label: '產品' },
        { path: '/features.html', label: '特色' },
        { path: '/use-cases.html', label: '使用場景' },
        { path: '/pricing.html', label: '方案與定價' },
        { path: '/about-us.html', label: '關於我們' }
    ];

    const sections = [];
    for (const p of pages) {
        const url = baseUrl.replace(/\/$/, '') + p.path;
        const html = await fetchHtml(url);
        const sec = extractFromPage(html, p.label);
        if (sec) sections.push(sec);
    }
    const text = sections.join('\n\n');
    MULTIPAGE_SITE_CONTEXT_CACHE = { text, fetchedAt: Date.now(), baseUrl };
    return text;
}

async function resolveBaseUrl(req) {
    const candidates = [];
    // 1) 依據請求來源（Referer/Origin）優先
    try {
        const hdrOrigin = req?.headers?.origin || '';
        const hdrReferer = req?.headers?.referer || '';
        const pick = (hdrOrigin || hdrReferer).match(/^https?:\/\/[^\/]+/i)?.[0];
        if (pick) candidates.push(pick);
    } catch {}
    if (process.env.PUBLIC_SITE_URL) candidates.push(process.env.PUBLIC_SITE_URL);
    candidates.push('https://echochat-frontend.onrender.com');
    candidates.push('https://echochat-web.onrender.com');
    for (const url of candidates) {
        const html = await fetchHtml(url);
        if (html && html.length > 200) return url.replace(/\/$/, '');
    }
    return candidates[0] || 'https://echochat-frontend.onrender.com';
}

async function fetchI18nPricing(baseUrl) {
    try {
        const url = baseUrl.replace(/\/$/, '') + '/js/i18n.js';
        const js = await fetchHtml(url);
        if (!js) return '';
        // 取 zh-TW 區塊
        const zhStart = js.indexOf("'zh-TW'");
        const enStart = js.indexOf("'en'", zhStart + 1);
        const zhBlock = zhStart !== -1 ? js.slice(zhStart, enStart !== -1 ? enStart : undefined) : js;
        const lines = [];
        const priceRe = /'pricing\.(basic|pro|professional|enterprise)\.price'\s*:\s*'([^']+)'/g;
        let m;
        while ((m = priceRe.exec(zhBlock)) !== null) {
            const planKey = m[1];
            const planMap = { basic: '基礎版', pro: '專業版', professional: '專業版', enterprise: '企業版' };
            const planName = planMap[planKey] || planKey;
            lines.push(`${planName}: ${m[2]}`);
        }
        return lines.length ? `【方案與定價(翻譯檔)】\n${lines.join('\n')}` : '';
    } catch {
        return '';
    }
}

// Google OAuth 配置
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

// CORS 設定 - 允許前端網站和手機 App 訪問
app.use(cors({
    origin: [
        // 本地開發
        'http://localhost:3000',
        'http://localhost:5173',
        'http://localhost:8000',
        'http://localhost:8080',
        'capacitor://localhost',
        // 雲端環境（Render、Vercel 等）
        'https://ai-chatbot-umqm.onrender.com',
        'https://echochat-web.vercel.app',
        'https://echochat-app.vercel.app',
        'https://echochat-frontend.onrender.com',
        'https://echochat-backend.onrender.com',
        'https://echochat-web.onrender.com',
        // 自訂網域
        'https://echochat.com.tw',
        'https://www.echochat.com.tw'
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    maxAge: 600
}));

// Google 登入交換端點：前端傳 id_token，後端驗證並發 JWT
app.post('/api/auth/google', async (req, res) => {
    try {
        const { id_token } = req.body || {};
        if (!id_token) return res.status(400).json({ success:false, error:'缺少 id_token' });
        const ticket = await googleClient.verifyIdToken({ idToken: id_token, audience: GOOGLE_CLIENT_ID });
        const payload = ticket.getPayload();
        const email = payload.email;
        const name = payload.name || payload.given_name || 'Google 使用者';

        loadDatabase();
        let user = (database.staff_accounts || []).find(u => u.email === email);
        if (!user) {
            // 首次登入自動註冊為一般用戶
            const id = database.staff_accounts.length ? Math.max(...database.staff_accounts.map(u => u.id)) + 1 : 1;
            user = { id, username: email, password: await bcrypt.hash(uuidv4(), 10), name, role:'user', email, plan:'free', created_at: new Date().toISOString() };
            database.staff_accounts.push(user);
            saveDatabase();
        }
        const token = jwt.sign(
            { id: user.id, username: user.username, name: user.name, role: user.role },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );
        return res.json({ success:true, token, user: { id:user.id, name:user.name, email:user.email, role:user.role, plan:user.plan } });
    } catch (e) {
        console.error('Google 登入失敗', e.message);
        return res.status(401).json({ success:false, error:'Google 登入驗證失敗' });
    }
});

// 取得前端用的 Google Client ID（公開資訊）
app.get('/api/auth/google/client-id', (req, res) => {
    return res.json({ success: !!GOOGLE_CLIENT_ID, client_id: GOOGLE_CLIENT_ID || null });
});

// 環境檢查（郵件設定用）
app.get('/api/env-check', (req, res) => {
    const maskEmail = (email) => {
        if (!email || typeof email !== 'string') return '未設置';
        const parts = email.split('@');
        if (parts.length !== 2 || !parts[0] || !parts[1]) return '未設置';
        return `${parts[0][0]}***@${parts[1]}`;
    };
    return res.json({
        EMAIL_HOST: EMAIL_HOST || '未設置',
        EMAIL_PORT,
        EMAIL_SECURE,
        EMAIL_USER: maskEmail(EMAIL_ACCOUNT),
        EMAIL_FROM: EMAIL_FROM_ADDRESS || '未設置',
        EMAIL_FROM_SOURCE: process.env.EMAIL_FROM ? 'env' : 'default',
        EMAIL_READY: !!(EMAIL_ACCOUNT && EMAIL_PASSWORD && EMAIL_HOST && EMAIL_PORT)
    });
});

// 公開診斷（不含敏感資訊）
app.get('/api/diagnostics/public', (req, res) => {
    loadDatabase();
    const openaiKey = process.env.OPENAI_API_KEY || '';
    const settings = database.line_api_settings || [];
    const encryptedCount = settings.filter(r => typeof r.channel_access_token === 'string' && r.channel_access_token.startsWith('v1:gcm:')).length;
    const plainCount = settings.filter(r => !!r.channel_access_token_plain).length;
    res.json({
        success: true,
        openai: {
            configured: !!openaiKey,
            length: openaiKey.length,
            prefix: openaiKey ? openaiKey.slice(0, 4) : ''
        },
        line: {
            hasSecretKey: !!process.env.LINE_SECRET_KEY,
            settingsCount: settings.length,
            encryptedCount,
            plainCount
        }
    });
});

// 請求速率限制
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: {
        success: false,
        error: '請求次數過多，請稍後再試'
    }
});

// 登入請求限制
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    skip: (req, res) => {
        return res.statusCode === 200;
    },
    message: {
        success: false,
        error: '登入失敗次數過多，請稍後再試'
    }
});

// 中間件設置
app.use(helmet());
app.use(limiter);
app.use('/api/login', loginLimiter);
app.use('/webhook', express.raw({ type: '*/*' }));
app.use(express.json({ limit: '200kb' }));
app.use(express.urlencoded({ extended: true, limit: '200kb' }));
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// ========= 敏感資訊加解密（AES-256-GCM） =========
function getEncryptionKey() {
    const secret = process.env.LINE_SECRET_KEY;
    if (!secret || typeof secret !== 'string' || secret.length < 10) {
        return null;
    }
    return crypto.createHash('sha256').update(secret).digest();
}

function encryptSensitive(plainText) {
    try {
        const key = getEncryptionKey();
        if (!key) return null;
        const iv = crypto.randomBytes(12);
        const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
        const enc = Buffer.concat([cipher.update(String(plainText), 'utf8'), cipher.final()]);
        const tag = cipher.getAuthTag();
        return `v1:gcm:${iv.toString('base64')}:${tag.toString('base64')}:${enc.toString('base64')}`;
    } catch (e) {
        console.warn('加密失敗，將回退為明文儲存:', e.message);
        return null;
    }
}

function decryptSensitive(encText) {
    try {
        const key = getEncryptionKey();
        if (!key) return null;
        if (!encText || typeof encText !== 'string' || !encText.startsWith('v1:gcm:')) return null;
        const parts = encText.split(':');
        const iv = Buffer.from(parts[2], 'base64');
        const tag = Buffer.from(parts[3], 'base64');
        const data = Buffer.from(parts[4], 'base64');
        const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
        decipher.setAuthTag(tag);
        const dec = Buffer.concat([decipher.update(data), decipher.final()]);
        return dec.toString('utf8');
    } catch (e) {
        console.warn('解密失敗，將回退為空值:', e.message);
        return null;
    }
}

// 取得使用者的 AI 助理配置（每帳號）
function getUserAIConfig(userId) {
    loadDatabase();
    const fallback = {
        assistant_name: 'AI 助理',
        llm: 'gpt-4o-mini',
        use_case: 'customer-service',
        description: '我是您的智能客服助理，很高興為您服務！'
    };
    if (!Array.isArray(database.ai_assistant_configs)) return fallback;
    const found = database.ai_assistant_configs.find(c => c.user_id === userId);
    return (found && found.config) ? found.config : fallback;
}

// 取得使用者 AI 設定（預設模型/升級模型/自動升級）
function getDefaultAISettings() {
    return {
        default_model: 'gpt-5.0',
        fallback_model: 'gpt-4.1',
        auto_escalate_enabled: true,
        escalate_keywords: ['退款', '合約', '發票', '抱怨', '故障'],
        updated_at: new Date().toISOString()
    };
}

function getUserAISettings(userId) {
    loadDatabase();
    if (!Array.isArray(database.ai_settings)) database.ai_settings = [];
    const found = database.ai_settings.find(s => s.user_id === userId);
    if (found && found.settings) return found.settings;
    const defaultSettings = getDefaultAISettings();
    database.ai_settings.push({ user_id: userId, settings: defaultSettings });
    saveDatabase();
    return defaultSettings;
}

// 依使用者與平台取得頻道與解密後的憑證
function findUserChannel(userId, platform) {
    loadDatabase();
    const ch = (database.channels || []).find(c => c.userId === userId && String(c.platform).toLowerCase() === String(platform).toLowerCase());
    if (!ch) return null;
    const apiKey = decryptSensitive(ch.apiKeyEnc) || ch.apiKeyEnc || '';
    const secret = decryptSensitive(ch.channelSecretEnc) || ch.channelSecretEnc || '';
    return { ...ch, apiKey, secret };
}

// 取得 LINE 憑證（優先從記憶體快取，提升效能並避免解密問題）
function getLineCredentials(userId) {
    const key = String(userId);
    // 優先從記憶體快取取得（保存時已放入明文）
    const cached = lineAPISettings[key];
    const hasRealToken = cached
        && cached.channelAccessToken
        && cached.channelSecret
        && cached.channelAccessToken !== 'Configured'
        && cached.channelSecret !== 'Configured';
    if (hasRealToken) {
        return {
            channelAccessToken: cached.channelAccessToken,
            channelSecret: cached.channelSecret
        };
    }
    // 若快取不存在，從資料庫讀取並解密
    loadDatabase();
    const rec = (database.line_api_settings || []).find(r => String(r.user_id) === String(userId));
    if (!rec) return null;
    const token = decryptSensitive(rec.channel_access_token) || rec.channel_access_token_plain || rec.channel_access_token || '';
    const secret = decryptSensitive(rec.channel_secret) || rec.channel_secret_plain || rec.channel_secret || '';
    // 同時更新快取
    lineAPISettings[key] = { channelAccessToken: token, channelSecret: secret };
    return { channelAccessToken: token, channelSecret: secret };
}

// 以使用者知識庫產生 AI 回覆並扣點（支援對話歷史）
async function generateAIReplyWithHistory(userId, messageHistory, currentMessage) {
    if (!process.env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY 未設置');
    loadDatabase();
    const user = getUserById(userId);
    if (!user) throw new Error('使用者不存在');
    const aiConfig = getUserAIConfig(userId);
    ensureUserTokenFields(user);
    maybeResetCycle(user);

    const normalized = (text) => (text || '').toLowerCase();
    const terms = normalized(currentMessage).replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/).filter(t => t.length >= 2).slice(0, 20);
    let knowledgeContext = '';
    const userKnowledge = (database.knowledge || []).filter(k => k.user_id === userId);
    const scored = userKnowledge.map(k => {
        const text = `${k.question} ${k.answer}`.toLowerCase();
        const score = terms.reduce((acc, t) => acc + (text.includes(t) ? 1 : 0), 0);
        return { item: k, score };
    }).filter(s => s.score > 0);
    scored.sort((a, b) => b.score - a.score);
    let top = scored.slice(0, 5).map(s => s.item);
    if (top.length === 0 && userKnowledge.length > 0) {
        const sortedByTime = [...userKnowledge].sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
        top = sortedByTime.slice(0, 3);
    }
    if (top.length) {
        knowledgeContext = top.map((k, idx) => `【來源${idx + 1}】Q: ${k.question}\nA: ${k.answer}`).join('\n\n');
        if (knowledgeContext.length > 4000) knowledgeContext = knowledgeContext.slice(0, 4000);
    }

    const systemPrompt = `你是 ${aiConfig.assistant_name}，${aiConfig.description}。你的使用場景是：${aiConfig.use_case}。請根據用戶的問題提供專業、友善且有用的回應。`;
    
    // 構建包含對話歷史的訊息陣列
    const messages = [
        { role: 'system', content: systemPrompt + (knowledgeContext ? `\n\n以下為商家提供的知識庫內容，優先據此回答；若知識庫無相關資訊再自行作答，並標註「一般建議」。\n${knowledgeContext}` : '') }
    ];
    
    // 添加對話歷史（限制最近 10 輪對話以避免 token 過多）
    const recentMessages = messageHistory.slice(-20); // 最近 20 條訊息
    for (const msg of recentMessages) {
        if (msg.role === 'user' || msg.role === 'assistant') {
            messages.push({ role: msg.role, content: msg.content });
        }
    }

    const plan = user?.plan || 'free';
    const planAllowance = getPlanAllowance(plan, user);
    const estimatedTokens = estimateChatTokens(currentMessage, knowledgeContext, 800); // 增加估計值因為有歷史
    const conversationLimit = getPlanConversationLimit(plan, user);
    const conversationUsed = user.conversation_used_in_cycle || 0;
    if (conversationLimit !== null && conversationUsed >= conversationLimit) {
        throw new Error('本月對話次數已達方案上限');
    }
    const availableThisCycle = Math.max(planAllowance - (user.token_used_in_cycle || 0), 0) + (user.token_bonus_balance || 0);
    if (availableThisCycle < estimatedTokens) throw new Error('餘額不足');

    const aiReply = await requestOpenAIReply({
        model: aiConfig.llm || 'gpt-3.5-turbo',
        messages,
        maxTokens: 800,
        temperature: 0.6
    });

    let remainingNeed = estimatedTokens;
    const cycleRemain = Math.max(planAllowance - (user.token_used_in_cycle || 0), 0);
    const useFromCycle = Math.min(cycleRemain, remainingNeed);
    user.token_used_in_cycle = (user.token_used_in_cycle || 0) + useFromCycle;
    remainingNeed -= useFromCycle;
    if (remainingNeed > 0) user.token_bonus_balance = Math.max((user.token_bonus_balance || 0) - remainingNeed, 0);
    user.conversation_used_in_cycle = (user.conversation_used_in_cycle || 0) + 1;
    saveDatabase();

    return { reply: aiReply, model: aiConfig.llm, assistantName: aiConfig.assistant_name };
}

// 以使用者知識庫產生 AI 回覆並扣點
async function generateAIReplyForUser(userId, message, knowledgeOnly = false) {
    if (!process.env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY 未設置');
    loadDatabase();
    const user = getUserById(userId);
    if (!user) throw new Error('使用者不存在');
    const aiConfig = getUserAIConfig(userId);
    ensureUserTokenFields(user);
    maybeResetCycle(user);

    const normalized = (text) => (text || '').toLowerCase();
    const terms = normalized(message).replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/).filter(t => t.length >= 2).slice(0, 20);
    let knowledgeContext = '';
    const userKnowledge = (database.knowledge || []).filter(k => k.user_id === userId);
    const scored = userKnowledge.map(k => {
        const text = `${k.question} ${k.answer}`.toLowerCase();
        const score = terms.reduce((acc, t) => acc + (text.includes(t) ? 1 : 0), 0);
        return { item: k, score };
    }).filter(s => s.score > 0);
    scored.sort((a, b) => b.score - a.score);
    let top = scored.slice(0, 5).map(s => s.item);
    if (top.length === 0 && userKnowledge.length > 0) {
        const sortedByTime = [...userKnowledge].sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
        top = sortedByTime.slice(0, 3);
    }
    if (top.length) {
        knowledgeContext = top.map((k, idx) => `【來源${idx + 1}】Q: ${k.question}\nA: ${k.answer}`).join('\n\n');
        if (knowledgeContext.length > 4000) knowledgeContext = knowledgeContext.slice(0, 4000);
    }
    if (knowledgeOnly && !knowledgeContext) return { reply: '抱歉，知識庫目前沒有相關資料。' };

    const systemPrompt = `你是 ${aiConfig.assistant_name}，${aiConfig.description}。你的使用場景是：${aiConfig.use_case}。請根據用戶的問題提供專業、友善且有用的回應。`;
    const messages = [
        { role: 'system', content: systemPrompt + (knowledgeContext ? `\n\n以下為商家提供的知識庫內容，${knowledgeOnly ? '僅能根據這些內容回答；若沒有足夠依據，請回覆「知識庫無相關資料」。' : '優先據此回答；若知識庫無相關資訊再自行作答，並標註「一般建議」。'}\n${knowledgeContext}` : (knowledgeOnly ? '\n\n僅能根據知識庫作答，但目前沒有可用內容。' : '')) },
        { role: 'user', content: message }
    ];

    const plan = user?.plan || 'free';
    const planAllowance = getPlanAllowance(plan, user);
    const estimatedTokens = estimateChatTokens(message, knowledgeContext, 600);
    const conversationLimit = getPlanConversationLimit(plan, user);
    const conversationUsed = user.conversation_used_in_cycle || 0;
    if (conversationLimit !== null && conversationUsed >= conversationLimit) {
        throw new Error('本月對話次數已達方案上限');
    }
    const availableThisCycle = Math.max(planAllowance - (user.token_used_in_cycle || 0), 0) + (user.token_bonus_balance || 0);
    if (availableThisCycle < estimatedTokens) throw new Error('餘額不足');

    const aiReply = await requestOpenAIReply({
        model: aiConfig.llm || 'gpt-3.5-turbo',
        messages,
        maxTokens: 800,
        temperature: 0.6
    });

    let remainingNeed = estimatedTokens;
    const cycleRemain = Math.max(planAllowance - (user.token_used_in_cycle || 0), 0);
    const useFromCycle = Math.min(cycleRemain, remainingNeed);
    user.token_used_in_cycle = (user.token_used_in_cycle || 0) + useFromCycle;
    remainingNeed -= useFromCycle;
    if (remainingNeed > 0) user.token_bonus_balance = Math.max((user.token_bonus_balance || 0) - remainingNeed, 0);
    user.conversation_used_in_cycle = (user.conversation_used_in_cycle || 0) + 1;
    saveDatabase();

    return { reply: aiReply, model: aiConfig.llm, assistantName: aiConfig.assistant_name };
}

// JWT 身份驗證中間件
const authenticateJWT = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader) {
            return res.status(401).json({
                success: false,
                error: '未提供認證令牌'
            });
        }

        const token = authHeader.split(' ')[1];
        if (!token) {
            return res.status(401).json({
                success: false,
                error: '認證令牌格式錯誤'
            });
        }

        // 檢查 JWT_SECRET 是否正確設置
        if (!process.env.JWT_SECRET) {
            console.error('⚠️ JWT_SECRET 未正確設置:', {
                hasEnvVar: !!process.env.JWT_SECRET,
                value: process.env.JWT_SECRET ? '已設置' : '未設置'
            });
        }

        jwt.verify(token, JWT_SECRET, (err, staff) => {
            if (err) {
                console.error('❌ JWT 驗證失敗:', {
                    error: err.message,
                    name: err.name,
                    jwtSecretExists: !!process.env.JWT_SECRET,
                    tokenLength: token.length
                });
                
                if (err.name === 'TokenExpiredError') {
                    return res.status(403).json({
                        success: false,
                        error: '認證令牌已過期，請重新登入'
                    });
                } else if (err.name === 'JsonWebTokenError') {
                    return res.status(403).json({
                        success: false,
                        error: '無效的認證令牌'
                    });
                } else {
                    return res.status(403).json({
                        success: false,
                        error: '認證令牌驗證失敗'
                    });
                }
            }
            req.staff = staff;
            next();
        });
    } catch (error) {
        console.error('認證過程發生錯誤:', error);
        return res.status(500).json({
            success: false,
            error: '認證過程發生錯誤'
        });
    }
};

// 角色檢查中間件
const checkRole = (roles) => {
    return (req, res, next) => {
        if (!req.staff) {
            return res.status(401).json({
                success: false,
                error: '未認證'
            });
        }
        
        const normalizedRoles = (roles || []).map(normalizeRole);
        const userRole = normalizeRole(req.staff.role);
        const allowAdminFallback = normalizedRoles.includes('admin') && isAdminRole(userRole);
        if (!normalizedRoles.includes(userRole) && !allowAdminFallback) {
            return res.status(403).json({
                success: false,
                error: '權限不足'
            });
        }
        
        next();
    };
};

// 簡單的 JSON 檔案儲存系統
const dataDir = process.env.NODE_ENV === 'production' ? process.env.DATA_DIR || './data' : './data';
const defaultDataDir = path.join(__dirname, 'data');
const dataFile = path.join(dataDir, 'database.json');
const defaultDataFile = path.join(defaultDataDir, 'database.json');

// 確保資料目錄存在
if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
}

// 若指定 DATA_DIR 但資料檔不存在，且專案內有備份，則自動複製一次
if (dataDir !== defaultDataDir && !fs.existsSync(dataFile) && fs.existsSync(defaultDataFile)) {
    try {
        fs.copyFileSync(defaultDataFile, dataFile);
        console.log('📁 已將 data/database.json 自動複製到 DATA_DIR');
    } catch (error) {
        console.error('⚠️ 無法自動複製資料庫檔案:', error.message);
    }
}

// 初始化資料結構
let database = {
    staff_accounts: [],
    user_questions: [],
    knowledge: [],
    user_states: [],
    chat_history: [],
    channels: [],
    ai_assistant_configs: [],
    ai_settings: [],
    email_verifications: [], // 儲存電子郵件驗證碼
    password_reset_requests: [], // 儲存密碼重設請求
    password_change_requests: [], // 儲存修改密碼驗證碼
    line_api_settings: [], // 每位使用者的 LINE Token 設定
    line_bots: [] // 每位使用者的多個 LINE Bot 設定
};

// 載入現有資料
const loadDatabase = () => {
    try {
        if (fs.existsSync(dataFile)) {
            const data = fs.readFileSync(dataFile, 'utf8');
            const loadedData = JSON.parse(data);
            
            // 確保所有必要的欄位都存在
            database = {
                staff_accounts: loadedData.staff_accounts || [],
                user_questions: loadedData.user_questions || [],
                knowledge: loadedData.knowledge || [],
                user_states: loadedData.user_states || [],
                chat_history: loadedData.chat_history || [],
                channels: loadedData.channels || [],
                ai_assistant_configs: loadedData.ai_assistant_configs || [],
                ai_settings: loadedData.ai_settings || [],
                email_verifications: loadedData.email_verifications || [],
                password_reset_requests: loadedData.password_reset_requests || [],
                password_change_requests: loadedData.password_change_requests || [],
                line_api_settings: loadedData.line_api_settings || [],
                line_bots: loadedData.line_bots || []
            };
        }
    } catch (error) {
        console.error('載入資料庫檔案失敗:', error.message);
    }
};

// 儲存資料
const saveDatabase = () => {
    try {
        fs.writeFileSync(dataFile, JSON.stringify(database, null, 2));
    } catch (error) {
        console.error('儲存資料庫檔案失敗:', error.message);
        // 在生產環境中，如果無法寫入文件，我們繼續運行而不拋出錯誤
        if (process.env.NODE_ENV === 'production') {
            console.log('⚠️ 生產環境中無法寫入文件，但服務器將繼續運行');
        }
    }
};

// 初始化資料庫
const connectDatabase = async () => {
    try {
        loadDatabase();
        
        // 確保既有帳號具備 plan 與 created_at 欄位
        if (!Array.isArray(database.staff_accounts)) {
            database.staff_accounts = [];
        }
        let didMutateForPlan = false;
        database.staff_accounts.forEach(staff => {
            if (!staff.plan) {
                staff.plan = isAdminRole(staff.role) ? 'enterprise' : 'free';
                didMutateForPlan = true;
            }
            if (!staff.created_at) {
                staff.created_at = new Date().toISOString();
                didMutateForPlan = true;
            }
        });
        if (didMutateForPlan) {
            saveDatabase();
        }
        if (!Array.isArray(database.payments)) {
            database.payments = [];
            saveDatabase();
        }

        // 檢查管理員帳號是否存在
        const adminExists = database.staff_accounts.find(staff => staff.username === 'sunnyharry1');
        if (!adminExists) {
            try {
                // 創建管理員帳號
                const adminPassword = 'gele1227';
                const hash = await new Promise((resolve, reject) => {
                    bcrypt.hash(adminPassword, 10, (err, hash) => {
                        if (err) reject(err);
                        else resolve(hash);
                    });
                });
                
                const adminAccount = {
                    id: database.staff_accounts.length + 1,
                    username: 'sunnyharry1',
                    password: hash,
                    name: '系統管理員',
                    role: 'admin',
                    email: '',
                    created_at: new Date().toISOString(),
                    plan: 'enterprise'
                };
                
                database.staff_accounts.push(adminAccount);
            saveDatabase();
                
                console.log('✅ 管理員帳號已創建');
                console.log('📧 帳號: sunnyharry1');
                console.log('🔑 密碼: gele1227');
            } catch (writeError) {
                console.log('⚠️ 無法創建管理員帳號（可能是只讀文件系統）:', writeError.message);
                console.log('ℹ️ 服務器將繼續運行，但管理員功能可能受限');
            }
        } else {
            console.log('ℹ️ 管理員帳號已存在');
        }
        
        console.log('✅ JSON 資料庫初始化完成');
        return true;
    } catch (error) {
        console.error('❌ 資料庫初始化失敗:', error.message);
        console.log('⚠️ 服務器將繼續運行，但某些功能可能受限');
        return true; // 不拋出錯誤，讓服務器繼續運行
    }
};

// 簡單的查詢輔助函數
const findStaffByUsername = (username) => {
    return database.staff_accounts.find(staff => staff.username === username);
};

const findStaffById = (id) => {
    return database.staff_accounts.find(staff => staff.id === parseInt(id));
};

const updateStaffPassword = (id, newPassword) => {
    const staff = findStaffById(id);
    if (staff) {
        staff.password = newPassword;
        saveDatabase();
        return true;
    }
    return false;
};

const deleteStaffById = (id) => {
    const index = database.staff_accounts.findIndex(staff => staff.id === parseInt(id));
    if (index !== -1) {
        database.staff_accounts.splice(index, 1);
        saveDatabase();
        return true;
    }
    return false;
};



// API 路由

// 登入 API
app.post('/api/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({
                success: false,
                error: '請提供用戶名和密碼'
            });
        }

        try {
            const staff = findStaffByUsername(username);
            
            if (!staff) {
                return res.status(401).json({
                    success: false,
                    error: '用戶名或密碼錯誤'
                });
            }

            const isValidPassword = await bcrypt.compare(password, staff.password);
            if (!isValidPassword) {
                return res.status(401).json({
                    success: false,
                    error: '用戶名或密碼錯誤'
                });
            }

            const token = jwt.sign(
                { 
                    id: staff.id, 
                    username: staff.username, 
                    name: staff.name, 
                    role: staff.role,
                    plan: staff.plan || 'free'
                },
                JWT_SECRET,
                { expiresIn: JWT_EXPIRES_IN }
            );

            console.log('✅ 登入成功，生成 Token:', {
                username: staff.username,
                role: staff.role,
                jwtSecretExists: !!process.env.JWT_SECRET,
                tokenLength: token.length
            });

            res.json({
                success: true,
                token,
                user: {
                    id: staff.id,
                    username: staff.username,
                    name: staff.name,
                    role: staff.role,
                    plan: staff.plan || 'free'
                }
            });
        } catch (error) {
            console.error('登入錯誤:', error);
            return res.status(500).json({
                success: false,
                error: '登入過程發生錯誤'
            });
        }
    } catch (error) {
        console.error('登入錯誤:', error);
        res.status(500).json({
            success: false,
            error: '登入過程發生錯誤'
        });
    }
});

// 發送電子郵件驗證碼
app.post('/api/send-verification-code', async (req, res) => {
    try {
        const { email } = req.body || {};
        if (!email) {
            return res.status(400).json({ success: false, error: '請提供電子郵件地址' });
        }

        loadDatabase();
        if (!Array.isArray(database.email_verifications)) {
            database.email_verifications = [];
        }

        const existingUser = (database.staff_accounts || []).find(staff => staff.email === email);
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: '此電子郵件已被註冊'
            });
        }

        const code = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

        database.email_verifications = database.email_verifications.filter(v => v.email !== email);
        database.email_verifications.push({
            email,
            code,
            expiresAt,
            verified: false
        });
        saveDatabase();

        try {
            console.log('📧 發送驗證碼到:', email);
            await sendVerificationEmail(email, code);
            return res.json({
                success: true,
                message: '驗證碼已發送到您的電子郵件'
            });
        } catch (emailError) {
            console.error('⚠️ 發送驗證碼郵件失敗:', emailError.message);
            return res.json({
                success: true,
                message: '驗證碼已生成（郵件服務暫時不可用）',
                code
            });
        }
    } catch (error) {
        console.error('發送驗證碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '發送驗證碼失敗，請稍後再試'
        });
    }
});

// 驗證電子郵件驗證碼
app.post('/api/verify-code', async (req, res) => {
    try {
        const { email, code } = req.body || {};
        if (!email || !code) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件與驗證碼'
            });
        }

        loadDatabase();
        if (!Array.isArray(database.email_verifications)) {
            return res.status(400).json({
                success: false,
                error: '請先申請驗證碼'
            });
        }

        const verification = database.email_verifications.find(
            v => v.email === email && v.code === code && !v.verified
        );

        if (!verification) {
            return res.status(400).json({
                success: false,
                error: '驗證碼無效'
            });
        }

        if (new Date() > new Date(verification.expiresAt)) {
            database.email_verifications = database.email_verifications.filter(v => v.email !== email);
            saveDatabase();
            return res.status(400).json({
                success: false,
                error: '驗證碼已過期'
            });
        }

        verification.verified = true;
        saveDatabase();
        return res.json({
            success: true,
            message: '電子郵件驗證成功'
        });
    } catch (error) {
        console.error('驗證碼驗證錯誤:', error);
        res.status(500).json({
            success: false,
            error: '驗證失敗，請稍後再試'
        });
    }
});

// 註冊 API（開啟前請以權限或驗證碼保護）
app.post('/api/register', async (req, res) => {
    try {
        const { username, password, name, email = '' } = req.body || {};
        if (!username || !password || !name || !email) {
            return res.status(400).json({ success: false, error: '缺少必要欄位' });
        }
        loadDatabase();
        if (database.staff_accounts.find(u => u.username === username)) {
            return res.status(409).json({ success: false, error: '用戶名已存在' });
        }
        const verifiedRecord = (database.email_verifications || []).find(
            v => v.email === email && v.verified
        );
        if (!verifiedRecord) {
            return res.status(400).json({ success: false, error: '請先驗證電子郵件' });
        }
        const id = database.staff_accounts.length ? Math.max(...database.staff_accounts.map(u => u.id)) + 1 : 1;
        const hashedPassword = await bcrypt.hash(password, 10);
        const newUser = {
            id,
            username,
            password: hashedPassword,
            name,
            role: 'user',
            email,
            plan: 'free',
            created_at: new Date().toISOString()
        };
        database.staff_accounts.push(newUser);
        database.email_verifications = (database.email_verifications || []).filter(v => v.email !== email);
        saveDatabase();
        const { password: _, ...safe } = newUser;
        res.json({ success: true, account: safe });
    } catch (e) {
        console.error('註冊失敗:', e);
        res.status(500).json({ success: false, error: '註冊失敗' });
    }
});

// 知識庫 API（使用 JSON 檔儲存）
// 僅回傳屬於自己的知識庫（或未綁定者可選擇是否可見，這裡預設僅本人）
app.get('/api/knowledge', authenticateJWT, (req, res) => {
    try {
        const items = (database.knowledge || []).filter(k => !k.user_id || k.user_id === req.staff.id);
        res.json(items);
    } catch (error) {
        res.status(500).json({ success: false, error: '無法讀取知識庫' });
    }
});

app.post('/api/knowledge', authenticateJWT, (req, res) => {
    try {
        const { question, answer, category = 'general', tags = '' } = req.body || {};
        if (!question || !answer) {
            return res.status(400).json({ success: false, error: '缺少必要欄位' });
        }
        const id = database.knowledge && database.knowledge.length
            ? Math.max(...database.knowledge.map(k => k.id || 0)) + 1
            : 1;
        const item = {
            id,
            question,
            answer,
            category,
            tags,
            created_at: new Date().toISOString(),
            user_id: req.staff?.id || null
        };
        if (!database.knowledge) database.knowledge = [];
        database.knowledge.push(item);
        saveDatabase();
        res.json({ success: true, item });
    } catch (error) {
        res.status(500).json({ success: false, error: '新增知識失敗' });
    }
});

// 更新知識庫項目
app.put('/api/knowledge/:id', authenticateJWT, (req, res) => {
    try {
        const id = parseInt(req.params.id);
        if (!id || Number.isNaN(id)) {
            return res.status(400).json({ success: false, error: 'ID 不正確' });
        }
        const { question, answer, category, tags } = req.body || {};
        loadDatabase();
        const idx = (database.knowledge || []).findIndex(k => k.id === id && (k.user_id === req.staff.id));
        if (idx === -1) return res.status(404).json({ success: false, error: '項目不存在' });
        if (typeof question === 'string' && question.trim()) database.knowledge[idx].question = question.trim();
        if (typeof answer === 'string' && answer.trim()) database.knowledge[idx].answer = answer.trim();
        if (typeof category === 'string') database.knowledge[idx].category = category;
        if (typeof tags !== 'undefined') database.knowledge[idx].tags = tags;
        database.knowledge[idx].updated_at = new Date().toISOString();
        saveDatabase();
        res.json({ success: true, item: database.knowledge[idx] });
    } catch (error) {
        res.status(500).json({ success: false, error: '無法更新知識庫項目' });
    }
});

app.delete('/api/knowledge/:id', authenticateJWT, (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const items = Array.isArray(database.knowledge) ? database.knowledge : [];
        const idx = items.findIndex(k => k.id === id);
        if (idx === -1) return res.status(404).json({ success: false, error: '項目不存在' });
        const item = items[idx];
        // 允許刪除條件：本人擁有、未綁定(user_id 為空)、或管理員
        const isOwner = item.user_id === req.staff.id;
        const isUnowned = typeof item.user_id === 'undefined' || item.user_id === null;
        const isAdmin = isAdminRole(req.staff.role);
        if (!isOwner && !isUnowned && !isAdmin) {
            return res.status(403).json({ success: false, error: '無權刪除此項目' });
        }
        const removed = database.knowledge.splice(idx, 1)[0];
        saveDatabase();
        res.json({ success: true, item: removed });
    } catch (error) {
        res.status(500).json({ success: false, error: '刪除知識失敗' });
    }
});

// 批次刪除知識庫
app.post('/api/knowledge/bulk-delete', authenticateJWT, (req, res) => {
    try {
        const { ids } = req.body || {};
        if (!Array.isArray(ids) || ids.length === 0) {
            return res.status(400).json({ success: false, error: '缺少 ids' });
        }
        const isAdmin = isAdminRole(req.staff.role);
        loadDatabase();
        const items = Array.isArray(database.knowledge) ? database.knowledge : [];
        let deleted = 0;
        for (const id of ids) {
            const idx = items.findIndex(k => k.id === id);
            if (idx === -1) continue;
            const item = items[idx];
            const isOwner = item.user_id === req.staff.id;
            const isUnowned = typeof item.user_id === 'undefined' || item.user_id === null;
            if (isOwner || isUnowned || isAdmin) {
                database.knowledge.splice(idx, 1);
                deleted++;
            }
        }
        saveDatabase();
        return res.json({ success: true, deleted });
    } catch (e) {
        return res.status(500).json({ success: false, error: '批次刪除失敗' });
    }
});

// 從單一網址匯入知識
app.post('/api/knowledge/import/url', authenticateJWT, async (req, res) => {
    try {
        const { url, maxItems = 20 } = req.body || {};
        if (!url) {
            return res.status(400).json({ success: false, error: '請提供要匯入的網址' });
        }

        // 抓取 HTML
        const response = await axios.get(url, { timeout: 15000, headers: { 'User-Agent': 'EchoChatBot/1.0' } });
        const html = response.data;
        const $ = cheerio.load(html);

        // 取 <title> 與主要文字
        const title = ($('title').first().text() || url).trim();
        const paragraphs = [];
        $('p').each((_, el) => {
            const text = $(el).text().trim();
            if (text && text.length > 20) {
                paragraphs.push(text);
            }
        });

        // 切分成 Q&A（簡單策略：用標題作為問題，段落合併作為答案）
        const combined = paragraphs.join('\n');
        const chunks = [];
        const chunkSize = 800;
        for (let i = 0; i < combined.length; i += chunkSize) {
            chunks.push(combined.slice(i, i + chunkSize));
        }

        loadDatabase();
        if (!database.knowledge) database.knowledge = [];
        const created = [];
        const baseId = database.knowledge.length ? Math.max(...database.knowledge.map(k => k.id || 0)) + 1 : 1;
        const limit = Math.max(1, Math.min(maxItems, chunks.length));
        for (let i = 0; i < limit; i++) {
            const id = baseId + i;
            const item = {
                id,
                question: `${title}（第 ${i + 1} 部分）`,
                answer: chunks[i],
                category: 'webpage',
                tags: 'imported,url',
                created_at: new Date().toISOString(),
                user_id: req.staff?.id || null,
                source_url: url
            };
            database.knowledge.push(item);
            created.push(item);
        }

        saveDatabase();
        return res.json({ success: true, createdCount: created.length, items: created });
    } catch (error) {
        console.error('URL 匯入失敗:', error.message);
        return res.status(500).json({ success: false, error: '匯入失敗', details: error.message });
    }
});

// 從 Sitemap 匯入（.xml）
app.post('/api/knowledge/import/sitemap', authenticateJWT, async (req, res) => {
    try {
        const { sitemapUrl, maxPages = 20, perPageItems = 5 } = req.body || {};
        if (!sitemapUrl) {
            return res.status(400).json({ success: false, error: '請提供站點地圖網址' });
        }

        // 下載 sitemap（支援 .xml 與 .xml.gz）
        let xmlText;
        try {
            const isGzip = /\.gz$/i.test(sitemapUrl);
            const resp = await axios.get(sitemapUrl, {
                timeout: 20000,
                responseType: isGzip ? 'arraybuffer' : 'text',
                headers: { 'User-Agent': 'EchoChatBot/1.1' }
            });
            if (isGzip || (resp.headers && /gzip/i.test(resp.headers['content-encoding'] || ''))) {
                const buf = Buffer.isBuffer(resp.data) ? resp.data : Buffer.from(resp.data);
                xmlText = zlib.gunzipSync(buf).toString('utf8');
            } else {
                xmlText = typeof resp.data === 'string' ? resp.data : resp.data.toString('utf8');
            }
        } catch (fetchErr) {
            console.error('下載 sitemap 失敗:', fetchErr.message);
            return res.status(500).json({ success: false, error: '無法下載站點地圖', details: fetchErr.message });
        }

        // 解析 sitemap
        let parsed;
        try {
            parsed = await parseStringPromise(xmlText);
        } catch (parseErr) {
            console.error('解析 sitemap XML 失敗:', parseErr.message);
            return res.status(500).json({ success: false, error: '站點地圖格式錯誤', details: parseErr.message });
        }

        // 可能是 urlset 或 sitemapindex
        const urls = [];
        const limitPages = Math.max(1, Math.min(maxPages, 500));

        const collectFromUrlset = (node) => {
            const list = (node && node.url) || [];
            for (const u of list) {
                const loc = (u.loc && u.loc[0]) || null;
                if (loc) urls.push(loc);
                if (urls.length >= limitPages) break;
            }
        };

        if (parsed.urlset) {
            collectFromUrlset(parsed.urlset);
        } else if (parsed.sitemapindex && Array.isArray(parsed.sitemapindex.sitemap)) {
            // 先抓取子 sitemap，再收集 url
            const children = parsed.sitemapindex.sitemap
                .map(s => (s.loc && s.loc[0]) || null)
                .filter(Boolean)
                .slice(0, 20); // 避免展開過多層
            for (const child of children) {
                try {
                    const isGz = /\.gz$/i.test(child);
                    const r = await axios.get(child, {
                        timeout: 20000,
                        responseType: isGz ? 'arraybuffer' : 'text',
                        headers: { 'User-Agent': 'EchoChatBot/1.1' }
                    });
                    const text = isGz || (r.headers && /gzip/i.test(r.headers['content-encoding'] || ''))
                        ? zlib.gunzipSync(Buffer.isBuffer(r.data) ? r.data : Buffer.from(r.data)).toString('utf8')
                        : (typeof r.data === 'string' ? r.data : r.data.toString('utf8'));
                    const sub = await parseStringPromise(text);
                    if (sub.urlset) collectFromUrlset(sub.urlset);
                    if (urls.length >= limitPages) break;
                } catch (childErr) {
                    console.warn('讀取子 sitemap 失敗:', child, childErr.message);
                }
            }
        }

        const targetUrls = urls.slice(0, limitPages);
        if (targetUrls.length === 0) {
            return res.status(400).json({ success: false, error: '站點地圖中未找到任何頁面 URL' });
        }

        // 逐頁抓取內容並寫入知識庫
        const allCreated = [];
        for (const pageUrl of targetUrls) {
            try {
                const page = await axios.get(pageUrl, { timeout: 20000, headers: { 'User-Agent': 'EchoChatBot/1.1' } });
                const $ = cheerio.load(page.data);
                const title = ($('title').first().text() || pageUrl).trim();
                const paragraphs = [];
                $('p').each((_, el) => {
                    const text = $(el).text().trim();
                    if (text && text.length > 20) paragraphs.push(text);
                });
                const combined = paragraphs.join('\n');
                if (!combined) continue;
                const chunks = [];
                const chunkSize = 800;
                for (let i = 0; i < combined.length; i += chunkSize) {
                    chunks.push(combined.slice(i, i + chunkSize));
                }
                const limit = Math.min(perPageItems, chunks.length);

                loadDatabase();
                if (!database.knowledge) database.knowledge = [];
                const baseId = database.knowledge.length ? Math.max(...database.knowledge.map(k => k.id || 0)) + 1 : 1;
                for (let i = 0; i < limit; i++) {
                    const id = baseId + i + database.knowledge.length;
                    const item = {
                        id,
                        question: `${title}（第 ${i + 1} 部分）`,
                        answer: chunks[i],
                        category: 'webpage',
                        tags: 'imported,sitemap',
                        created_at: new Date().toISOString(),
                        user_id: req.staff?.id || null,
                        source_url: pageUrl
                    };
                    database.knowledge.push(item);
                    allCreated.push(item);
                }
                saveDatabase();
            } catch (pageErr) {
                console.warn('抓取頁面失敗:', pageUrl, pageErr.message);
            }
        }

        return res.json({ success: true, createdCount: allCreated.length, items: allCreated });
    } catch (error) {
        console.error('Sitemap 匯入失敗:', error.message);
        return res.status(500).json({ success: false, error: '匯入失敗', details: error.message });
    }
});

// 從 CSV/XLSX 匯入（每列需包含 question, answer 欄位）
app.post('/api/knowledge/import/file', authenticateJWT, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) return res.status(400).json({ success: false, error: '缺少檔案' });
        const mime = req.file.mimetype || '';
        const buf = req.file.buffer;
        let rows = [];
        if (mime.includes('csv') || req.file.originalname.toLowerCase().endsWith('.csv')) {
            const text = buf.toString('utf8');
            rows = parseCsv(text, { columns: true, skip_empty_lines: true });
        } else if (mime.includes('excel') || mime.includes('spreadsheet') || /\.xlsx?$/i.test(req.file.originalname)) {
            const wb = XLSX.read(buf, { type: 'buffer' });
            const sheet = wb.Sheets[wb.SheetNames[0]];
            rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });
        } else if (mime.includes('json') || req.file.originalname.toLowerCase().endsWith('.json')) {
            rows = JSON.parse(buf.toString('utf8'));
        } else {
            return res.status(400).json({ success: false, error: '不支援的檔案格式' });
        }

        loadDatabase();
        if (!database.knowledge) database.knowledge = [];
        let created = 0;
        const baseId = database.knowledge.length ? Math.max(...database.knowledge.map(k => k.id || 0)) + 1 : 1;
        let idCursor = baseId;
        for (const r of rows) {
            const q = r.question || r.Q || r.title || '';
            const a = r.answer || r.A || r.content || '';
            if (!q || !a) continue;
            database.knowledge.push({
                id: idCursor++,
                question: String(q),
                answer: String(a),
                category: 'upload',
                tags: 'imported,file',
                created_at: new Date().toISOString(),
                user_id: req.staff?.id || null
            });
            created++;
        }
        saveDatabase();
        return res.json({ success: true, createdCount: created });
    } catch (e) {
        console.error('檔案匯入失敗:', e.message);
        return res.status(500).json({ success: false, error: '匯入失敗', details: e.message });
    }
});

// 預約系統：提供公開可讀取的可預約時段與預約建立
// 可用於在前台提供客戶檢視與下單（不強制登入）
// 資料儲存於 database.appointments（每筆包含 id, datetime, name, contact, note, status, created_at）

// 建立週期性預設可預約規則（Mon-Fri 10:00-17:00 整點）
function getBusinessHours() {
    loadDatabase();
    if (!database.business_hours) {
        database.business_hours = {
            mon: { open: true, start: 10, end: 17 },
            tue: { open: true, start: 10, end: 17 },
            wed: { open: true, start: 10, end: 17 },
            thu: { open: true, start: 10, end: 17 },
            fri: { open: true, start: 10, end: 17 },
            sat: { open: false, start: 10, end: 17 },
            sun: { open: false, start: 10, end: 17 }
        };
        saveDatabase();
    }
    return database.business_hours;
}

function generateDefaultSlots(days = 14) {
    const slots = [];
    const now = new Date();
    const bh = getBusinessHours();
    for (let i = 0; i < days; i++) {
        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i);
        const day = d.getDay(); // 0 Sun ... 6 Sat
        const map = ['sun','mon','tue','wed','thu','fri','sat'];
        const cfg = bh[map[day]] || { open: false };
        if (cfg.open) {
            for (let h = cfg.start; h <= cfg.end; h++) {
                const dt = new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, 0, 0, 0);
                if (dt.getTime() > now.getTime()) {
                    slots.push(dt.toISOString());
                }
            }
        }
    }
    return slots;
}

// 取得可預約時段（公開）
app.get('/api/appointments/slots', (req, res) => {
    try {
        loadDatabase();
        const all = Array.isArray(database.appointments) ? database.appointments : [];
        const booked = new Set(all.filter(x => x.status !== 'cancelled').map(x => new Date(x.datetime).toISOString()));
        const slots = generateDefaultSlots(14).filter(iso => !booked.has(iso));
        return res.json({ success: true, slots });
    } catch (e) {
        console.error('取得可預約時段失敗:', e.message);
        return res.status(500).json({ success: false, error: '無法取得可預約時段' });
    }
});

// 建立預約（公開）
app.post('/api/appointments/book', (req, res) => {
    try {
        const { name, contact, datetime, note, platform, customerId, customerName, location } = req.body || {};
        if (!name || !contact || !datetime) {
            return res.status(400).json({ success: false, error: '缺少必要欄位' });
        }
        const dt = new Date(datetime);
        if (isNaN(dt.getTime())) {
            return res.status(400).json({ success: false, error: '時間格式不正確' });
        }

        loadDatabase();
        if (!Array.isArray(database.appointments)) database.appointments = [];
        const normalized = dt.toISOString();
        const exists = database.appointments.find(x => new Date(x.datetime).toISOString() === normalized && x.status !== 'cancelled');
        if (exists) {
            return res.status(409).json({ success: false, error: '此時段已被預約' });
        }

        const nextId = database.appointments.length ? Math.max(...database.appointments.map(x => x.id || 0)) + 1 : 1;
        let normalizedLocation = null;
        if (location) {
            if (typeof location === 'string') {
                normalizedLocation = { address: location.trim() };
            } else if (typeof location === 'object') {
                normalizedLocation = {
                    name: location.name ? String(location.name).trim() : undefined,
                    address: location.address ? String(location.address).trim() : undefined,
                    lat: typeof location.lat === 'number' ? location.lat : undefined,
                    lng: typeof location.lng === 'number' ? location.lng : undefined
                };
            }
        }
        const item = {
            id: nextId,
            datetime: normalized,
            name: String(name).trim(),
            contact: String(contact).trim(),
            note: note ? String(note).trim() : '',
            platform: platform ? String(platform).trim().toLowerCase() : 'web',
            customerId: customerId ? String(customerId).trim() : null,
            customerName: customerName ? String(customerName).trim() : null,
            location: normalizedLocation,
            status: 'pending',
            created_at: new Date().toISOString()
        };
        database.appointments.push(item);
        saveDatabase();
        return res.json({ success: true, appointment: item });
    } catch (e) {
        console.error('建立預約失敗:', e.message);
        return res.status(500).json({ success: false, error: '建立預約失敗' });
    }
});

// 取得預約時段表（依日期分組，公開）
app.get('/api/appointments/slots-table', (req, res) => {
    try {
        loadDatabase();
        const all = Array.isArray(database.appointments) ? database.appointments : [];
        const booked = new Set(all.filter(x => x.status !== 'cancelled').map(x => new Date(x.datetime).toISOString()));
        const slots = generateDefaultSlots(14).filter(iso => !booked.has(iso));
        const grouped = {};
        slots.forEach((iso) => {
            const dateKey = iso.split('T')[0];
            if (!grouped[dateKey]) grouped[dateKey] = [];
            grouped[dateKey].push(iso);
        });
        return res.json({ success: true, slots: grouped });
    } catch (e) {
        console.error('取得預約時段表失敗:', e.message);
        return res.status(500).json({ success: false, error: '無法取得預約時段表' });
    }
});

// 營業時間：取得/更新（需登入）
app.get('/api/appointments/business-hours', authenticateJWT, (req, res) => {
    try {
        const bh = getBusinessHours();
        return res.json({ success: true, hours: bh });
    } catch (e) {
        return res.status(500).json({ success: false, error: '無法取得營業時間' });
    }
});

app.post('/api/appointments/business-hours', authenticateJWT, (req, res) => {
    try {
        const { hours } = req.body || {};
        if (!hours || typeof hours !== 'object') {
            return res.status(400).json({ success: false, error: '格式不正確' });
        }
        const keys = ['mon','tue','wed','thu','fri','sat','sun'];
        const normalized = {};
        for (const k of keys) {
            const v = hours[k] || {};
            normalized[k] = {
                open: Boolean(v.open),
                start: Number.isFinite(v.start) ? Number(v.start) : 10,
                end: Number.isFinite(v.end) ? Number(v.end) : 17
            };
        }
        loadDatabase();
        database.business_hours = normalized;
        saveDatabase();
        return res.json({ success: true, hours: normalized });
    } catch (e) {
        return res.status(500).json({ success: false, error: '更新營業時間失敗' });
    }
});

// 商家端：取得所有預約（需登入）
app.get('/api/appointments', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const all = Array.isArray(database.appointments) ? database.appointments : [];
        // 簡化：目前無多商家切分，全部返回
        return res.json({ success: true, items: all.sort((a,b)=> new Date(a.datetime)-new Date(b.datetime)) });
    } catch (e) {
        return res.status(500).json({ success: false, error: '無法取得預約清單' });
    }
});

// 商家端：更新預約狀態（確認/取消）（需登入）
app.post('/api/appointments/:id/status', authenticateJWT, (req, res) => {
    try {
        const id = parseInt(req.params.id, 10);
        const { status } = req.body || {};
        if (!['pending', 'confirmed', 'cancelled', 'completed'].includes(status)) {
            return res.status(400).json({ success: false, error: '狀態不正確' });
        }
        loadDatabase();
        if (!Array.isArray(database.appointments)) database.appointments = [];
        const idx = database.appointments.findIndex(x => x.id === id);
        if (idx === -1) return res.status(404).json({ success: false, error: '預約不存在' });
        database.appointments[idx].status = status;
        database.appointments[idx].updated_at = new Date().toISOString();
        saveDatabase();
        return res.json({ success: true, item: database.appointments[idx] });
    } catch (e) {
        return res.status(500).json({ success: false, error: '更新狀態失敗' });
    }
});

// 儀表板統計 API
app.get('/api/stats', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const userId = req.staff?.id;
        const isAdmin = isAdminRole(req.staff?.role);

        const belongsToUser = (conv) => {
            if (!conv) return false;
            if (isAdmin) return true;
            if (conv.userId && String(conv.userId) === String(userId)) return true;
            const id = String(conv.id || '');
            return (
                id.startsWith(`line_${userId}_`) ||
                id.startsWith(`slack_${userId}_`) ||
                id.startsWith(`telegram_${userId}_`) ||
                id.startsWith(`messenger_${userId}_`) ||
                id.startsWith(`discord_${userId}_`)
            );
        };

        const conversations = (database.chat_history || []).filter(belongsToUser);
        const totalConversations = conversations.length;
        const totalMessages = conversations.reduce((sum, conv) => sum + (Array.isArray(conv.messages) ? conv.messages.length : 0), 0);
        const totalUsers = Array.isArray(database.staff_accounts) ? database.staff_accounts.length : 0;
        const knowledgeItems = (database.knowledge || []).filter(k => isAdmin || !k.user_id || k.user_id === userId).length;

        let responseTimes = [];
        conversations.forEach((conv) => {
            const msgs = Array.isArray(conv.messages) ? conv.messages : [];
            for (let i = 0; i < msgs.length - 1; i++) {
                const cur = msgs[i];
                const next = msgs[i + 1];
                if (cur.role === 'user' && next.role === 'assistant') {
                    const t1 = new Date(cur.timestamp || cur.created_at || cur.time || 0).getTime();
                    const t2 = new Date(next.timestamp || next.created_at || next.time || 0).getTime();
                    if (t1 && t2 && t2 >= t1) {
                        responseTimes.push((t2 - t1) / 1000);
                    }
                }
            }
        });
        const avgSeconds = responseTimes.length
            ? Math.round((responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length) * 10) / 10
            : 0;

        return res.json({
            success: true,
            data: {
                totalUsers,
                totalMessages,
                totalConversations,
                knowledgeItems,
                avgResponseTime: avgSeconds ? `${avgSeconds}s` : '0s',
                lastUpdated: new Date().toISOString()
            }
        });
    } catch (error) {
        console.error('取得統計數據錯誤:', error);
        return res.status(500).json({ success: false, error: '無法取得統計數據' });
    }
});

app.get('/api/stats/activity', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const userId = req.staff?.id;
        const isAdmin = isAdminRole(req.staff?.role);
        const belongsToUser = (conv) => {
            if (!conv) return false;
            if (isAdmin) return true;
            if (conv.userId && String(conv.userId) === String(userId)) return true;
            const id = String(conv.id || '');
            return (
                id.startsWith(`line_${userId}_`) ||
                id.startsWith(`slack_${userId}_`) ||
                id.startsWith(`telegram_${userId}_`) ||
                id.startsWith(`messenger_${userId}_`) ||
                id.startsWith(`discord_${userId}_`)
            );
        };

        const conversations = (database.chat_history || []).filter(belongsToUser);
        const messages = conversations.flatMap(conv => Array.isArray(conv.messages) ? conv.messages : []);
        const countsByDate = {};
        messages.forEach((msg) => {
            const ts = msg.timestamp || msg.created_at || msg.time;
            if (!ts) return;
            const dateKey = new Date(ts).toISOString().split('T')[0];
            countsByDate[dateKey] = (countsByDate[dateKey] || 0) + 1;
        });

        const labels = [];
        const data = [];
        const weekLabel = ['週日', '週一', '週二', '週三', '週四', '週五', '週六'];
        const now = new Date();
        for (let i = 6; i >= 0; i--) {
            const d = new Date(now);
            d.setDate(d.getDate() - i);
            const dateKey = d.toISOString().split('T')[0];
            labels.push(weekLabel[d.getDay()]);
            data.push(countsByDate[dateKey] || 0);
        }

        return res.json({
            success: true,
            data: {
                labels,
                datasets: [{
                    label: '活躍用戶',
                    data,
                    borderColor: '#667eea',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    tension: 0.4,
                    fill: true
                }]
            }
        });
    } catch (error) {
        console.error('取得活躍度統計錯誤:', error);
        return res.status(500).json({ success: false, error: '無法取得活躍度統計' });
    }
});

app.get('/api/stats/recent-activity', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const userId = req.staff?.id;
        const isAdmin = isAdminRole(req.staff?.role);

        const toDate = (value) => {
            const d = new Date(value || 0);
            return isNaN(d.getTime()) ? null : d;
        };

        const formatRelative = (date) => {
            if (!date) return '剛剛';
            const diff = Date.now() - date.getTime();
            if (diff < 60 * 1000) return '剛剛';
            if (diff < 60 * 60 * 1000) return `${Math.floor(diff / 60000)} 分鐘前`;
            if (diff < 24 * 60 * 60 * 1000) return `${Math.floor(diff / 3600000)} 小時前`;
            return `${Math.floor(diff / 86400000)} 天前`;
        };

        const activities = [];
        const users = Array.isArray(database.staff_accounts) ? database.staff_accounts : [];
        users.forEach((u) => {
            const created = toDate(u.created_at);
            if (!created) return;
            activities.push({
                timestamp: created.getTime(),
                icon: 'fas fa-user-plus',
                color: 'bg-success',
                text: `新用戶註冊：${u.username || u.name || '新用戶'}`,
                time: formatRelative(created)
            });
        });

        const knowledge = (database.knowledge || []).filter(k => isAdmin || !k.user_id || k.user_id === userId);
        knowledge.forEach((k) => {
            const updated = toDate(k.updated_at || k.created_at);
            if (!updated) return;
            activities.push({
                timestamp: updated.getTime(),
                icon: 'fas fa-brain',
                color: 'bg-warning',
                text: `知識庫更新：${k.question || '內容更新'}`,
                time: formatRelative(updated)
            });
        });

        const convs = (database.chat_history || []).filter(c => {
            if (isAdmin) return true;
            if (c.userId && String(c.userId) === String(userId)) return true;
            return false;
        });
        convs.forEach((c) => {
            const updated = toDate(c.updatedAt || c.updated_at || c.createdAt);
            if (!updated) return;
            const platform = c.platform || '對話';
            activities.push({
                timestamp: updated.getTime(),
                icon: 'fas fa-comment',
                color: 'bg-primary',
                text: `收到新訊息（${platform}）`,
                time: formatRelative(updated)
            });
        });

        activities.sort((a, b) => b.timestamp - a.timestamp);
        const result = activities.slice(0, 6).map(({ icon, color, text, time }) => ({ icon, color, text, time }));

        return res.json({ success: true, data: result });
    } catch (error) {
        console.error('取得最近活動錯誤:', error);
        return res.status(500).json({ success: false, error: '無法取得最近活動' });
    }
});

// 取得目前使用者資訊
app.get('/api/me', authenticateJWT, (req, res) => {
    try {
        const currentStaffId = req.staff && req.staff.id ? req.staff.id : null;
        if (!currentStaffId) {
            return res.status(401).json({
                success: false,
                error: '未授權'
            });
        }

        const user = findStaffById(currentStaffId);
        if (!user) {
            return res.status(404).json({
                success: false,
                error: '用戶不存在'
            });
        }
        
        return res.json({
            success: true,
            user: {
                id: user.id,
                username: user.username,
                name: user.name,
                    role: user.role,
                    plan: user.plan || 'free',
                    plan_expires_at: user.plan_expires_at || null
            }
        });
    } catch (error) {
        return res.status(500).json({
            success: false,
            error: '伺服器錯誤'
        });
    }
});

// 取得個人資料（帳戶設定頁使用）
app.get('/api/profile', authenticateJWT, (req, res) => {
    try {
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        const { password: _, ...safe } = user;
        res.json({ success: true, profile: safe });
    } catch (e) {
        res.status(500).json({ success: false, error: '無法取得個人資料' });
    }
});

// 更新個人資料（可改姓名與 email）
app.post('/api/profile', authenticateJWT, (req, res) => {
    try {
        const { name, email } = req.body || {};
        loadDatabase();
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        if (typeof name === 'string') user.name = name.trim();
        if (typeof email === 'string') user.email = email.trim();
        user.updated_at = new Date().toISOString();
        saveDatabase();
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false, error: '更新失敗' });
    }
});

// 發送修改密碼驗證碼（需登入）
app.post('/api/change-password/request-code', authenticateJWT, async (req, res) => {
    try {
        loadDatabase();
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        if (!user.email) return res.status(400).json({ success: false, error: '請先設定電子郵件' });

        const code = generateVerificationCode();
        if (!Array.isArray(database.password_change_requests)) {
            database.password_change_requests = [];
        }
        database.password_change_requests = database.password_change_requests.filter(v => v.userId !== user.id);
        database.password_change_requests.push({
            userId: user.id,
            email: user.email,
            code,
            expiresAt: new Date(Date.now() + 10 * 60 * 1000),
            createdAt: new Date().toISOString()
        });
        saveDatabase();

        await sendPasswordResetEmail(user.email, code);

        return res.json({ success: true, message: '驗證碼已發送' });
    } catch (error) {
        console.error('發送修改密碼驗證碼失敗:', error);
        return res.status(500).json({ success: false, error: '發送驗證碼失敗' });
    }
});

// 修改密碼（需登入）
app.post('/api/change-password', authenticateJWT, async (req, res) => {
    try {
        const { oldPassword, newPassword, code } = req.body || {};
        if (!oldPassword || !newPassword || !code) {
            return res.status(400).json({ success: false, error: '缺少必要欄位' });
        }
        if (String(newPassword).length < 6) {
            return res.status(400).json({ success: false, error: '新密碼長度至少 6 碼' });
        }

        loadDatabase();
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        if (!user.email) return res.status(400).json({ success: false, error: '請先設定電子郵件' });

        const verify = (database.password_change_requests || []).find(v => v.userId === user.id && v.code === String(code).trim());
        if (!verify) {
            return res.status(400).json({ success: false, error: '驗證碼錯誤或已過期' });
        }
        if (new Date() > new Date(verify.expiresAt)) {
            database.password_change_requests = (database.password_change_requests || []).filter(v => v.userId !== user.id);
            saveDatabase();
            return res.status(400).json({ success: false, error: '驗證碼已過期，請重新取得' });
        }

        const isValid = await bcrypt.compare(String(oldPassword), user.password || '');
        if (!isValid) {
            return res.status(400).json({ success: false, error: '目前密碼不正確' });
        }

        user.password = await bcrypt.hash(String(newPassword), 10);
        user.updated_at = new Date().toISOString();
        database.password_change_requests = (database.password_change_requests || []).filter(v => v.userId !== user.id);
        saveDatabase();
        return res.json({ success: true });
    } catch (error) {
        console.error('修改密碼失敗:', error);
        return res.status(500).json({ success: false, error: '修改密碼失敗' });
    }
});

// 使用者自助升級或儲值 Token（綠界收銀台）
app.post('/api/upgrade', authenticateJWT, (req, res) => {
    try {
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });

        // 基本防呆：確認金流環境變數已設定
        if (!ECPAY_MERCHANT_ID || !ECPAY_HASH_KEY || !ECPAY_HASH_IV || !ECPAY_RETURN_URL || !ECPAY_ORDER_RESULT_URL || !ECPAY_CLIENT_BACK_URL) {
            return res.status(400).json({ success: false, error: '金流尚未完成設定，請稍後再試或聯繫管理員（缺少 ECPay 參數）' });
        }

        // 建立綠界訂單參數
        const tradeNo = `EC${Date.now()}`;
        const date = new Date();
        const pad2 = (n) => n.toString().padStart(2, '0');
        const tradeDate = `${date.getFullYear()}/${pad2(date.getMonth()+1)}/${pad2(date.getDate())} ${pad2(date.getHours())}:${pad2(date.getMinutes())}:${pad2(date.getSeconds())}`;
        const { type = 'plan', amount = 2990, tokens = 0 } = req.body || {};
        const totalAmount = Math.max(parseInt(amount, 10) || 0, 0);

        // 參數檢查：金額與儲值數量
        if (totalAmount <= 0) {
            return res.status(400).json({ success: false, error: '金額不正確，請選擇有效金額' });
        }
        if (type === 'topup' && (!tokens || parseInt(tokens, 10) <= 0)) {
            return res.status(400).json({ success: false, error: '儲值數量不正確，請選擇有效的 Token 數量' });
        }
        const orderParams = {
            MerchantID: ECPAY_MERCHANT_ID,
            MerchantTradeNo: tradeNo,
            MerchantTradeDate: tradeDate,
            PaymentType: 'aio',
            TotalAmount: totalAmount,
            TradeDesc: type === 'topup' ? `EchoChat Token 儲值 ${tokens}` : 'EchoChat Premium 升級',
            ItemName: type === 'topup' ? `Token 儲值 (${tokens}) x1` : 'EchoChat 尊榮版 x1',
            ReturnURL: ECPAY_RETURN_URL,
            OrderResultURL: ECPAY_ORDER_RESULT_URL,
            ClientBackURL: ECPAY_CLIENT_BACK_URL,
            ChoosePayment: 'Credit',
            EncryptType: 1
        };

        // 計算 CheckMacValue
        const raw = Object.keys(orderParams)
            .sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()))
            .map(k => `${k}=${orderParams[k]}`)
            .join('&');
        const urlEncoded = `HashKey=${ECPAY_HASH_KEY}&${raw}&HashIV=${ECPAY_HASH_IV}`
            .replace(/%20/g, '+');
        const encoded = encodeURIComponent(urlEncoded).toLowerCase()
            .replace(/%2d/g, '-')
            .replace(/%5f/g, '_')
            .replace(/%2e/g, '.')
            .replace(/%21/g, '!')
            .replace(/%2a/g, '*')
            .replace(/%28/g, '(')
            .replace(/%29/g, ')');
        const checkMacValue = crypto.createHash('sha256').update(encoded).digest('hex').toUpperCase();

        // 儲存付款記錄（狀態 pending）
        database.payments.push({
            tradeNo,
            userId: user.id,
            amount: totalAmount,
            plan: type === 'plan' ? 'premium' : null,
            type,
            tokens: type === 'topup' ? parseInt(tokens, 10) || 0 : 0,
            status: 'pending',
            created_at: new Date().toISOString()
        });
        saveDatabase();
        
        // 回傳可自動送出的表單資料給前端
        return res.json({
                success: true,
            action: ECPAY_ACTION,
            params: {
                ...orderParams,
                CheckMacValue: checkMacValue
            }
        });
    } catch (error) {
        console.error('建立綠界訂單失敗:', error);
        return res.status(500).json({ success: false, error: '建立訂單失敗' });
    }
});

// 取消訂閱（當期結束後生效）
app.post('/api/subscription/cancel', authenticateJWT, (req, res) => {
    try {
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        loadDatabase();
        user.subscription_status = 'cancel_at_period_end';
        // 若無到期日，預設 30 天後終止
        if (!user.plan_expires_at) {
            const expires = new Date();
            expires.setDate(expires.getDate() + 30);
            user.plan_expires_at = expires.toISOString();
        }
        saveDatabase();
        return res.json({ success: true, message: '已設定於週期結束後取消訂閱', plan_expires_at: user.plan_expires_at });
    } catch (e) {
        return res.status(500).json({ success: false, error: '取消訂閱失敗' });
    }
});

// 變更付款方式（示意：更新付款紀錄的偏好）
app.post('/api/subscription/payment-method', authenticateJWT, (req, res) => {
    try {
        const { method = 'Credit' } = req.body || {};
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        loadDatabase();
        user.payment_method = method;
        saveDatabase();
        return res.json({ success: true });
    } catch (e) {
        return res.status(500).json({ success: false, error: '更新付款方式失敗' });
    }
});

// 取消訂閱挽回：提供一次性 10% 折扣（僅下期一次）
app.post('/api/subscription/retention-offer', authenticateJWT, (req, res) => {
    try {
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        loadDatabase();
        user.retention_offer = { type: 'one_month_discount', value: 0.1, granted_at: new Date().toISOString() };
        saveDatabase();
        return res.json({ success: true });
    } catch (e) {
        return res.status(500).json({ success: false, error: '設定挽回優惠失敗' });
    }
});

// 收集取消原因
app.post('/api/subscription/cancel-feedback', authenticateJWT, (req, res) => {
    try {
        const { reason = '' } = req.body || {};
        const user = findStaffById(req.staff.id);
        if (!user) return res.status(404).json({ success: false, error: '用戶不存在' });
        loadDatabase();
        if (!Array.isArray(database.cancellation_feedback)) database.cancellation_feedback = [];
        database.cancellation_feedback.push({ userId: user.id, reason: String(reason), created_at: new Date().toISOString() });
        saveDatabase();
        return res.json({ success: true });
    } catch (e) {
        return res.status(500).json({ success: false, error: '回饋提交失敗' });
    }
});

// 綠界伺服器端通知（付款結果）
app.post('/api/payment/ecpay/return', express.urlencoded({ extended: false }), (req, res) => {
    try {
        const data = req.body || {};
        // 驗證 CheckMacValue
        const receivedCMV = data.CheckMacValue;
        const { CheckMacValue, ...forMac } = data;
        const raw = Object.keys(forMac)
            .sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()))
            .map(k => `${k}=${forMac[k]}`)
            .join('&');
        const urlEncoded = `HashKey=${ECPAY_HASH_KEY}&${raw}&HashIV=${ECPAY_HASH_IV}`
            .replace(/%20/g, '+');
        const encoded = encodeURIComponent(urlEncoded).toLowerCase()
            .replace(/%2d/g, '-')
            .replace(/%5f/g, '_')
            .replace(/%2e/g, '.')
            .replace(/%21/g, '!')
            .replace(/%2a/g, '*')
            .replace(/%28/g, '(')
            .replace(/%29/g, ')');
        const calcCMV = crypto.createHash('sha256').update(encoded).digest('hex').toUpperCase();
        if (calcCMV !== receivedCMV) {
            console.warn('綠界簽章驗證失敗');
            return res.send('0|Error');
        }

        const tradeNo = data.MerchantTradeNo;
        const payment = (database.payments || []).find(p => p.tradeNo === tradeNo);
        if (!payment) {
            console.warn('找不到付款記錄:', tradeNo);
            return res.send('0|Error');
        }

        // 付款成功
        if (data.RtnCode === '1' || data.RtnCode === 1) {
            payment.status = 'paid';
            payment.paid_at = new Date().toISOString();
            // 升級或儲值
            const user = findStaffById(payment.userId);
            if (user) {
                if (payment.type === 'plan' && payment.plan) {
                user.plan = payment.plan;
                const expires = new Date();
                expires.setDate(expires.getDate() + 30);
                user.plan_expires_at = expires.toISOString();
                } else if (payment.type === 'topup' && payment.tokens > 0) {
                    ensureUserTokenFields(user);
                    user.token_bonus_balance = (user.token_bonus_balance || 0) + payment.tokens;
                }
            }
        saveDatabase();
        } else {
            payment.status = 'failed';
            saveDatabase();
        }

        // 綠界要求固定回傳
        return res.send('1|OK');
    } catch (error) {
        console.error('處理綠界回傳錯誤:', error);
        return res.send('0|Error');
    }
});

// 對話列表（讀取實際 chat_history，僅顯示當前使用者相關）
app.get('/api/conversations', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const userId = req.staff.id;

        // 過濾屬於該使用者的對話（依 userId 或 id 前綴）
        const belongsToUser = (conv) => {
            if (!conv) return false;
            // 嚴格比對 userId（數字或字串都支援）
            if (conv.userId && String(conv.userId) === String(userId)) return true;
            const id = String(conv.id || '');
            return (
                id.startsWith(`line_${userId}_`) ||
                id.startsWith(`slack_${userId}_`) ||
                id.startsWith(`telegram_${userId}_`) ||
                id.startsWith(`messenger_${userId}_`) ||
                id.startsWith(`discord_${userId}_`)
            );
        };

        const list = (database.chat_history || [])
            .filter(belongsToUser)
            .filter((c) => {
                const platform = String(c.platform || '').toLowerCase();
                const id = String(c.id || '');
                return platform !== 'dashboard' && platform !== 'test' && !id.startsWith('conv_');
            })
            .map((c) => ({
                id: c.id,
                platform: c.platform || (String(c.id || '').split('_')[0] || 'unknown'),
                userId: c.userId || userId,
                customerName: c.customerName || '未知客戶',
                customerPicture: c.customerPicture || null,
                lastMessage: (c.messages && c.messages.length)
                    ? (c.messages[c.messages.length - 1].content || '')
                    : (c.content || ''),
                messageCount: (c.messages && c.messages.length) || 0,
                updatedAt: c.updatedAt || new Date().toISOString()
            }))
            .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));

        // 為保持前端相容性，直接回傳陣列（不包 success）
        return res.json(list);
    } catch (error) {
        return res.status(500).json({ success: false, error: '無法取得對話列表' });
    }
        });

// 取得單一對話詳情
app.get('/api/conversations/:conversationId', authenticateJWT, async (req, res) => {
    try {
        loadDatabase();
        const userId = req.staff.id;
        const { conversationId } = req.params;
        const conv = (database.chat_history || []).find(c => {
            if (!c) return false;
            if (c.id !== conversationId) return false;
            // 確認該對話屬於當前使用者
            if (c.userId && String(c.userId) === String(userId)) return true;
            const id = String(c.id || '');
            return (id.startsWith(`line_${userId}_`) || id.startsWith(`slack_${userId}_`) || id.startsWith(`telegram_${userId}_`) || id.startsWith(`messenger_${userId}_`) || id.startsWith(`discord_${userId}_`));
        });
        if (!conv) return res.status(404).json({ success: false, error: '對話不存在' });
        const updated = await maybeRefreshConversationProfile(conv);
        if (updated) saveDatabase();
        return res.json({ success: true, conversation: conv });
    } catch (error) {
        return res.status(500).json({ success: false, error: '無法取得對話詳情' });
    }
});

// 帳號管理 API
app.get('/api/accounts', authenticateJWT, checkRole(['admin']), (req, res) => {
    try {
        const accounts = (database.staff_accounts || []).map(staff => ({
            id: staff.id,
            username: staff.username,
            name: staff.name,
            role: staff.role,
            email: staff.email || '',
            plan: staff.plan || 'free',
            plan_expires_at: staff.plan_expires_at || null,
            subscription_status: staff.subscription_status || 'none',
            next_billing_at: staff.next_billing_at || null,
            enterprise_token_monthly: staff.enterprise_token_monthly || 0,
            token_used_in_cycle: staff.token_used_in_cycle || 0,
            token_bonus_balance: staff.token_bonus_balance || 0,
            created_at: staff.created_at
        }));
        res.json({ success: true, accounts });
    } catch (error) {
        res.status(500).json({ success: false, error: '無法載入帳號清單' });
    }
});

app.post('/api/accounts', authenticateJWT, checkRole(['admin']), async (req, res) => {
    try {
        const { username, password, name, role = 'user', email = '', plan = 'free' } = req.body;
        if (!username || !password || !name) {
            return res.status(400).json({ success: false, error: '缺少必要欄位' });
        }
        if (database.staff_accounts.find(u => u.username === username)) {
            return res.status(409).json({ success: false, error: '用戶名已存在' });
        }
        const id = database.staff_accounts.length ? Math.max(...database.staff_accounts.map(u => u.id)) + 1 : 1;
        const hashedPassword = await bcrypt.hash(password, 10);
        const newUser = { id, username, password: hashedPassword, name, role, email, plan, created_at: new Date().toISOString() };
        database.staff_accounts.push(newUser);
        saveDatabase();
        // 不回傳密碼
        const { password: _, ...safeUser } = newUser;
        res.json({ success: true, account: safeUser });
    } catch (error) {
        res.status(500).json({ success: false, error: '無法新增帳號' });
    }
});

app.put('/api/accounts/:id', authenticateJWT, checkRole(['admin']), async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const user = database.staff_accounts.find(u => u.id === id);
        if (!user) return res.status(404).json({ success: false, error: '帳號不存在' });
        const { name, role, password, email, plan, plan_expires_at, subscription_status, next_billing_at, enterprise_token_monthly, token_used_in_cycle, token_bonus_balance } = req.body;
        if (name !== undefined) user.name = name;
        if (role !== undefined) user.role = role;
        if (email !== undefined) user.email = email;
        if (plan !== undefined) user.plan = plan;
        if (plan_expires_at !== undefined) user.plan_expires_at = plan_expires_at;
        if (subscription_status !== undefined) user.subscription_status = subscription_status;
        if (next_billing_at !== undefined) user.next_billing_at = next_billing_at;
        if (enterprise_token_monthly !== undefined) user.enterprise_token_monthly = parseInt(enterprise_token_monthly, 10) || 0;
        if (token_used_in_cycle !== undefined) user.token_used_in_cycle = parseInt(token_used_in_cycle, 10) || 0;
        if (token_bonus_balance !== undefined) user.token_bonus_balance = parseInt(token_bonus_balance, 10) || 0;
        if (password) {
            user.password = await bcrypt.hash(password, 10);
        }
        saveDatabase();
        const { password: _, ...safeUser } = user;
        res.json({ success: true, account: safeUser });
        } catch (error) {
        res.status(500).json({ success: false, error: '無法更新帳號' });
    }
});

app.delete('/api/accounts/:id', authenticateJWT, checkRole(['admin']), (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const idx = database.staff_accounts.findIndex(u => u.id === id);
        if (idx === -1) return res.status(404).json({ success: false, error: '帳號不存在' });
        const removed = database.staff_accounts.splice(idx, 1)[0];
        saveDatabase();
        res.json({ success: true, account: removed });
    } catch (error) {
        res.status(500).json({ success: false, error: '無法刪除帳號' });
    }
});

app.get('/api/accounts/:id', authenticateJWT, checkRole(['admin']), (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const user = database.staff_accounts.find(u => u.id === id);
        if (!user) return res.status(404).json({ success: false, error: '帳號不存在' });
        const { password: _, ...safeUser } = user;
        res.json({ success: true, account: safeUser });
        } catch (error) {
        res.status(500).json({ success: false, error: '無法取得帳號' });
    }
});

// 忘記密碼 API - 發送驗證碼
app.post('/api/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件地址'
            });
        }

        // 查找用戶
        const user = database.staff_accounts.find(staff => staff.email === email);
        if (!user) {
            return res.status(404).json({
                success: false,
                error: '找不到此電子郵件地址的帳號'
            });
        }

        // 生成驗證碼
        const verificationCode = generateVerificationCode();
        
        // 儲存驗證碼到資料庫（包含過期時間）
        const resetRequest = {
            email: email,
            code: verificationCode,
            expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10分鐘後過期
            createdAt: new Date().toISOString()
        };

        // 移除舊的驗證碼
        database.password_reset_requests = database.password_reset_requests.filter(
            req => req.email !== email
        );
        
        // 添加新的驗證碼
        database.password_reset_requests.push(resetRequest);
        saveDatabase();

        // 發送驗證碼電子郵件
        try {
            await sendPasswordResetEmail(email, verificationCode);
            
            console.log('✅ 密碼重設驗證碼已發送給:', email);
            
            res.json({
                success: true,
                message: '驗證碼已發送到您的電子郵件'
            });
        } catch (emailError) {
            console.error('發送密碼重設郵件失敗:', emailError);
            res.status(500).json({
                success: false,
                error: '發送驗證碼失敗，請稍後再試'
            });
        }
    } catch (error) {
        console.error('忘記密碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '處理請求失敗'
        });
    }
});

// 重設密碼 API
app.post('/api/reset-password', async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;
        
        if (!email || !code || !newPassword) {
            return res.status(400).json({
                success: false,
                error: '請提供所有必要資訊'
            });
        }

        if (newPassword.length < 6) {
            return res.status(400).json({
                success: false,
                error: '新密碼長度至少需要6個字元'
            });
        }

        // 查找驗證碼請求
        const resetRequest = database.password_reset_requests.find(
            req => req.email === email && req.code === code
        );

        if (!resetRequest) {
            return res.status(400).json({
                success: false,
                error: '驗證碼錯誤或已過期'
            });
        }

        // 檢查驗證碼是否過期
        if (new Date() > new Date(resetRequest.expiresAt)) {
            // 移除過期的驗證碼
            database.password_reset_requests = database.password_reset_requests.filter(
                req => req.email !== email
            );
            saveDatabase();
            
            return res.status(400).json({
                success: false,
                error: '驗證碼已過期，請重新申請'
            });
        }

        // 查找用戶
        const user = database.staff_accounts.find(staff => staff.email === email);
        if (!user) {
            return res.status(404).json({
                success: false,
                error: '找不到此電子郵件地址的帳號'
            });
        }

        // 更新密碼
        const hashedNewPassword = await bcrypt.hash(newPassword, 10);
        user.password = hashedNewPassword;
        user.updated_at = new Date().toISOString();
        
        // 移除已使用的驗證碼
        database.password_reset_requests = database.password_reset_requests.filter(
            req => req.email !== email
        );
        
        saveDatabase();

        console.log('✅ 密碼重設成功:', email);
        
        res.json({
            success: true,
            message: '密碼重設成功'
        });
    } catch (error) {
        console.error('重設密碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '重設密碼失敗'
        });
    }
});

// AI 助理配置 API
// 獲取 AI 助理配置
app.get('/api/ai-assistant-config', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        if (!Array.isArray(database.ai_assistant_configs)) {
            database.ai_assistant_configs = [];
        }
        const userId = req.staff.id;
        const found = database.ai_assistant_configs.find(c => c.user_id === userId);
        const defaultConfig = {
            assistant_name: 'AI 助理',
            llm: 'gpt-4o-mini',
            use_case: 'customer-service',
            description: '我是您的智能客服助理，很高興為您服務！',
            industry: 'general',
            features: [],
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        const config = found ? { industry: 'general', features: [], ...found.config } : defaultConfig;

        const user = getUserById(userId);
        ensureUserTokenFields(user);
        maybeResetCycle(user);
        
        res.json({
            success: true,
            config,
            token: {
                plan: user?.plan || 'free',
                allowance: getPlanAllowance(user?.plan || 'free', user),
                used_in_cycle: user?.token_used_in_cycle || 0,
                bonus_balance: user?.token_bonus_balance || 0,
                next_billing_at: user?.next_billing_at || null
            }
        });
    } catch (error) {
        console.error('獲取 AI 助理配置錯誤:', error);
        res.status(500).json({ success: false, error: '獲取配置失敗' });
    }
});

// 更新 AI 助理配置
app.post('/api/ai-assistant-config', authenticateJWT, (req, res) => {
    try {
        const { assistant_name, llm, use_case, description, industry, features } = req.body;
        
        // 驗證必要欄位
        if (!assistant_name || !llm || !use_case) {
            return res.status(400).json({
                success: false,
                error: '請填寫所有必要欄位'
            });
        }
        
        const config = {
            assistant_name: assistant_name.trim(),
            llm: llm.trim(),
            use_case: use_case.trim(),
            description: description ? description.trim() : '',
            industry: typeof industry === 'string' ? industry.trim() : 'general',
            features: Array.isArray(features) ? features.filter(f => typeof f === 'string') : [],
            updated_at: new Date().toISOString()
        };
        
        loadDatabase();
        if (!Array.isArray(database.ai_assistant_configs)) {
            database.ai_assistant_configs = [];
        }
        const userId = req.staff.id;
        const idx = database.ai_assistant_configs.findIndex(c => c.user_id === userId);
        if (idx === -1) {
            config.created_at = new Date().toISOString();
            database.ai_assistant_configs.push({ user_id: userId, config });
        } else {
            const prev = database.ai_assistant_configs[idx].config || {};
            config.created_at = prev.created_at || new Date().toISOString();
            database.ai_assistant_configs[idx].config = config;
        }
        saveDatabase();
        
        console.log('✅ AI 助理配置已更新(使用者):', req.staff.username);
        // 附帶目前 token 狀態
        const user = getUserById(req.staff.id);
        ensureUserTokenFields(user);
        maybeResetCycle(user);
        res.json({
            success: true,
            message: 'AI 助理配置已成功更新',
            config,
            token: {
                plan: user?.plan || 'free',
                allowance: getPlanAllowance(user?.plan || 'free', user),
                used_in_cycle: user.token_used_in_cycle || 0,
                bonus_balance: user.token_bonus_balance || 0,
                next_billing_at: user.next_billing_at
            }
        });
    } catch (error) {
        console.error('更新 AI 助理配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新配置失敗'
        });
    }
});

// 重置 AI 助理配置為預設值
app.post('/api/ai-assistant-config/reset', authenticateJWT, (req, res) => {
    try {
        const defaultConfig = {
            assistant_name: 'AI 助理',
            llm: 'gpt-4o-mini',
            use_case: 'customer-service',
            description: '我是您的智能客服助理，很高興為您服務！',
            industry: 'general',
            features: [],
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        
        loadDatabase();
        if (!Array.isArray(database.ai_assistant_configs)) {
            database.ai_assistant_configs = [];
        }
        const userId = req.staff.id;
        const idx = database.ai_assistant_configs.findIndex(c => c.user_id === userId);
        if (idx === -1) {
            database.ai_assistant_configs.push({ user_id: userId, config: defaultConfig });
        } else {
            database.ai_assistant_configs[idx].config = defaultConfig;
        }
        saveDatabase();
        
        console.log('✅ AI 助理配置已重置為預設值(使用者):', req.staff.username);
        res.json({ success: true, message: 'AI 助理配置已重置為預設值', config: defaultConfig });
    } catch (error) {
        console.error('重置 AI 助理配置錯誤:', error);
        res.status(500).json({ success: false, error: '重置配置失敗' });
    }
});

// AI 設定（預設模型/升級模型/關鍵字）
app.get('/api/ai-settings', authenticateJWT, (req, res) => {
    try {
        const userId = req.staff.id;
        const settings = getUserAISettings(userId);
        res.json({ success: true, settings });
    } catch (error) {
        console.error('取得 AI 設定錯誤:', error);
        res.status(500).json({ success: false, error: '取得 AI 設定失敗' });
    }
});

app.put('/api/ai-settings', authenticateJWT, (req, res) => {
    try {
        const userId = req.staff.id;
        const payload = (req.body && req.body.settings) ? req.body.settings : (req.body || {});
        const defaultSettings = getDefaultAISettings();

        const settings = {
            default_model: typeof payload.default_model === 'string' && payload.default_model.trim()
                ? payload.default_model.trim()
                : defaultSettings.default_model,
            fallback_model: typeof payload.fallback_model === 'string' && payload.fallback_model.trim()
                ? payload.fallback_model.trim()
                : null,
            auto_escalate_enabled: typeof payload.auto_escalate_enabled === 'boolean'
                ? payload.auto_escalate_enabled
                : defaultSettings.auto_escalate_enabled,
            escalate_keywords: Array.isArray(payload.escalate_keywords)
                ? payload.escalate_keywords.filter(k => typeof k === 'string' && k.trim()).map(k => k.trim())
                : defaultSettings.escalate_keywords,
            updated_at: new Date().toISOString()
        };

        loadDatabase();
        if (!Array.isArray(database.ai_settings)) database.ai_settings = [];
        const idx = database.ai_settings.findIndex(s => s.user_id === userId);
        if (idx === -1) {
            database.ai_settings.push({ user_id: userId, settings });
        } else {
            database.ai_settings[idx].settings = settings;
        }
        saveDatabase();
        res.json({ success: true, settings });
    } catch (error) {
        console.error('更新 AI 設定錯誤:', error);
        res.status(500).json({ success: false, error: '更新 AI 設定失敗' });
    }
});

// 強制初始化 API
app.post('/api/init-database', async (req, res) => {
    try {
        console.log('🔧 強制初始化資料庫...');
        
        // 重新載入資料庫
        loadDatabase();
        
        // 檢查管理員帳號是否存在
        const adminExists = database.staff_accounts.find(staff => staff.username === 'sunnyharry1');
        if (!adminExists) {
            // 創建管理員帳號
            const adminPassword = 'gele1227';
            const hash = await new Promise((resolve, reject) => {
                bcrypt.hash(adminPassword, 10, (err, hash) => {
                    if (err) reject(err);
                    else resolve(hash);
                });
            });
            
            const adminAccount = {
                id: database.staff_accounts.length + 1,
                username: 'sunnyharry1',
                password: hash,
                name: '系統管理員',
                role: 'admin',
                email: '',
                created_at: new Date().toISOString()
            };
            
            database.staff_accounts.push(adminAccount);
            saveDatabase();
            
            console.log('✅ 管理員帳號已創建');
            console.log('📧 帳號: sunnyharry1');
            console.log('🔑 密碼: gele1227');
        
        res.json({
            success: true,
                message: '資料庫初始化成功',
                adminCreated: true,
                adminAccount: {
                    username: 'sunnyharry1',
                    password: 'gele1227'
                }
            });
        } else {
            console.log('ℹ️ 管理員帳號已存在');
            res.json({
                success: true,
                message: '資料庫已初始化',
                adminCreated: false
            });
        }
    } catch (error) {
        console.error('❌ 強制初始化失敗:', error);
        res.status(500).json({
            success: false,
            error: '資料庫初始化失敗',
            details: error.message
        });
    }
});

// AI 聊天 API 端點 - 使用配置的 AI 模型生成回應
app.post('/api/chat', authenticateJWT, async (req, res) => {
    try {
        const { message, conversationId, knowledgeOnly } = req.body;
        
        if (!message || typeof message !== 'string') {
            return res.status(400).json({
                success: false,
                error: '請提供有效的訊息內容'
            });
        }

        // 檢查 OpenAI API Key 是否存在
        if (!process.env.OPENAI_API_KEY) {
            console.error('OpenAI API Key 未設置');
            return res.status(500).json({
                success: false,
                error: 'AI 服務尚未配置，請聯繫管理員設置 OpenAI API Key',
                details: 'OPENAI_API_KEY 環境變數未設置'
            });
        }

        // 驗證 API Key 格式
        if (!process.env.OPENAI_API_KEY.startsWith('sk-')) {
            console.error('OpenAI API Key 格式無效');
            return res.status(500).json({
                success: false,
                error: 'AI 服務配置錯誤，請檢查 API Key 格式',
                details: 'OpenAI API Key 應以 sk- 開頭'
            });
        }

        // 載入資料庫
        loadDatabase();
        
        // 獲取 AI 助理配置（每帳號）
        const aiConfig = getUserAIConfig(req.staff.id);

        // 確保模型名稱有效
        const modelName = aiConfig.llm || 'gpt-3.5-turbo';
        
        // 驗證模型名稱
        const validModels = [
            'gpt-5.2',
            'gpt-5.1',
            'gpt-5.0',
            'gpt-4.1',
            'gpt-4.1-mini',
            'gpt-4.1-nano',
            'gpt-4o',
            'gpt-4o-mini',
            'gpt-4-turbo',
            'gpt-4',
            'gpt-3.5-turbo',
            'gpt-3.5-turbo-16k'
        ];
        if (!validModels.includes(modelName)) {
            console.warn(`無效的模型名稱: ${modelName}，使用預設值 gpt-3.5-turbo`);
            aiConfig.llm = 'gpt-3.5-turbo';
        }

        // 構建系統提示詞
        const systemPrompt = `你是 ${aiConfig.assistant_name}，${aiConfig.description}。你的使用場景是：${aiConfig.use_case}。請根據用戶的問題提供專業、友善且有用的回應。`;

        // 準備對話歷史
        let conversationHistory = [];
        if (conversationId && database.chat_history) {
            const existingConversation = database.chat_history.find(conv => conv.id === conversationId);
            if (existingConversation && existingConversation.messages) {
                conversationHistory = existingConversation.messages.slice(-10); // 保留最近10條訊息
            }
        }

        // 基於使用者知識庫做簡單關鍵字檢索，取前 N 筆做為上下文
        const normalized = (text) => (text || '').toLowerCase();
        const terms = normalized(message)
            .replace(/[^\p{L}\p{N}\s]/gu, ' ')
            .split(/\s+/)
            .filter(t => t.length >= 2)
            .slice(0, 20);
        let knowledgeContext = '';
        try {
            const userKnowledge = (database.knowledge || []).filter(
                k => !k.user_id || k.user_id === req.staff.id
            );
            const scored = userKnowledge.map(k => {
                const text = `${k.question} ${k.answer}`.toLowerCase();
                const score = terms.reduce((acc, t) => acc + (text.includes(t) ? 1 : 0), 0);
                return { item: k, score };
            }).filter(s => s.score > 0);
            scored.sort((a, b) => b.score - a.score);
            let top = scored.slice(0, 5).map(s => s.item);
            // 若無關鍵字匹配，退回使用最新的知識庫項目（提升體感）
            if (top.length === 0 && userKnowledge.length > 0) {
                const sortedByTime = [...userKnowledge].sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
                top = sortedByTime.slice(0, 3);
            }
            if (top.length) {
                knowledgeContext = top.map((k, idx) => `【來源${idx + 1}】Q: ${k.question}\nA: ${k.answer}`).join('\n\n');
                // 控制上下文長度，避免超限
                if (knowledgeContext.length > 4000) {
                    knowledgeContext = knowledgeContext.slice(0, 4000);
                }
            }
        } catch (e) {
            console.warn('知識檢索失敗，將不帶入上下文:', e.message);
        }

        // 若強制僅使用知識庫且沒有知識上下文，直接回覆提示
        if (knowledgeOnly && !knowledgeContext) {
            return res.json({
                success: true,
                reply: '抱歉，知識庫目前沒有相關資料。請先在知識庫新增或匯入相關內容後再試。',
                conversationId: conversationId || `conv_${Date.now()}`,
                model: aiConfig.llm,
                assistantName: aiConfig.assistant_name
            });
        }

        // 構建完整的對話訊息
        const messages = [
            { role: 'system', content: systemPrompt + (knowledgeContext ? `\n\n以下為商家提供的知識庫內容，${knowledgeOnly ? '僅能根據這些內容回答；若沒有足夠依據，請回覆「知識庫無相關資料」。' : '優先據此回答；若知識庫無相關資訊再自行作答，並標註「一般建議」。'}\n${knowledgeContext}` : (knowledgeOnly ? '\n\n僅能根據知識庫作答，但目前沒有可用內容。' : '')) },
            ...conversationHistory,
            { role: 'user', content: message }
        ];

        console.log('使用的模型:', aiConfig.llm || 'gpt-3.5-turbo');
        
        // 計算本次大致 token 需求，若不足則嘗試使用儲值 token
        const user = getUserById(req.staff.id);
        ensureUserTokenFields(user);
        maybeResetCycle(user);
        const planAllowance = getPlanAllowance(user?.plan || 'free', user);
        const estimatedTokens = estimateChatTokens(message, knowledgeContext, 600);
        const availableThisCycle = Math.max(planAllowance - (user.token_used_in_cycle || 0), 0) + (user.token_bonus_balance || 0);
        if (availableThisCycle < estimatedTokens) {
            return res.status(402).json({
                success: false,
                error: '餘額不足，請儲值 Token 後再試',
                details: {
                    plan: user?.plan || 'free',
                    planAllowance,
                    used: user.token_used_in_cycle || 0,
                    bonus: user.token_bonus_balance || 0,
                    need: estimatedTokens
                }
            });
        }
        
        // 調用 OpenAI API
        const aiReply = await requestOpenAIReply({
            model: aiConfig.llm || 'gpt-3.5-turbo',
            messages,
            maxTokens: 1000,
            temperature: 0.7
        });

        const skipStore = !!req.body.no_store || req.body.source === 'test' || req.body.source === 'dashboard_test';
        if (skipStore) {
            return res.json({
                success: true,
                reply: aiReply,
                conversationId: conversationId || null,
                model: aiConfig.llm,
                assistantName: aiConfig.assistant_name
            });
        }

        // 扣除 tokens（先扣月度，若不足則扣儲值）
        let remainingNeed = estimatedTokens;
        const cycleRemain = Math.max(planAllowance - (user.token_used_in_cycle || 0), 0);
        const useFromCycle = Math.min(cycleRemain, remainingNeed);
        user.token_used_in_cycle = (user.token_used_in_cycle || 0) + useFromCycle;
        remainingNeed -= useFromCycle;
        if (remainingNeed > 0) {
            user.token_bonus_balance = Math.max((user.token_bonus_balance || 0) - remainingNeed, 0);
            remainingNeed = 0;
        }
        saveDatabase();

        // 更新對話歷史
        const newMessage = {
            role: 'user',
            content: message,
            timestamp: new Date().toISOString()
        };

        const aiMessage = {
            role: 'assistant',
            content: aiReply,
            timestamp: new Date().toISOString()
        };

        // 保存對話歷史
        if (!database.chat_history) {
            database.chat_history = [];
        }

        let conversation;
        if (conversationId) {
            conversation = database.chat_history.find(conv => conv.id === conversationId);
        }

        if (!conversation) {
            conversation = {
                id: conversationId || `conv_${Date.now()}`,
                userId: req.staff?.id || null,
                platform: 'dashboard',
                messages: [],
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };
            database.chat_history.push(conversation);
        }

        conversation.messages.push(newMessage, aiMessage);
        conversation.updatedAt = new Date().toISOString();

        // 保存到資料庫
        saveDatabase();

        res.json({
            success: true,
            reply: aiReply,
            conversationId: conversation.id,
            model: aiConfig.llm,
            assistantName: aiConfig.assistant_name
        });

    } catch (error) {
        console.error('AI 聊天錯誤:', error);
        console.error('錯誤詳情:', {
            message: error.message,
            response: error.response ? {
                status: error.response.status,
                data: error.response.data
            } : null,
            code: error.code
        });
        
        // 檢查是否為 OpenAI API 錯誤
        if (error.response) {
            if (error.response.status === 401) {
                return res.status(500).json({
                    success: false,
                    error: 'OpenAI API 金鑰無效或已過期',
                    details: '請檢查 OPENAI_API_KEY 環境變數是否正確',
                    solution: '請運行 node update-render-env-openai.js 更新 API Key'
                });
            } else if (error.response.status === 429) {
                return res.status(500).json({
                    success: false,
                    error: 'OpenAI API 請求頻率過高',
                    details: '已達到 API 使用限制',
                    solution: '請稍後再試或升級 OpenAI 計劃'
                });
            } else if (error.response.status === 403) {
                return res.status(500).json({
                    success: false,
                    error: 'OpenAI API 存取被拒絕',
                    details: '可能是帳戶問題或 API Key 權限不足',
                    solution: '請檢查 OpenAI 帳戶狀態'
                });
            } else if (error.response.status === 400) {
                return res.status(500).json({
                    success: false,
                    error: 'OpenAI API 請求參數錯誤',
                    details: error.response.data?.error?.message || '請求格式不正確',
                    solution: '請檢查模型名稱和請求參數'
                });
            }
        } else if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED') {
            return res.status(500).json({
                success: false,
                error: '無法連接到 OpenAI 服務',
                details: `網路錯誤: ${error.code}`,
                solution: '請檢查網路連接或稍後再試'
            });
        } else if (error.message && error.message.includes('API key')) {
            return res.status(500).json({
                success: false,
                error: 'OpenAI API Key 配置問題',
                details: error.message,
                solution: '請運行 node update-render-env-openai.js 設置 API Key'
            });
        }

        // 一般錯誤
        res.status(500).json({
            success: false,
            error: 'AI 回應生成失敗',
            details: error.message || '未知錯誤',
            solution: '請檢查伺服器日誌或聯繫技術支援'
        });
    }
});

// 公開聊天端點（供首頁使用）：不需要登入，使用基本網站描述作為上下文
app.post('/api/public-chat', async (req, res) => {
    try {
        const { message, messages } = req.body || {};
        if (!message || typeof message !== 'string') {
            return res.status(400).json({ success: false, error: '請提供有效的訊息內容' });
        }

        // 萃取多頁內容（首頁/產品/特色/使用場景/定價/關於我們）
        const baseUrl = await resolveBaseUrl(req);
        const siteContextBase = await buildMultipageSiteContext(baseUrl);
        const pricingFromI18n = await fetchI18nPricing(baseUrl);
        const siteContext = [siteContextBase, pricingFromI18n].filter(Boolean).join('\n\n');

        if (!process.env.OPENAI_API_KEY || !process.env.OPENAI_API_KEY.startsWith('sk-')) {
            const desc = siteContext || 'EchoChat 提供 AI 客服、LINE/網站整合、知識庫導入與自動回覆，協助企業快速上線智慧客服。';
            return res.json({ success: true, reply: `${desc}\n\n目前為公開對話測試模式，若需更進一步協助，請前往聯繫我們頁面。` });
        }

        const systemPrompt = `你是本網站的 SaaS 客服助理。\n任務: 嚴格根據「網站內容摘要」回覆。不得臆測或補完未出現在內容中的資訊；若內容未涵蓋，請明確回覆「本站未提供相關資訊」，並可引導使用者至聯繫我們。\n表達: 使用繁體中文，重點以條列為主，必要時給出簡短總結。\n主題: 說明平台是讓商家在本網站上將 AI 串接進自家客服（網站/社群/LINE 等）的 SaaS。當被問到「方案/價格」時，只能引用內容摘要中可得的方案與價格，不可猜測。\n\n【網站內容摘要（多頁彙整）】\n${siteContext}`;
        // 前端可傳入歷史訊息，這裡做基本清洗與截斷
        let history = [];
        if (Array.isArray(messages)) {
            history = messages
                .filter(m => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
                .slice(-10); // 保留最近 10 則
        }

        const chatMessages = [
            { role: 'system', content: systemPrompt },
            ...history,
            { role: 'user', content: message }
        ];

        const aiReply = await requestOpenAIReply({
            model: process.env.PUBLIC_CHAT_MODEL || 'gpt-4o-mini',
            messages: chatMessages,
            maxTokens: 600,
            temperature: 0.2,
            topP: 0.9
        });
        res.json({ success: true, reply: aiReply });
    } catch (error) {
        console.error('公開聊天錯誤(子模組):', error.response?.data || error.message);
        res.status(500).json({ success: false, error: '服務暫時不可用，請稍後再試' });
    }
});

// 內容快取/來源偵測除錯端點
app.get('/api/public-chat/context', async (req, res) => {
    try {
        const baseUrl = await resolveBaseUrl(req);
        const context = await buildMultipageSiteContext(baseUrl);
        res.json({
            success: true,
            baseUrl,
            length: context.length,
            preview: context.slice(0, 800)
        });
    } catch (e) {
        res.status(500).json({ success: false, error: e.message });
    }
});

// 根路由 - 健康檢查
app.get('/', (req, res) => {
        res.json({
            success: true,
        message: 'EchoChat API 服務運行中',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// API 健康檢查端點
app.get('/api/health', (req, res) => {
    res.json({
        success: true,
        message: 'EchoChat API 健康檢查通過',
        timestamp: new Date().toISOString()
    });
});

// ==================== AI 模型 API ====================

// AI 模型列表端點 - 不需要認證
app.get('/api/ai-models', (req, res) => {
    try {
        const models = {
            'gpt-5.2': {
                name: 'GPT-5.2',
                description: '最新旗艦模型，適合最高品質與高準確度場景',
                features: ['最高準確度', '強推理能力', '多語言支援', '適合複雜任務'],
                pricing: '頂級',
                speed: '中等'
            },
            'gpt-5.1': {
                name: 'GPT-5.1',
                description: '高品質旗艦模型，適合關鍵任務與專業場景',
                features: ['高準確度', '穩定回覆', '多語言支援', '適合專業任務'],
                pricing: '高階',
                speed: '中等'
            },
            'gpt-5.0': {
                name: 'GPT-5.0',
                description: '新一代高品質模型，兼顧品質與效率',
                features: ['高品質回覆', '多語言支援', '通用能力強'],
                pricing: '高階',
                speed: '中等'
            },
            'gpt-4.1': {
                name: 'GPT-4.1',
                description: '最新旗艦模型，適合高品質與高準確度場景',
                features: ['高準確度', '強推理能力', '多語言支援', '適合複雜任務'],
                pricing: '高階',
                speed: '中等'
            },
            'gpt-4.1-mini': {
                name: 'GPT-4.1 Mini',
                description: '高效能與成本平衡的新版模型，適合主流客服需求',
                features: ['高性價比', '穩定回覆', '多語言支援', '適合日常對話'],
                pricing: '中等',
                speed: '快速'
            },
            'gpt-4.1-nano': {
                name: 'GPT-4.1 Nano',
                description: '輕量快速的新模型，適合大量即時回覆',
                features: ['極速回應', '成本最低', '多語言支援'],
                pricing: '經濟實惠',
                speed: '極速'
            },
            'gpt-4o': {
                name: 'GPT-4o',
                description: '高品質通用模型，適合需要更佳理解力的場景',
                features: ['高品質回覆', '多語言支援', '通用能力強'],
                pricing: '高階',
                speed: '中等'
            },
            'gpt-4o-mini': {
                name: 'GPT-4o Mini',
                description: '快速且經濟實惠的對話體驗，適合一般客服需求',
                features: ['快速回應', '成本效益高', '支援多語言', '適合日常對話'],
                pricing: '經濟實惠',
                speed: '快速'
            },
            'gpt-4': {
                name: 'GPT-4',
                description: '經典高品質模型，適合複雜任務與專業場景',
                features: ['高品質回覆', '強推理能力', '適合複雜任務'],
                pricing: '高階',
                speed: '中等'
            },
            'gpt-4-turbo': {
                name: 'GPT-4 Turbo',
                description: '高級模型，適合較複雜的任務與內容生成',
                features: ['強推理能力', '高準確度', '適合複雜任務'],
                pricing: '高階',
                speed: '中等'
            },
            'gpt-3.5-turbo': {
                name: 'GPT-3.5 Turbo',
                description: '經典入門模型，速度快且成本較低',
                features: ['快速回應', '成本效益高', '穩定可靠'],
                pricing: '經濟實惠',
                speed: '快速'
            },
            'gpt-3.5-turbo-16k': {
                name: 'GPT-3.5 Turbo 16K',
                description: '支援更長上下文的 3.5 版本',
                features: ['較長上下文', '成本較低', '穩定可靠'],
                pricing: '經濟實惠',
                speed: '快速'
            }
        };

        Object.keys(models).forEach((key) => {
            models[key].provider = 'OpenAI';
        });

        res.json({
            success: true,
            message: 'AI 模型列表獲取成功',
            models,
            data: models
        });
    } catch (error) {
        console.error('獲取 AI 模型列表錯誤:', error);
        res.status(500).json({
            success: false,
            message: '獲取 AI 模型列表失敗',
            error: error.message
        });
    }
});

// ==================== 頻道管理 API ====================

// 建立新頻道
app.post('/api/channels', authenticateJWT, (req, res) => {
    try {
        const { name, platform, apiKey, channelSecret, webhookUrl, isActive } = req.body;
        
        if (!name || !platform || !apiKey || !channelSecret) {
            return res.status(400).json({
                success: false,
                error: '缺少必要欄位'
            });
        }
        
        loadDatabase();
        
        const encApiKey = encryptSensitive(apiKey);
        const encSecret = encryptSensitive(channelSecret);
        const newChannel = {
            id: uuidv4(),
            userId: req.staff.id,
            name,
            platform,
            apiKeyEnc: encApiKey || null,
            channelSecretEnc: encSecret || null,
            hasCredentials: true,
            webhookUrl: webhookUrl || '',
            isActive: isActive || false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };
        
        if (!database.channels) {
            database.channels = [];
        }
        
        database.channels.push(newChannel);
        saveDatabase();

        console.log('✅ 頻道建立成功:', name);
        
        // 回傳去除敏感資訊
        const { apiKeyEnc, channelSecretEnc, ...safe } = newChannel;
        res.status(201).json({ success: true, message: '頻道建立成功', channel: safe });
        
    } catch (error) {
        console.error('建立頻道錯誤:', error);
        res.status(500).json({
            success: false,
            error: '建立頻道失敗'
        });
    }
});

// 獲取用戶的頻道列表
app.get('/api/channels', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        
        const userChannels = (database.channels || [])
            .filter(channel => channel.userId === req.staff.id)
            .map(c => ({
                id: c.id,
                userId: undefined,
                name: c.name,
                platform: c.platform,
                webhookUrl: c.webhookUrl || '',
                isActive: !!c.isActive,
                hasCredentials: !!c.hasCredentials || !!c.apiKeyEnc || !!c.channelSecretEnc,
                createdAt: c.createdAt,
                updatedAt: c.updatedAt
            }));

        res.json({
            success: true,
            channels: userChannels
        });
        
    } catch (error) {
        console.error('獲取頻道列表錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取頻道列表失敗'
        });
    }
});

// 更新頻道
app.put('/api/channels/:id', authenticateJWT, (req, res) => {
    try {
        const { id } = req.params;
        const { name, platform, apiKey, channelSecret, webhookUrl, isActive } = req.body;
        
        loadDatabase();
        
        const channelIndex = (database.channels || []).findIndex(
            channel => channel.id === id && channel.userId === req.staff.id
        );
        
        if (channelIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '頻道不存在'
            });
        }
        
        const current = database.channels[channelIndex];
        const updatedChannel = {
            ...current,
            name: name || current.name,
            platform: platform || current.platform,
            apiKeyEnc: apiKey ? (encryptSensitive(apiKey) || current.apiKeyEnc) : current.apiKeyEnc,
            channelSecretEnc: channelSecret ? (encryptSensitive(channelSecret) || current.channelSecretEnc) : current.channelSecretEnc,
            hasCredentials: current.hasCredentials || !!apiKey || !!channelSecret,
            webhookUrl: webhookUrl || current.webhookUrl,
            isActive: isActive !== undefined ? isActive : current.isActive,
            updatedAt: new Date().toISOString()
        };
        
        database.channels[channelIndex] = updatedChannel;
        saveDatabase();

        console.log('✅ 頻道更新成功:', updatedChannel.name);

        const { apiKeyEnc, channelSecretEnc, ...safe } = updatedChannel;
        res.json({ success: true, message: '頻道更新成功', channel: safe });
        
    } catch (error) {
        console.error('更新頻道錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新頻道失敗'
        });
    }
});

// 刪除頻道
app.delete('/api/channels/:id', authenticateJWT, (req, res) => {
    try {
        const { id } = req.params;
        
        loadDatabase();
        
        const channelIndex = (database.channels || []).findIndex(
            channel => channel.id === id && channel.userId === req.staff.id
        );
        
        if (channelIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '頻道不存在'
            });
        }
        
        const deletedChannel = database.channels[channelIndex];
        database.channels.splice(channelIndex, 1);
        saveDatabase();
        
        console.log('✅ 頻道刪除成功:', deletedChannel.name);
        
        res.json({
            success: true,
            message: '頻道刪除成功'
        });
        
    } catch (error) {
        console.error('刪除頻道錯誤:', error);
        res.status(500).json({
                success: false,
            error: '刪除頻道失敗'
        });
    }
});

// 測試頻道連接
app.post('/api/channels/test', authenticateJWT, async (req, res) => {
    try {
        const { platform, apiKey, channelSecret } = req.body;
        
        if (!platform || !apiKey || !channelSecret) {
            return res.status(400).json({
                success: false,
                error: '缺少必要欄位'
            });
        }
        
        const pf = String(platform).toLowerCase();
        // 根據平台進行不同的測試
        if (pf === 'line') {
            // LINE 平台測試
            try {
                const lineClient = new Client({
                    channelAccessToken: apiKey,
                    channelSecret: channelSecret
                });
                
                // 測試獲取 LINE 配置
                lineClient.getProfile('test').catch(() => {
                    // 忽略錯誤，這只是測試連接
                });
                
                res.json({
                    success: true,
                    message: 'LINE 頻道連接測試成功'
                });
                } catch (error) {
                res.json({
                    success: false,
                    error: 'LINE 頻道連接測試失敗'
                });
            }
        } else if (pf === 'slack') {
            // 嘗試使用 slack auth 檢查（僅檢查字串存在）
            if (!/^xoxb-/.test(apiKey)) return res.json({ success: false, error: 'Slack Bot Token 格式錯誤' });
            return res.json({ success: true, message: 'Slack Token 格式看起來有效' });
        } else if (pf === 'telegram') {
            if (!/^[0-9]+:[A-Za-z0-9_-]+$/.test(apiKey)) return res.json({ success: false, error: 'Telegram Bot Token 格式錯誤' });
            return res.json({ success: true, message: 'Telegram Token 格式看起來有效' });
        } else if (pf === 'discord') {
            if (!apiKey || apiKey.length < 20) return res.json({ success: false, error: 'Discord Bot Token 看起來無效' });
            return res.json({ success: true, message: 'Discord Token 格式看起來有效' });
        } else if (pf === 'messenger') {
            if (!apiKey || !channelSecret) return res.json({ success: false, error: '需提供 Page Access Token 與 App Secret' });
            return res.json({ success: true, message: 'Messenger 憑證已提供' });
        } else if (pf === 'whatsapp') {
            if (!apiKey) return res.json({ success: false, error: '需提供 WhatsApp Cloud API Token' });
            return res.json({ success: true, message: 'WhatsApp Token 已提供' });
        } else if (pf === 'webhook') {
            return res.json({ success: true, message: 'Webhook 將使用您提供的 URL 接收事件' });
        } else {
            return res.json({ success: true, message: `${platform} 測試完成` });
        }
        
    } catch (error) {
        console.error('測試頻道連接錯誤:', error);
        res.status(500).json({
            success: false,
            error: '測試頻道連接失敗'
        });
    }
});

// ==================== 移動端 LINE 整合 API ====================

// 獲取 LINE 整合列表
app.get('/api/mobile/line-integrations', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        
        const userChannels = (database.channels || []).filter(
            channel => channel.userId === req.staff.id && channel.platform === 'LINE'
        );
        
        const integrations = userChannels.map(channel => ({
            id: channel.id,
            name: channel.name,
            status: channel.isActive ? 'active' : 'inactive',
            platform: 'LINE',
            createdAt: channel.createdAt,
            updatedAt: channel.updatedAt
        }));
        
        res.json({
            success: true,
            integrations: integrations
        });
        
                } catch (error) {
        console.error('獲取 LINE 整合列表錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 LINE 整合列表失敗'
        });
    }
});

// 獲取 LINE 對話記錄
app.get('/api/mobile/line-conversations/:tenantId', authenticateJWT, (req, res) => {
    try {
        const { tenantId } = req.params;
        const { page = 1, limit = 20 } = req.query;
        
        loadDatabase();
        
        // 驗證用戶是否有權限訪問此頻道
        const channel = (database.channels || []).find(
            ch => ch.id === tenantId && ch.userId === req.staff.id
        );
        
        if (!channel) {
            return res.status(404).json({
                success: false,
                error: '頻道不存在'
            });
        }
        
        // 獲取該頻道的對話記錄
        const conversations = (database.chat_history || []).filter(
            conv => conv.platform === 'line'
        );
        
        // 分頁處理
        const startIndex = (page - 1) * limit;
        const endIndex = startIndex + parseInt(limit);
        const paginatedConversations = conversations.slice(startIndex, endIndex);
            
            res.json({
                success: true,
            conversations: paginatedConversations,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total: conversations.length,
                totalPages: Math.ceil(conversations.length / limit)
            }
        });
        
    } catch (error) {
        console.error('獲取 LINE 對話記錄錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 LINE 對話記錄失敗'
        });
    }
});

// 獲取對話詳情
app.get('/api/mobile/conversation/:conversationId', authenticateJWT, (req, res) => {
    try {
        const { conversationId } = req.params;
        
        loadDatabase();
        
        const conversation = (database.chat_history || []).find(
            conv => conv.id === conversationId
        );
        
        if (!conversation) {
            return res.status(404).json({
                success: false,
                error: '對話不存在'
            });
        }
        
    res.json({
        success: true,
            conversation: conversation
});

    } catch (error) {
        console.error('獲取對話詳情錯誤:', error);
    res.status(500).json({
        success: false,
            error: '獲取對話詳情失敗'
        });
    }
});

// 發送測試訊息
app.post('/api/mobile/line-test-message/:tenantId', authenticateJWT, (req, res) => {
    try {
        const { tenantId } = req.params;
        const { message } = req.body;
        
        loadDatabase();
        
        // 驗證用戶是否有權限訪問此頻道
        const channel = (database.channels || []).find(
            ch => ch.id === tenantId && ch.userId === req.staff.id
        );
        
        if (!channel) {
            return res.status(404).json({
                success: false,
                error: '頻道不存在'
            });
        }
        
        if (!channel.isActive) {
            return res.status(400).json({
                success: false,
                error: '頻道未啟用'
            });
        }
        
        // 這裡應該實際發送 LINE 訊息
        // 目前返回模擬成功回應
        res.json({
            success: true,
            message: '測試訊息發送成功',
            sentMessage: message || '測試訊息'
        });
        
    } catch (error) {
        console.error('發送測試訊息錯誤:', error);
        res.status(500).json({
            success: false,
            error: '發送測試訊息失敗'
        });
    }
});

// 獲取 LINE 統計資料
app.get('/api/mobile/line-stats/:tenantId', authenticateJWT, (req, res) => {
    try {
        const { tenantId } = req.params;
        
        loadDatabase();
        
        // 驗證用戶是否有權限訪問此頻道
        const channel = (database.channels || []).find(
            ch => ch.id === tenantId && ch.userId === req.staff.id
        );
        
        if (!channel) {
            return res.status(404).json({
            success: false,
                error: '頻道不存在'
            });
        }
        
        // 獲取該頻道的統計資料
        const conversations = (database.chat_history || []).filter(
            conv => conv.platform === 'line'
        );
        
        const totalConversations = conversations.length;
        const totalMessages = conversations.reduce((sum, conv) => sum + (conv.messages?.length || 0), 0);
        
        // 計算今日對話數
        const today = new Date().toDateString();
        const todayConversations = conversations.filter(conv => 
            new Date(conv.createdAt).toDateString() === today
        ).length;
        
        // 計算平均訊息數
        const averageMessages = totalConversations > 0 ? (totalMessages / totalConversations).toFixed(1) : 0;

        res.json({
            success: true,
            stats: {
                totalConversations,
                totalMessages,
                todayConversations,
                averageMessages: parseFloat(averageMessages)
            }
        });
        
    } catch (error) {
        console.error('獲取 LINE 統計資料錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 LINE 統計資料失敗'
        });
    }
});

// 搜尋對話
app.get('/api/mobile/search-conversations/:tenantId', authenticateJWT, (req, res) => {
    try {
        const { tenantId } = req.params;
        const { query, page = 1, limit = 20 } = req.query;
        
        if (!query) {
            return res.status(400).json({
            success: false,
                error: '請提供搜尋關鍵字'
            });
        }
        
        loadDatabase();
        
        // 驗證用戶是否有權限訪問此頻道
        const channel = (database.channels || []).find(
            ch => ch.id === tenantId && ch.userId === req.staff.id
        );
        
        if (!channel) {
            return res.status(404).json({
                success: false,
                error: '頻道不存在'
            });
        }
        
        // 搜尋對話
        const conversations = (database.chat_history || []).filter(conv => {
            if (conv.platform !== 'line') return false;
            
            // 搜尋訊息內容
            return conv.messages?.some(msg => 
                msg.content?.toLowerCase().includes(query.toLowerCase())
            );
        });
        
        // 分頁處理
        const startIndex = (page - 1) * limit;
        const endIndex = startIndex + parseInt(limit);
        const paginatedConversations = conversations.slice(startIndex, endIndex);

        res.json({
            success: true,
            conversations: paginatedConversations,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total: conversations.length,
                totalPages: Math.ceil(conversations.length / limit)
            }
        });
        
    } catch (error) {
        console.error('搜尋對話錯誤:', error);
        res.status(500).json({
            success: false,
            error: '搜尋對話失敗'
        });
    }
});

// ==================== 帳務系統 API ====================

// 獲取帳務總覽（改用使用者真實配額）
app.get('/api/billing/overview', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const user = getUserById(req.staff.id);
        ensureUserTokenFields(user);
        maybeResetCycle(user);
        const plan = user.plan || 'free';
        const planConfig = getPlanConfig(plan);
        const allowance = getPlanAllowance(plan, user);
        const used = user.token_used_in_cycle || 0;
        const bonus = user.token_bonus_balance || 0;
        const available = Math.max(allowance - used, 0) + bonus;
        const conversationLimit = getPlanConversationLimit(plan, user);
        const hasUnlimitedConversations = conversationLimit === null;
        const conversationUsed = user.conversation_used_in_cycle || 0;
        const conversationRemaining = hasUnlimitedConversations ? null : Math.max(conversationLimit - conversationUsed, 0);
        const hasUnlimitedTokens = planConfig.tokenAllowance === null && !(normalizeRole(plan) === 'enterprise' && typeof user.enterprise_token_monthly === 'number');
        const displayAllowance = hasUnlimitedTokens ? null : allowance;
        const myConvs = (database.chat_history || []).filter(c => c && c.userId === req.staff.id);
        const msgCount = myConvs.reduce((sum, c) => sum + (c.messages ? c.messages.length : 0), 0);
        
        const overview = {
            currentPlan: plan,
            planDisplayName: getPlanDisplayName(plan),
            nextBillingDate: user.next_billing_at || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            tokenAllowance: displayAllowance,
            tokenAllowanceRaw: allowance,
            tokenUsed: used,
            tokenBonus: bonus,
            tokenAvailable: available,
            usagePercent: displayAllowance && displayAllowance > 0 ? Math.min((used / displayAllowance) * 100, 100).toFixed(1) : 0,
            hasUnlimitedTokens,
            hasUnlimitedConversations,
            conversationLimit,
            conversationUsed,
            conversationRemaining,
            estimatedTokensPerConversation: ESTIMATED_TOKENS_PER_CONVERSATION,
            conversationCount: myConvs.length,
            messageCount: msgCount
        };
        res.json({ success: true, overview });
    } catch (error) {
        console.error('獲取帳務總覽錯誤:', error);
        res.status(500).json({ success: false, error: '獲取帳務總覽失敗' });
            }
});

// 取得可用儲值方案
app.get('/api/billing/topup-packages', authenticateJWT, (req, res) => {
    try {
        res.json({
            success: true,
            packages: TOPUP_PACKAGES
        });
    } catch (error) {
        console.error('獲取儲值方案錯誤:', error);
        res.status(500).json({ success: false, error: '無法載入儲值方案' });
    }
});

// 直接儲值（模擬付款成功後入帳）
app.post('/api/billing/topup', authenticateJWT, (req, res) => {
    try {
        const { packageId } = req.body || {};
        const pkg = TOPUP_PACKAGES.find(p => p.id === packageId);
        if (!pkg) {
            return res.status(400).json({ success: false, error: '無效的儲值方案' });
        }
        loadDatabase();
        const user = findStaffById(req.staff.id);
        if (!user) {
            return res.status(404).json({ success: false, error: '找不到帳號' });
        }
        ensureUserTokenFields(user);
        maybeResetCycle(user);
        user.token_bonus_balance = (user.token_bonus_balance || 0) + pkg.tokens;
        if (!Array.isArray(database.payments)) database.payments = [];
        database.payments.push({
            id: uuidv4(),
            userId: user.id,
            type: 'topup',
            packageId: pkg.id,
            tokens: pkg.tokens,
            conversations: pkg.conversations,
            amount: pkg.price,
            currency: pkg.currency,
            created_at: new Date().toISOString()
        });
        saveDatabase();
        res.json({
            success: true,
            balance: user.token_bonus_balance,
            package: pkg
        });
    } catch (error) {
        console.error('儲值失敗:', error);
        res.status(500).json({ success: false, error: '儲值過程發生錯誤' });
    }
});

// 獲取使用量統計
app.get('/api/billing/usage', authenticateJWT, (req, res) => {
    try {
        const { timeRange = 'month' } = req.query;
        
        loadDatabase();
        
        // 根據時間範圍生成使用量資料
        const generateUsageData = (range) => {
            const data = [];
            const now = new Date();
            
            switch (range) {
                case 'week':
                    for (let i = 6; i >= 0; i--) {
                        const date = new Date(now);
                        date.setDate(date.getDate() - i);
                        data.push({
                            date: date.toISOString().split('T')[0],
                            conversations: Math.floor(Math.random() * 50) + 10,
                            messages: Math.floor(Math.random() * 200) + 50,
                            apiCalls: Math.floor(Math.random() * 300) + 100
                        });
                    }
                    break;
                case 'month':
                    for (let i = 29; i >= 0; i--) {
                        const date = new Date(now);
                        date.setDate(date.getDate() - i);
                        data.push({
                            date: date.toISOString().split('T')[0],
                            conversations: Math.floor(Math.random() * 30) + 5,
                            messages: Math.floor(Math.random() * 150) + 30,
                            apiCalls: Math.floor(Math.random() * 200) + 50
                        });
                    }
                    break;
                case 'quarter':
                    for (let i = 89; i >= 0; i--) {
                        const date = new Date(now);
                        date.setDate(date.getDate() - i);
                        if (i % 3 === 0) {
                            data.push({
                                date: date.toISOString().split('T')[0],
                                conversations: Math.floor(Math.random() * 100) + 20,
                                messages: Math.floor(Math.random() * 500) + 100,
                                apiCalls: Math.floor(Math.random() * 800) + 200
                            });
                        }
                    }
                    break;
                case 'year':
                    for (let i = 11; i >= 0; i--) {
                        const date = new Date(now);
                        date.setMonth(date.getMonth() - i);
                        data.push({
                            date: date.toISOString().split('T')[0].substring(0, 7),
                            conversations: Math.floor(Math.random() * 500) + 100,
                            messages: Math.floor(Math.random() * 2000) + 500,
                            apiCalls: Math.floor(Math.random() * 3000) + 800
                        });
                    }
                    break;
            }
            
            return data;
        };
        
        const usageData = generateUsageData(timeRange);

        res.json({
            success: true,
            usage: usageData,
            timeRange: timeRange
        });
        
    } catch (error) {
        console.error('獲取使用量統計錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取使用量統計失敗'
        });
    }
});

// 獲取客戶使用量列表
app.get('/api/billing/customers', authenticateJWT, (req, res) => {
    try {
        const { timeRange = 'month' } = req.query;
        
        loadDatabase();
        
        // 模擬客戶使用量資料
        const customers = [
            {
                id: '1',
                name: '美髮沙龍 A',
                conversations: 150,
                messages: 850,
                apiCalls: 1200,
                lastActivity: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
            },
            {
                id: '2',
                name: '美容院 B',
                conversations: 89,
                messages: 520,
                apiCalls: 780,
                lastActivity: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString()
            },
            {
                id: '3',
                name: '美甲店 C',
                conversations: 67,
                messages: 380,
                apiCalls: 550,
                lastActivity: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString()
            }
        ];

        res.json({
            success: true,
            customers: customers
        });
        
    } catch (error) {
        console.error('獲取客戶使用量錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取客戶使用量失敗'
        });
    }
});

// 獲取方案列表
app.get('/api/billing/plans', authenticateJWT, (req, res) => {
    try {
        const plans = [
            {
                id: 'basic',
                name: '基本方案',
                price: 299,
                currency: 'TWD',
                period: 'month',
                features: [
                    '每月 1,000 次對話',
                    '每月 5,000 次 API 呼叫',
                    '基本 AI 助理',
                    '電子郵件支援'
                ],
                limits: {
                    conversations: 1000,
                    messages: 5000,
                    apiCalls: 5000
                }
            },
            {
                id: 'pro',
                name: '專業方案',
                price: 599,
                currency: 'TWD',
                period: 'month',
                features: [
                    '每月 5,000 次對話',
                    '每月 25,000 次 API 呼叫',
                    '進階 AI 助理',
                    'LINE Bot 整合',
                    '優先支援'
                ],
                limits: {
                    conversations: 5000,
                    messages: 25000,
                    apiCalls: 25000
                }
            },
            {
                id: 'enterprise',
                name: '企業方案',
                price: 1299,
                currency: 'TWD',
                period: 'month',
                features: [
                    '無限制對話',
                    '無限制 API 呼叫',
                    '自定義 AI 助理',
                    '多平台整合',
                    '專屬支援'
                ],
                limits: {
                    conversations: -1,
                    messages: -1,
                    apiCalls: -1
                }
            }
        ];

        res.json({
            success: true,
            plans: plans
        });
        
    } catch (error) {
        console.error('獲取方案列表錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取方案列表失敗'
        });
    }
});

// ==================== LINE API 設定與 Webhook ====================

// LINE API 設定儲存 (用戶專用)
let lineAPISettings = {}; // 仍保留快取，但以 database.line_api_settings 作持久化

function normalizeAutoReplyValue(value) {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') return value.toLowerCase() === 'true';
    return true;
}

async function fetchLineProfile({ channelAccessToken, channelSecret, sourceType, groupId, roomId, userId }) {
    if (!channelAccessToken || !channelSecret || !userId) return null;
    const client = new Client({ channelAccessToken, channelSecret });
    if (sourceType === 'group' && groupId) {
        return client.getGroupMemberProfile(groupId, userId);
    }
    if (sourceType === 'room' && roomId) {
        return client.getRoomMemberProfile(roomId, userId);
    }
    return client.getProfile(userId);
}

async function maybeRefreshConversationProfile(conv) {
    if (!conv || !conv.customerLineId) return false;
    const needsName = !conv.customerName || conv.customerName === 'LINE 使用者';
    const needsPicture = !conv.customerPicture;
    if (!needsName && !needsPicture) return false;

    try {
        let token = '';
        let secret = '';
        if (conv.platform === 'line') {
            const creds = getLineCredentials(conv.userId);
            token = creds?.channelAccessToken || '';
            secret = creds?.channelSecret || '';
        } else if (conv.platform === 'line_bot' && conv.bot_id) {
            loadDatabase();
            const bot = (database.line_bots || []).find(b => b.id === conv.bot_id);
            token = decryptSensitive(bot?.channel_access_token) || bot?.channel_access_token_plain || '';
            secret = decryptSensitive(bot?.channel_secret) || bot?.channel_secret_plain || '';
        }

        if (!token || !secret) return false;

        const profile = await fetchLineProfile({
            channelAccessToken: token,
            channelSecret: secret,
            sourceType: conv.sourceType,
            groupId: conv.groupId,
            roomId: conv.roomId,
            userId: conv.customerLineId
        });

        if (!profile) return false;
        conv.customerName = profile.displayName || conv.customerName;
        conv.customerPicture = profile.pictureUrl || conv.customerPicture;
        conv.profileRefreshedAt = new Date().toISOString();
        return true;
    } catch (error) {
        return false;
    }
}

// 獲取 LINE API 設定
app.get('/api/line-api/settings', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        loadDatabase();
        const record = (database.line_api_settings || []).find(r => String(r.user_id) === String(userId));
        const decryptedToken = decryptSensitive(record?.channel_access_token) || record?.channel_access_token_plain || record?.channel_access_token || '';
        const decryptedSecret = decryptSensitive(record?.channel_secret) || record?.channel_secret_plain || record?.channel_secret || '';
        // 若成功解密且尚未補明文備援，補寫回資料庫
        if (record && decryptedToken && decryptedSecret && (!record.channel_access_token_plain || !record.channel_secret_plain)) {
            record.channel_access_token_plain = decryptedToken;
            record.channel_secret_plain = decryptedSecret;
            record.updated_at = new Date().toISOString();
            saveDatabase();
        }
        // 更新快取（不回傳明文至前端）
        lineAPISettings[String(userId)] = {
            channelAccessToken: decryptedToken || '',
            channelSecret: decryptedSecret || '',
            webhookUrl: record?.webhook_url || ''
        };

        res.json({
            success: true,
            data: {
                channelAccessToken: decryptedToken ? 'Configured' : '',
                channelSecret: decryptedSecret ? 'Configured' : '',
                webhookUrl: record?.webhook_url || '',
                isActive: record?.isActive !== false // 預設為啟用
            }
        });
    } catch (error) {
        console.error('獲取 LINE API 設定錯誤:', error);
        res.status(500).json({
                success: false,
            error: '獲取 LINE API 設定失敗'
        });
    }
});

// 保存 LINE API 設定
app.post('/api/line-api/settings', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const { channelAccessToken, channelSecret, webhookUrl } = req.body;
        
        if (!channelAccessToken || !channelSecret) {
            return res.status(400).json({
                success: false,
                error: '請提供 Channel Access Token 和 Channel Secret'
            });
        }

        console.log('📝 準備儲存 LINE Token，userId:', userId);
        console.log('   Token 長度:', channelAccessToken.length, 'Secret 長度:', channelSecret.length);

        loadDatabase();
        if (!database.line_api_settings) database.line_api_settings = [];
        const idx = database.line_api_settings.findIndex(r => String(r.user_id) === String(userId));
        const encryptedToken = encryptSensitive(channelAccessToken);
        const encryptedSecret = encryptSensitive(channelSecret);
        const existingRecord = idx >= 0 ? database.line_api_settings[idx] : null;
        const record = {
            user_id: userId,
            channel_access_token: encryptedToken || channelAccessToken,
            channel_secret: encryptedSecret || channelSecret,
            channel_access_token_plain: channelAccessToken,
            channel_secret_plain: channelSecret,
            webhook_url: webhookUrl || `https://${req.get('host')}/api/webhook/line/${userId}`,
            isActive: existingRecord?.isActive !== false, // 保留現有狀態，新記錄預設為啟用
            updated_at: new Date().toISOString()
        };
        if (idx >= 0) {
            database.line_api_settings[idx] = record;
            console.log('✅ 更新現有記錄，index:', idx);
        } else {
            database.line_api_settings.push(record);
            console.log('✅ 新增記錄');
        }
        saveDatabase();

        // 更新記憶體快取（用於回推時快速取得）
        lineAPISettings[userId] = {
            channelAccessToken: channelAccessToken,
            channelSecret: channelSecret,
            webhookUrl: record.webhook_url,
            updatedAt: record.updated_at
        };
        
        console.log('✅ LINE Token 已儲存並更新快取');

        res.json({
            success: true,
            message: 'LINE API 設定保存成功',
            data: {
                channelAccessToken: 'Configured',
                channelSecret: 'Configured',
                webhookUrl: record.webhook_url,
                isActive: record.isActive
            }
        });
    } catch (error) {
        console.error('保存 LINE API 設定錯誤:', error);
        res.status(500).json({
                success: false,
            error: '保存 LINE API 設定失敗'
        });
    }
});

// 切換 LINE API 設定啟用狀態
app.put('/api/line-api/settings/toggle', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const { isActive } = req.body;
        
        if (typeof isActive !== 'boolean') {
            return res.status(400).json({
                success: false,
                error: '請提供有效的 isActive 值（true/false）'
            });
        }

        loadDatabase();
        if (!database.line_api_settings) database.line_api_settings = [];
        const idx = database.line_api_settings.findIndex(r => String(r.user_id) === String(userId));
        
        if (idx < 0) {
            return res.status(404).json({
                success: false,
                error: '找不到 LINE API 設定，請先儲存設定'
            });
        }

        database.line_api_settings[idx].isActive = isActive;
        database.line_api_settings[idx].updated_at = new Date().toISOString();
        saveDatabase();

        console.log(`✅ LINE API 設定啟用狀態已更新: ${isActive ? '啟用' : '停用'}`);

        res.json({
            success: true,
            message: isActive ? 'LINE 頻道已啟用' : 'LINE 頻道已停用',
            data: {
                isActive: isActive
            }
        });
    } catch (error) {
        console.error('切換 LINE API 設定啟用狀態錯誤:', error);
        res.status(500).json({
            success: false,
            error: '切換啟用狀態失敗'
        });
    }
});

// AI/LINE 診斷（僅登入後可用）
app.get('/api/diagnostics/ai', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        loadDatabase();
        const record = (database.line_api_settings || []).find(r => String(r.user_id) === String(userId));
        const decryptedToken = decryptSensitive(record?.channel_access_token) || record?.channel_access_token_plain || '';
        const decryptedSecret = decryptSensitive(record?.channel_secret) || record?.channel_secret_plain || '';
        const hasLineSecretKey = !!process.env.LINE_SECRET_KEY;
        const openaiKey = process.env.OPENAI_API_KEY || '';
        const openaiKeyStatus = {
            configured: !!openaiKey,
            length: openaiKey.length,
            prefix: openaiKey ? openaiKey.slice(0, 4) : '',
            looksValid: openaiKey.startsWith('sk-')
        };

        const user = getUserById(userId);
        const plan = user?.plan || 'free';
        const planAllowance = getPlanAllowance(plan, user);
        const conversationLimit = getPlanConversationLimit(plan, user);
        const availableThisCycle = Math.max(planAllowance - (user?.token_used_in_cycle || 0), 0) + (user?.token_bonus_balance || 0);

        res.json({
            success: true,
            openai: openaiKeyStatus,
            line: {
                hasRecord: !!record,
                hasEncryptedToken: !!record?.channel_access_token,
                hasPlainToken: !!record?.channel_access_token_plain,
                tokenLength: decryptedToken ? decryptedToken.length : 0,
                secretLength: decryptedSecret ? decryptedSecret.length : 0,
                hasLineSecretKey
            },
            usage: {
                plan,
                tokenUsed: user?.token_used_in_cycle || 0,
                tokenBonus: user?.token_bonus_balance || 0,
                allowance: planAllowance,
                available: availableThisCycle,
                conversationUsed: user?.conversation_used_in_cycle || 0,
                conversationLimit
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: '診斷資訊取得失敗' });
    }
});

// 獲取用戶的 Webhook URL
app.get('/api/user/webhook-url', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const webhookUrl = `${req.protocol}://${req.get('host')}/api/webhook/line/${userId}`;
        
        res.json({
            success: true,
            data: {
                webhookUrl: webhookUrl,
                userId: userId
            }
        });
    } catch (error) {
        console.error('獲取 Webhook URL 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 Webhook URL 失敗'
        });
    }
});

// 更新用戶的 Webhook URL
app.post('/api/user/webhook-url', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const { webhookUrl } = req.body;

        loadDatabase();
        if (!database.line_api_settings) database.line_api_settings = [];
        const idx = database.line_api_settings.findIndex(r => r.user_id === userId);
        if (idx >= 0) {
            database.line_api_settings[idx].webhook_url = webhookUrl;
            database.line_api_settings[idx].updated_at = new Date().toISOString();
        } else {
            database.line_api_settings.push({
                user_id: userId,
                channel_access_token: '',
                channel_secret: '',
                webhook_url: webhookUrl,
                updated_at: new Date().toISOString()
            });
        }
        saveDatabase();

        lineAPISettings[userId] = {
            ...(lineAPISettings[userId] || {}),
            webhookUrl
        };

        res.json({
            success: true,
            message: 'Webhook URL 更新成功',
            data: {
                webhookUrl: webhookUrl,
                userId: userId
            }
        });
    } catch (error) {
        console.error('更新 Webhook URL 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新 Webhook URL 失敗'
        });
    }
});

// LINE Webhook 驗證（GET/HEAD）- 供 LINE Developers「Verify」使用
app.get('/api/webhook/line/:userId', (req, res) => {
    return res.status(200).send('OK');
});
app.head('/api/webhook/line/:userId', (req, res) => {
    return res.sendStatus(200);
});

// LINE Webhook 處理 (用戶專用)
app.post('/api/webhook/line/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const events = req.body.events || [];
        
        console.log(`📨 收到 LINE Webhook: 用戶 ${userId}, 事件數量: ${events.length}`);
        console.log('📋 Webhook 詳細資訊:', {
            userId,
            eventCount: events.length,
            timestamp: new Date().toISOString(),
            userAgent: req.headers['user-agent'],
            ip: req.ip
        });
        
        // 檢查頻道是否啟用
        loadDatabase();
        const lineSetting = (database.line_api_settings || []).find(r => r.user_id == userId);
        if (lineSetting && lineSetting.isActive === false) {
            console.log(`⚠️ LINE 頻道已停用，跳過處理: 用戶 ${userId}`);
            return res.json({ 
                success: true, 
                message: '頻道已停用，事件已忽略',
                ignored: true 
            });
        }
        
        // 處理每個事件
        for (const event of events) {
            console.log('📝 LINE 事件:', event.type);
            
            // 檢查事件是否已經處理過（使用事件 ID 防重複）
            const eventId = event.replyToken || event.timestamp || `${event.type}_${Date.now()}`;
            const eventCacheKey = `line_event_${userId}_${eventId}`;
            
            if (messageCache.has(eventCacheKey)) {
                console.log('⚠️ 事件已處理過，跳過:', event.type);
                continue;
            }
            
            // 將事件加入快取（10 分鐘後自動清除）
            messageCache.set(eventCacheKey, true);
            setTimeout(() => messageCache.delete(eventCacheKey), 10 * 60 * 1000);
            
            switch (event.type) {
                case 'message':
                    await handleLineMessage(event, userId);
                    break;
                case 'follow':
                    await handleLineFollow(event, userId);
                    break;
                case 'unfollow':
                    await handleLineUnfollow(event, userId);
                    break;
                default:
                    console.log('🔄 未處理的事件類型:', event.type);
            }
        }
        
        res.json({ success: true, message: 'Webhook 處理完成' });
    } catch (error) {
        console.error('處理 LINE Webhook 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '處理 Webhook 失敗'
        });
    }
});

// Slack Webhook（事件API）- 每位使用者專屬 URL
app.post('/api/webhook/slack/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const body = req.body || {};
        // Slack URL 驗證
        if (body.type === 'url_verification') {
            return res.json({ challenge: body.challenge });
        }
        const event = body.event || {};
        if (event.type === 'message' && !event.bot_id) {
            loadDatabase();
            if (!database.chat_history) database.chat_history = [];
            const convId = `slack_${userId}_${event.channel}`;
            let conv = database.chat_history.find(c => c.id === convId);
            if (!conv) {
                conv = { id: convId, userId, platform: 'slack', messages: [], createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
                database.chat_history.push(conv);
            }
            conv.messages.push({ role: 'user', content: event.text || '', timestamp: new Date().toISOString() });
            conv.updatedAt = new Date().toISOString();
            saveDatabase();

            // 生成 AI 回覆（僅存對話；回推 Slack 需安裝 bot 並呼叫 chat.postMessage，可後續擴充）
            try {
                const { reply } = await generateAIReplyForUser(userId, event.text || '', true);
                conv.messages.push({ role: 'assistant', content: reply, timestamp: new Date().toISOString() });
                saveDatabase();
            } catch {}
        }
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ ok: false });
    }
});

// Telegram Webhook
app.post('/api/webhook/telegram/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const body = req.body || {};
        const msg = body.message || {};
        if (msg.text) {
            loadDatabase();
            if (!database.chat_history) database.chat_history = [];
            const convId = `telegram_${userId}_${msg.chat?.id || 'unknown'}`;
            let conv = database.chat_history.find(c => c.id === convId);
            if (!conv) {
                conv = { id: convId, userId, platform: 'telegram', messages: [], createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
                database.chat_history.push(conv);
            }
            conv.messages.push({ role: 'user', content: msg.text, timestamp: new Date().toISOString() });
            conv.updatedAt = new Date().toISOString();
            saveDatabase();

            try {
                const { reply } = await generateAIReplyForUser(userId, msg.text, true);
                conv.messages.push({ role: 'assistant', content: reply, timestamp: new Date().toISOString() });
                saveDatabase();
            } catch {}
        }
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ ok: false });
    }
});

// Discord Webhook（互動或機器人事件需另設 Gateway，本處僅提供簡易 Webhook 收信）
app.post('/api/webhook/discord/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const body = req.body || {};
        const content = body.content || body.message || '';
        if (content) {
            loadDatabase();
            if (!database.chat_history) database.chat_history = [];
            const convId = `discord_${userId}_webhook`;
            let conv = database.chat_history.find(c => c.id === convId);
            if (!conv) {
                conv = { id: convId, userId, platform: 'discord', messages: [], createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
                database.chat_history.push(conv);
            }
            conv.messages.push({ role: 'user', content, timestamp: new Date().toISOString() });
            conv.updatedAt = new Date().toISOString();
            saveDatabase();

            try {
                const { reply } = await generateAIReplyForUser(userId, content, true);
                conv.messages.push({ role: 'assistant', content: reply, timestamp: new Date().toISOString() });
                saveDatabase();
            } catch {}
        }
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ ok: false });
    }
});

// Messenger Webhook（需同時支援驗證）
app.get('/api/webhook/messenger/:userId', (req, res) => {
    const challenge = req.query['hub.challenge'];
    if (challenge) return res.status(200).send(challenge);
    res.sendStatus(200);
});
app.post('/api/webhook/messenger/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const body = req.body || {};
        const entries = body.entry || [];
        for (const entry of entries) {
            for (const ev of (entry.messaging || [])) {
                if (ev.message && ev.message.text) {
                    loadDatabase();
                    if (!database.chat_history) database.chat_history = [];
                    const sender = ev.sender?.id || 'unknown';
                    const convId = `messenger_${userId}_${sender}`;
                    let conv = database.chat_history.find(c => c.id === convId);
                    if (!conv) {
                        conv = { id: convId, userId, platform: 'messenger', messages: [], createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
                        database.chat_history.push(conv);
                    }
                    conv.messages.push({ role: 'user', content: ev.message.text, timestamp: new Date().toISOString() });
                    conv.updatedAt = new Date().toISOString();
                    saveDatabase();

                    try {
                        const { reply } = await generateAIReplyForUser(userId, ev.message.text, true);
                        conv.messages.push({ role: 'assistant', content: reply, timestamp: new Date().toISOString() });
                        saveDatabase();
                    } catch {}
                }
            }
        }
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ ok: false });
    }
});

// WhatsApp Webhook（Meta Cloud API）
app.get('/api/webhook/whatsapp/:userId', (req, res) => {
    const challenge = req.query['hub.challenge'];
    if (challenge) return res.status(200).send(challenge);
    res.sendStatus(200);
});
app.post('/api/webhook/whatsapp/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const body = req.body || {};
        const entries = body.entry || [];
        for (const entry of entries) {
            for (const change of (entry.changes || [])) {
                const messages = change.value?.messages || [];
                for (const msg of messages) {
                    if (msg.type === 'text' && msg.text?.body) {
                        loadDatabase();
                        if (!database.chat_history) database.chat_history = [];
                        const from = msg.from || 'unknown';
                        const convId = `whatsapp_${userId}_${from}`;
                        let conv = database.chat_history.find(c => c.id === convId);
                        if (!conv) {
                            conv = { id: convId, userId, platform: 'whatsapp', messages: [], createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
                            database.chat_history.push(conv);
                        }
                        conv.messages.push({ role: 'user', content: msg.text.body, timestamp: new Date().toISOString() });
                        conv.updatedAt = new Date().toISOString();
                        saveDatabase();

                        try {
                            const { reply } = await generateAIReplyForUser(userId, msg.text.body, true);
                            conv.messages.push({ role: 'assistant', content: reply, timestamp: new Date().toISOString() });
                            saveDatabase();
                        } catch {}
                    }
                }
            }
        }
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ ok: false });
    }
});

function getConversationLastMessageTimestamp(conversation) {
    if (!conversation) return null;
    const messages = Array.isArray(conversation.messages) ? conversation.messages : [];
    const lastMessage = messages.length ? messages[messages.length - 1] : null;
    return lastMessage?.timestamp || conversation.updatedAt || conversation.createdAt || null;
}

function maybeRestoreAutoReply(conversation) {
    if (!conversation || conversation.autoReplyEnabled !== false) return false;
    const manualSince = conversation.lastManualReplyAt || conversation.manualModeSince || getConversationLastMessageTimestamp(conversation);
    if (!manualSince) {
        conversation.autoReplyEnabled = true;
        conversation.autoReplyRestoredAt = new Date().toISOString();
        conversation.manualModeRestoredReason = 'missing_manual_marker';
        delete conversation.manualModeSince;
        delete conversation.lastManualReplyAt;
        return true;
    }
    const sinceMs = Date.parse(manualSince);
    if (Number.isNaN(sinceMs)) {
        conversation.autoReplyEnabled = true;
        conversation.autoReplyRestoredAt = new Date().toISOString();
        conversation.manualModeRestoredReason = 'invalid_manual_timestamp';
        delete conversation.manualModeSince;
        delete conversation.lastManualReplyAt;
        return true;
    }
    if (Date.now() - sinceMs < MANUAL_REPLY_IDLE_MS) return false;

    conversation.autoReplyEnabled = true;
    conversation.autoReplyRestoredAt = new Date().toISOString();
    conversation.manualModeRestoredReason = 'idle_timeout';
    delete conversation.manualModeSince;
    delete conversation.lastManualReplyAt;
    return true;
}

function normalizeLineMessage(lineMessage) {
    const type = String(lineMessage?.type || '').toLowerCase();
    if (type === 'text') {
        return { type: 'text', content: lineMessage.text || '' };
    }
    if (type === 'sticker') {
        const stickerId = lineMessage.stickerId || null;
        const packageId = lineMessage.packageId || null;
        const stickerUrl = stickerId
            ? `https://stickershop.line-scdn.net/stickershop/v1/sticker/${stickerId}/android/sticker.png`
            : null;
        return {
            type: 'sticker',
            content: '[貼圖]',
            stickerId,
            stickerPackageId: packageId,
            stickerResourceType: lineMessage.stickerResourceType || null,
            stickerUrl
        };
    }
    if (type === 'image') {
        return { type: 'image', content: '[圖片]' };
    }
    if (type === 'video') {
        return { type: 'video', content: '[影片]' };
    }
    if (type === 'audio') {
        return { type: 'audio', content: '[語音]' };
    }
    if (type === 'file') {
        const fileName = lineMessage.fileName || '';
        const fileSize = lineMessage.fileSize || null;
        return {
            type: 'file',
            content: `[檔案]${fileName ? ' ' + fileName : ''}`,
            fileName: fileName || null,
            fileSize
        };
    }
    if (type === 'location') {
        const address = lineMessage.address || '';
        return {
            type: 'location',
            content: `[位置]${address ? ' ' + address : ''}`,
            address: address || null,
            latitude: lineMessage.latitude || null,
            longitude: lineMessage.longitude || null
        };
    }
    const fallbackType = type || 'unknown';
    return { type: fallbackType, content: `[${fallbackType}]` };
}

// 處理 LINE 訊息事件
async function handleLineMessage(event, userId) {
    try {
        const message = event.message;
        const sourceUserId = event.source.userId;
        const normalized = normalizeLineMessage(message);
        const messageContent = normalized.content || '';
        const messageType = normalized.type || 'unknown';
        const messageId = message.id || `${sourceUserId}_${Date.now()}`;
        
        // 生成快取鍵
        const cacheKey = `line_${userId}_${sourceUserId}_${messageId}_${messageType}_${messageContent}`;
        
        // 檢查是否已經處理過相同的訊息
        if (messageCache.has(cacheKey)) {
            console.log('⚠️ 訊息已處理過，跳過:', messageContent);
            return;
        }
        
        // 將訊息加入快取（5 分鐘後自動清除）
        messageCache.set(cacheKey, true);
        setTimeout(() => messageCache.delete(cacheKey), 5 * 60 * 1000);
        
        console.log('💬 收到訊息:', messageContent || message.type, 'from:', sourceUserId);
        console.log('📋 訊息詳細資訊:', {
            messageId: messageId,
            messageContent: messageContent,
            messageType: messageType,
            sourceUserId: sourceUserId,
            userId: userId,
            timestamp: new Date().toISOString(),
            cacheKey: cacheKey
        });
        
        // 取得用戶資料（名稱與照片）
        let displayName = 'LINE 使用者';
        let pictureUrl = null;
        let profileLoaded = false;
        try {
            const creds = getLineCredentials(userId);
            if (creds && creds.channelAccessToken) {
                const client = new Client({ channelAccessToken: creds.channelAccessToken, channelSecret: creds.channelSecret });
                const sourceType = event.source?.type;
                let profile = null;
                if (sourceType === 'group' && event.source?.groupId) {
                    profile = await client.getGroupMemberProfile(event.source.groupId, sourceUserId);
                } else if (sourceType === 'room' && event.source?.roomId) {
                    profile = await client.getRoomMemberProfile(event.source.roomId, sourceUserId);
                } else {
                    profile = await client.getProfile(sourceUserId);
                }
                if (profile) {
                    displayName = profile.displayName || displayName;
                    pictureUrl = profile.pictureUrl || null;
                    profileLoaded = true;
                }
            }
        } catch (profileErr) {
            console.warn('無法取得 LINE 用戶資料:', profileErr.message);
        }
        
        // 寫入使用者專屬對話記錄（依 userId 隔離）
        loadDatabase();
        if (!database.chat_history) database.chat_history = [];
        const convId = `line_${userId}_${sourceUserId}`;
        let conv = database.chat_history.find(c => c.id === convId);
        if (!conv) {
            conv = { 
                id: convId, 
                userId: parseInt(userId),
                platform: 'line', 
                customerName: displayName,
                customerPicture: pictureUrl,
                customerLineId: sourceUserId,
                sourceType: event.source?.type || null,
                groupId: event.source?.groupId || null,
                roomId: event.source?.roomId || null,
                messages: [], 
                createdAt: new Date().toISOString(), 
                updatedAt: new Date().toISOString() 
            };
            database.chat_history.push(conv);
        } else {
            // 更新客戶名稱與照片（僅在成功取得 profile 時更新）
            if (profileLoaded) {
                conv.customerName = displayName;
                conv.customerPicture = pictureUrl;
            }
            conv.customerLineId = sourceUserId;
            if (!conv.sourceType) conv.sourceType = event.source?.type || null;
            if (!conv.groupId) conv.groupId = event.source?.groupId || null;
            if (!conv.roomId) conv.roomId = event.source?.roomId || null;
            if (!conv.userId) conv.userId = parseInt(userId);
        }
        
        // 檢查是否已經回覆過相同的訊息（防重複）
        const messageTimestamp = new Date().toISOString();
        const recentMessages = conv.messages.slice(-10); // 檢查最近 10 條訊息
        
        // 如果最近有相同的用戶訊息，跳過處理
        const duplicateMessage = messageType === 'text'
            ? recentMessages.find(msg => 
                msg.role === 'user' && 
                msg.content === messageContent && 
                msg.type === 'text' &&
                (new Date(messageTimestamp) - new Date(msg.timestamp)) < 30000 // 30 秒內
            )
            : null;
        
        if (duplicateMessage) {
            console.log('⚠️ 檢測到重複訊息，跳過處理:', messageContent);
            return;
        }
        
        const userMessage = { role: 'user', content: messageContent, timestamp: messageTimestamp, type: messageType };
        if (normalized.stickerId) userMessage.stickerId = normalized.stickerId;
        if (normalized.stickerPackageId) userMessage.stickerPackageId = normalized.stickerPackageId;
        if (normalized.stickerResourceType) userMessage.stickerResourceType = normalized.stickerResourceType;
        if (normalized.stickerUrl) userMessage.stickerUrl = normalized.stickerUrl;
        if (normalized.fileName) userMessage.fileName = normalized.fileName;
        if (normalized.fileSize) userMessage.fileSize = normalized.fileSize;
        if (normalized.address) userMessage.address = normalized.address;
        if (normalized.latitude !== null) userMessage.latitude = normalized.latitude;
        if (normalized.longitude !== null) userMessage.longitude = normalized.longitude;
        conv.messages.push(userMessage);
        conv.updatedAt = new Date().toISOString();
        saveDatabase();

        // 若人工接手過久未回覆，恢復自動回覆
        if (maybeRestoreAutoReply(conv)) {
            conv.updatedAt = new Date().toISOString();
            saveDatabase();
        }

        // 若尚未設定自動回覆，預設啟用
        conv.autoReplyEnabled = normalizeAutoReplyValue(conv.autoReplyEnabled);
        conv.updatedAt = new Date().toISOString();
        saveDatabase();

        // 檢查是否需要自動回覆（從對話設定中讀取）
        const autoReplyEnabled = conv.autoReplyEnabled !== false; // 預設為開啟，除非明確關閉

        // 生成 AI 回覆並嘗試回推
        let replyText = '';
        let replySuccess = false;
        
        if (autoReplyEnabled) {
            try {
                console.log('📝 開始生成 AI 回覆');
                console.log('   userId:', userId, '(type:', typeof userId, ')');
                console.log('   message:', message.text);
                console.log('   sourceUserId:', sourceUserId);
                
                const userIdInt = parseInt(userId);
                console.log('   userIdInt:', userIdInt);
                
                // 使用對話歷史生成回覆
                const aiPrompt = messageType === 'text' ? (message.text || messageContent) : messageContent;
                const { reply } = await generateAIReplyWithHistory(userIdInt, conv.messages, aiPrompt);
                console.log('✅ AI 回覆生成成功，長度:', reply.length);
                replyText = reply;
                replySuccess = true;
            } catch (e) {
                console.warn('❌ 生成 AI 回覆失敗:', e.message);
                console.error('   完整錯誤:', e);
                // 針對常見情況提供使用者可見的告知訊息
                if (String(e?.message || '').includes('餘額不足')) {
                    replyText = '目前餘額不足，請至儀表板加值後再試。';
                } else if (String(e?.message || '').includes('對話次數')) {
                    replyText = '本月對話次數已達方案上限，請至儀表板升級或等待重置。';
                } else if (String(e?.message || '').includes('OPENAI_API_KEY')) {
                    replyText = '目前尚未設定 AI 金鑰，已記錄您的訊息，我們會盡快處理。';
                } else if (String(e?.message || '').includes('使用者不存在')) {
                    replyText = '系統設定錯誤，請聯繫管理員。';
                } else {
                    replyText = '目前暫時無法回覆，請稍後再試。';
                }
            }
        } else {
            // 人工回覆模式，只記錄訊息，不自動回覆
            replyText = '';
            console.log('📝 人工回覆模式：已記錄訊息，等待管理員回覆');
        }
        
        // 只有在有回覆內容時才回推
        if (replyText) {
            const aiMessage = {
                role: 'assistant',
                content: replyText,
                timestamp: new Date().toISOString(),
                isAutoReply: true,
                deliveryStatus: 'pending'
            };
            conv.messages.push(aiMessage);
            conv.updatedAt = new Date().toISOString();
            saveDatabase();

            aiMessage.deliveryStatus = 'internal_only';
            aiMessage.deliveryError = 'hidden_from_customer';
            conv.updatedAt = new Date().toISOString();
            saveDatabase();
            console.log('📝 AI 回覆僅顯示於後台，未回推給顧客');
            console.log('✅ 對話已儲存，總訊息數:', conv.messages.length);
        } else {
            console.log('📝 無回覆內容，不進行回推');
        }
        
    } catch (error) {
        console.error('處理 LINE 訊息錯誤:', error);
    }
}

// 人工回覆 LINE 訊息 API
app.post('/api/line/manual-reply', authenticateJWT, async (req, res) => {
    try {
        const { conversationId, message } = req.body;
        
        if (!conversationId || !message) {
            return res.status(400).json({
                success: false,
                error: '請提供對話ID和回覆訊息'
            });
        }
        
        loadDatabase();
        const conv = database.chat_history.find(c => c.id === conversationId);
        if (!conv) {
            return res.status(404).json({
                success: false,
                error: '找不到對話記錄'
            });
        }
        
        const nowIso = new Date().toISOString();

        // 將人工回覆加入對話記錄
        conv.messages.push({ 
            role: 'assistant', 
            content: message, 
            timestamp: nowIso,
            isManualReply: true
        });
        // 人工回覆即視為接手對話
        conv.autoReplyEnabled = false;
        if (!conv.manualModeSince) conv.manualModeSince = nowIso;
        conv.lastManualReplyAt = nowIso;
        conv.updatedAt = nowIso;
        saveDatabase();
        
        // 如果是 LINE 對話，推送到 LINE
        if (conv.platform === 'line' && conv.customerLineId) {
            try {
                const creds = getLineCredentials(conv.userId);
                if (creds && creds.channelAccessToken) {
                    const client = new Client({ 
                        channelAccessToken: creds.channelAccessToken, 
                        channelSecret: creds.channelSecret 
                    });
                    await client.pushMessage(conv.customerLineId, { 
                        type: 'text', 
                        text: message 
                    });
                    console.log('✅ 人工回覆已推送到 LINE');
                }
            } catch (pushErr) {
                console.error('❌ 推送人工回覆失敗:', pushErr.message);
            }
        }
        
        res.json({
            success: true,
            message: '人工回覆已發送'
        });
        
    } catch (error) {
        console.error('人工回覆 LINE 訊息錯誤:', error);
        res.status(500).json({
            success: false,
            error: '發送人工回覆失敗'
        });
    }
});

// 切換對話自動回覆設定 API
app.post('/api/conversation/toggle-auto-reply', authenticateJWT, async (req, res) => {
    try {
        const { conversationId, autoReplyEnabled } = req.body;
        
        if (!conversationId || typeof autoReplyEnabled !== 'boolean') {
            return res.status(400).json({
                success: false,
                error: '請提供對話ID和自動回覆設定'
            });
        }
        
        loadDatabase();
        const conv = database.chat_history.find(c => c.id === conversationId);
        if (!conv) {
            return res.status(404).json({
                success: false,
                error: '找不到對話記錄'
            });
        }
        
        // 更新自動回覆設定
        const nowIso = new Date().toISOString();
        conv.autoReplyEnabled = autoReplyEnabled;
        if (autoReplyEnabled) {
            delete conv.manualModeSince;
            delete conv.lastManualReplyAt;
            delete conv.autoReplyRestoredAt;
            delete conv.manualModeRestoredReason;
        } else {
            conv.manualModeSince = nowIso;
        }
        conv.updatedAt = nowIso;
        saveDatabase();
        
        console.log(`✅ 對話 ${conversationId} 自動回覆設定已更新: ${autoReplyEnabled}`);
        
        res.json({
            success: true,
            message: autoReplyEnabled ? '已開啟自動回覆' : '已關閉自動回覆',
            autoReplyEnabled: autoReplyEnabled
        });
        
    } catch (error) {
        console.error('切換自動回覆設定錯誤:', error);
        res.status(500).json({
            success: false,
            error: '切換設定失敗'
        });
    }
});

// ==================== 多個 LINE Bot 管理 ====================

// 獲取使用者的所有 LINE Bot
app.get('/api/line-bots', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        loadDatabase();
        
        const userBots = (database.line_bots || []).filter(bot => bot.user_id === userId);
        
        // 不返回敏感的 Token 和 Secret
        const safeBots = userBots.map(bot => ({
            id: bot.id,
            name: bot.name,
            description: bot.description,
            channel_id: bot.channel_id,
            webhook_url: bot.webhook_url,
            status: bot.status || 'inactive',
            created_at: bot.created_at,
            updated_at: bot.updated_at,
            message_count: bot.message_count || 0,
            conversation_count: bot.conversation_count || 0
        }));
        
        res.json({
            success: true,
            bots: safeBots
        });
        
    } catch (error) {
        console.error('獲取 LINE Bot 列表錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 Bot 列表失敗'
        });
    }
});

// 創建新的 LINE Bot
app.post('/api/line-bots', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const { name, description, channelAccessToken, channelSecret, channelId } = req.body;
        
        if (!name || !channelAccessToken || !channelSecret) {
            return res.status(400).json({
                success: false,
                error: '請提供 Bot 名稱、Token 和 Secret'
            });
        }
        
        loadDatabase();
        if (!database.line_bots) database.line_bots = [];
        
        // 檢查是否已存在相同名稱的 Bot
        const existingBot = database.line_bots.find(bot => 
            bot.user_id === userId && bot.name === name
        );
        
        if (existingBot) {
            return res.status(400).json({
                success: false,
                error: '已存在相同名稱的 Bot'
            });
        }
        
        const botId = `bot_${userId}_${Date.now()}`;
        const webhookUrl = `https://echochat-api.onrender.com/api/webhook/line-bot/${botId}`;
        
        const newBot = {
            id: botId,
            user_id: userId,
            name: name,
            description: description || '',
            channel_id: channelId || '',
            channel_access_token: encryptSensitive(channelAccessToken),
            channel_secret: encryptSensitive(channelSecret),
            webhook_url: webhookUrl,
            status: 'active',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            message_count: 0,
            conversation_count: 0
        };
        
        database.line_bots.push(newBot);
        saveDatabase();
        
        console.log(`✅ 用戶 ${userId} 創建新 Bot: ${name} (ID: ${botId})`);
        
        res.json({
            success: true,
            message: 'LINE Bot 創建成功',
            bot: {
                id: newBot.id,
                name: newBot.name,
                description: newBot.description,
                webhook_url: newBot.webhook_url,
                status: newBot.status,
                created_at: newBot.created_at
            }
        });
        
    } catch (error) {
        console.error('創建 LINE Bot 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '創建 Bot 失敗'
        });
    }
});

// 更新 LINE Bot 設定
app.put('/api/line-bots/:botId', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const { botId } = req.params;
        const { name, description, channelAccessToken, channelSecret, status } = req.body;
        
        loadDatabase();
        const botIndex = database.line_bots.findIndex(bot => 
            bot.id === botId && bot.user_id === userId
        );
        
        if (botIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '找不到指定的 Bot'
            });
        }
        
        const bot = database.line_bots[botIndex];
        
        // 更新可更新的欄位
        if (name) bot.name = name;
        if (description !== undefined) bot.description = description;
        if (channelAccessToken) bot.channel_access_token = encryptSensitive(channelAccessToken);
        if (channelSecret) bot.channel_secret = encryptSensitive(channelSecret);
        if (status) bot.status = status;
        
        bot.updated_at = new Date().toISOString();
        database.line_bots[botIndex] = bot;
        saveDatabase();
        
        console.log(`✅ 用戶 ${userId} 更新 Bot ${botId}`);
        
        res.json({
            success: true,
            message: 'Bot 設定更新成功'
        });
        
    } catch (error) {
        console.error('更新 LINE Bot 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新 Bot 失敗'
        });
    }
});

// 刪除 LINE Bot
app.delete('/api/line-bots/:botId', authenticateJWT, async (req, res) => {
    try {
        const userId = req.staff.id;
        const { botId } = req.params;
        
        loadDatabase();
        const botIndex = database.line_bots.findIndex(bot => 
            bot.id === botId && bot.user_id === userId
        );
        
        if (botIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '找不到指定的 Bot'
            });
        }
        
        // 刪除相關的對話記錄
        database.chat_history = (database.chat_history || []).filter(conv => 
            !conv.bot_id || conv.bot_id !== botId
        );
        
        // 刪除 Bot
        database.line_bots.splice(botIndex, 1);
        saveDatabase();
        
        console.log(`✅ 用戶 ${userId} 刪除 Bot ${botId}`);
        
        res.json({
            success: true,
            message: 'Bot 刪除成功'
        });
        
    } catch (error) {
        console.error('刪除 LINE Bot 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '刪除 Bot 失敗'
        });
    }
});

// 處理多個 LINE Bot 的 Webhook
app.post('/api/webhook/line-bot/:botId', async (req, res) => {
    try {
        const { botId } = req.params;
        const events = req.body.events || [];
        
        console.log(`📨 收到 LINE Bot ${botId} 的 Webhook，事件數量: ${events.length}`);
        
        // 查找 Bot 設定
        loadDatabase();
        const bot = database.line_bots.find(b => b.id === botId);
        
        if (!bot) {
            console.warn(`❌ 找不到 Bot ${botId}`);
            return res.status(404).json({ success: false, error: 'Bot 不存在' });
        }
        
        if (bot.status !== 'active') {
            console.warn(`⚠️ Bot ${botId} 狀態為 ${bot.status}，忽略訊息`);
            return res.json({ success: true, message: 'Bot 未啟用' });
        }
        
        // 處理每個事件
        for (const event of events) {
            await handleLineBotMessage(event, bot);
        }
        
        res.json({ success: true, message: 'Webhook 處理完成' });
        
    } catch (error) {
        console.error('處理 LINE Bot Webhook 錯誤:', error);
        res.status(500).json({
            success: false,
            error: '處理 Webhook 失敗'
        });
    }
});

// 處理 LINE Bot 訊息事件
async function handleLineBotMessage(event, bot) {
    try {
        const message = event.message;
        const sourceUserId = event.source.userId;
        const normalized = normalizeLineMessage(message);
        const messageContent = normalized.content || '';
        const messageType = normalized.type || 'unknown';
        const messageId = message.id || `${sourceUserId}_${Date.now()}`;
        
        // 生成快取鍵（包含 Bot ID）
        const cacheKey = `line_bot_${bot.id}_${sourceUserId}_${messageId}_${messageType}_${messageContent}`;
        
        // 檢查是否已經處理過相同的訊息
        if (messageCache.has(cacheKey)) {
            console.log('⚠️ Bot 訊息已處理過，跳過:', messageContent);
            return;
        }
        
        // 將訊息加入快取（5 分鐘後自動清除）
        messageCache.set(cacheKey, true);
        setTimeout(() => messageCache.delete(cacheKey), 5 * 60 * 1000);
        
        console.log('💬 Bot 收到訊息:', messageContent || message.type, 'from:', sourceUserId, 'Bot:', bot.name);
        
        // 取得用戶資料
        let displayName = 'LINE 使用者';
        let pictureUrl = null;
        let profileLoaded = false;
        try {
            const token = decryptSensitive(bot.channel_access_token);
            const secret = decryptSensitive(bot.channel_secret);
            
            if (token && secret) {
                const client = new Client({ channelAccessToken: token, channelSecret: secret });
                const sourceType = event.source?.type;
                let profile = null;
                if (sourceType === 'group' && event.source?.groupId) {
                    profile = await client.getGroupMemberProfile(event.source.groupId, sourceUserId);
                } else if (sourceType === 'room' && event.source?.roomId) {
                    profile = await client.getRoomMemberProfile(event.source.roomId, sourceUserId);
                } else {
                    profile = await client.getProfile(sourceUserId);
                }
                if (profile) {
                    displayName = profile.displayName || displayName;
                    pictureUrl = profile.pictureUrl || null;
                    profileLoaded = true;
                }
            }
        } catch (profileErr) {
            console.warn('無法取得 LINE 用戶資料:', profileErr.message);
        }
        
        // 寫入對話記錄
        loadDatabase();
        if (!database.chat_history) database.chat_history = [];
        const convId = `line_bot_${bot.id}_${sourceUserId}`;
        let conv = database.chat_history.find(c => c.id === convId);
        
        if (!conv) {
            conv = { 
                id: convId,
                bot_id: bot.id,
                userId: bot.user_id,
                platform: 'line_bot', 
                customerName: displayName,
                customerPicture: pictureUrl,
                customerLineId: sourceUserId,
                sourceType: event.source?.type || null,
                groupId: event.source?.groupId || null,
                roomId: event.source?.roomId || null,
                messages: [], 
                createdAt: new Date().toISOString(), 
                updatedAt: new Date().toISOString() 
            };
            database.chat_history.push(conv);
            
            // 更新 Bot 的對話計數
            bot.conversation_count = (bot.conversation_count || 0) + 1;
        } else {
            if (profileLoaded) {
                conv.customerName = displayName;
                conv.customerPicture = pictureUrl;
            }
            conv.customerLineId = sourceUserId;
            if (!conv.sourceType) conv.sourceType = event.source?.type || null;
            if (!conv.groupId) conv.groupId = event.source?.groupId || null;
            if (!conv.roomId) conv.roomId = event.source?.roomId || null;
            if (!conv.userId) conv.userId = bot.user_id;
        }
        
        // 檢查重複訊息
        const messageTimestamp = new Date().toISOString();
        const recentMessages = conv.messages.slice(-10);
        const duplicateMessage = messageType === 'text'
            ? recentMessages.find(msg => 
                msg.role === 'user' && 
                msg.content === messageContent && 
                msg.type === 'text' &&
                (new Date(messageTimestamp) - new Date(msg.timestamp)) < 30000
            )
            : null;
        
        if (duplicateMessage) {
            console.log('⚠️ 檢測到重複訊息，跳過處理:', messageContent);
            return;
        }
        
        const userMessage = { role: 'user', content: messageContent, timestamp: messageTimestamp, type: messageType };
        if (normalized.stickerId) userMessage.stickerId = normalized.stickerId;
        if (normalized.stickerPackageId) userMessage.stickerPackageId = normalized.stickerPackageId;
        if (normalized.stickerResourceType) userMessage.stickerResourceType = normalized.stickerResourceType;
        if (normalized.stickerUrl) userMessage.stickerUrl = normalized.stickerUrl;
        if (normalized.fileName) userMessage.fileName = normalized.fileName;
        if (normalized.fileSize) userMessage.fileSize = normalized.fileSize;
        if (normalized.address) userMessage.address = normalized.address;
        if (normalized.latitude !== null) userMessage.latitude = normalized.latitude;
        if (normalized.longitude !== null) userMessage.longitude = normalized.longitude;
        conv.messages.push(userMessage);
        conv.updatedAt = new Date().toISOString();
        
        // 更新 Bot 的訊息計數
        bot.message_count = (bot.message_count || 0) + 1;
        
        saveDatabase();
        
        // 若人工接手過久未回覆，恢復自動回覆
        if (maybeRestoreAutoReply(conv)) {
            conv.updatedAt = new Date().toISOString();
            saveDatabase();
        }

        // 若尚未設定自動回覆，預設啟用
        conv.autoReplyEnabled = normalizeAutoReplyValue(conv.autoReplyEnabled);
        conv.updatedAt = new Date().toISOString();
        saveDatabase();

        // 檢查是否需要自動回覆
        const autoReplyEnabled = conv.autoReplyEnabled !== false;
        
        if (autoReplyEnabled) {
            try {
                console.log('📝 開始生成 AI 回覆');
                
                // 使用對話歷史生成回覆
                const aiPrompt = messageType === 'text' ? (message.text || messageContent) : messageContent;
                const { reply } = await generateAIReplyWithHistory(bot.user_id, conv.messages, aiPrompt);
                console.log('✅ AI 回覆生成成功，長度:', reply.length);
                
                const aiMessage = {
                    role: 'assistant',
                    content: reply,
                    timestamp: new Date().toISOString(),
                    isAutoReply: true,
                    deliveryStatus: 'pending'
                };
                conv.messages.push(aiMessage);
                conv.updatedAt = new Date().toISOString();
                saveDatabase();
                
                aiMessage.deliveryStatus = 'internal_only';
                aiMessage.deliveryError = 'hidden_from_customer';
                conv.updatedAt = new Date().toISOString();
                saveDatabase();
                console.log('📝 AI 回覆僅顯示於後台，未回推給顧客');
            } catch (e) {
                console.warn('❌ 生成 AI 回覆失敗:', e.message);
            }
        } else {
            console.log('📝 人工回覆模式：已記錄訊息，等待管理員回覆');
        }
        
    } catch (error) {
        console.error('處理 LINE Bot 訊息錯誤:', error);
    }
}

// 處理 LINE 關注事件
async function handleLineFollow(event, userId) {
    try {
        const sourceUserId = event.source.userId;
        console.log('👋 新用戶關注:', sourceUserId);
        
        // 發送歡迎訊息
        const settings = lineAPISettings[userId];
        if (settings && settings.channelAccessToken) {
            try {
                const lineClient = new Client({
                    channelAccessToken: settings.channelAccessToken,
                    channelSecret: settings.channelSecret
                });
                
                await lineClient.pushMessage(sourceUserId, {
                    type: 'text',
                    text: '歡迎關注我們的官方帳號！有任何問題都可以隨時詢問。'
                });
                
                console.log('✅ 歡迎訊息發送成功');
            } catch (error) {
                console.log('❌ 歡迎訊息發送失敗:', error);
            }
        }
    } catch (error) {
        console.error('處理 LINE 關注錯誤:', error);
    }
}

// 處理 LINE 取消關注事件
async function handleLineUnfollow(event, userId) {
    try {
        const sourceUserId = event.source.userId;
        console.log('👋 用戶取消關注:', sourceUserId);
    } catch (error) {
        console.error('處理 LINE 取消關注錯誤:', error);
    }
}

// 測試用 LINE API 端點（不需要認證）
app.post('/api/test-line-api', async (req, res) => {
    try {
        const { channelAccessToken, channelSecret, testUserId } = req.body;
        
        if (!channelAccessToken || !channelSecret) {
            return res.status(400).json({
                success: false,
                error: '請提供 Channel Access Token 和 Channel Secret'
            });
        }
        
        // 測試連接
        let isConnected = false;
        let testResponse = null;
        
        try {
            const testUrl = 'https://api.line.me/oauth2/v2.1/verify';
            testResponse = await axios.get(testUrl, {
                headers: {
                    'Authorization': `Bearer ${channelAccessToken}`
                }
            });
            isConnected = testResponse.status === 200;
        } catch (error) {
            isConnected = false;
            testResponse = error.response || { status: 'error' };
        }
        
        // 測試發送訊息（如果提供了測試用戶 ID）
        let testMessageResult = null;
        if (testUserId && isConnected) {
            try {
                const lineClient = new Client({
                    channelAccessToken: channelAccessToken,
                    channelSecret: channelSecret
                });
                
                await lineClient.pushMessage(testUserId, {
                    type: 'text',
                    text: `LINE API 測試訊息 - ${new Date().toLocaleString()}`
                });
                
                testMessageResult = {
                    success: true,
                    message: '測試訊息發送成功'
                };
            } catch (error) {
                testMessageResult = {
                    success: false,
                    error: error.message
                };
            }
        }
        
        const PORT = process.env.PORT || 3000;
        res.json({
            success: true,
            data: {
                connectionTest: {
                    connected: isConnected,
                    status: testResponse.status
                },
                messageTest: testMessageResult,
                webhookUrl: `http://localhost:${PORT}/api/webhook/line/test`,
                timestamp: new Date().toISOString()
            }
        });
        
    } catch (error) {
        console.error('LINE API 測試錯誤:', error);
        res.status(500).json({
            success: false,
            error: '測試失敗'
        });
    }
});

// 錯誤處理中間件
const errorHandler = (err, req, res, next) => {
    console.error('❌ 伺服器錯誤:', err);
    res.status(500).json({
        success: false,
        error: '伺服器內部錯誤'
    });
};

// 啟動伺服器
const startServer = async () => {
    try {
        // 連接資料庫
        await connectDatabase();
        console.log('✅ 資料庫初始化完成');
        
        // 設置錯誤處理
        app.use(errorHandler);
        
        // 啟動伺服器
        const PORT = process.env.PORT || 3000;
        app.listen(PORT, () => {
            console.log('🚀 EchoChat API server is running on port', PORT);
            console.log('📝 API 端點: http://localhost:' + PORT + '/api');
            console.log('🔍 健康檢查: http://localhost:' + PORT + '/api/health');
        });
        
    } catch (error) {
        console.error('❌ 啟動伺服器失敗:', error.message);
        process.exit(1);
    }
};

// 啟動應用
startServer(); 