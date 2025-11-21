const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const nodemailer = require('nodemailer');
const fs = require('fs').promises;
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'echochat-secret-key-2025';
const SESSION_TIMEOUT_MINUTES = Math.max(parseInt(process.env.SESSION_TIMEOUT_MINUTES || '5', 10) || 5, 1);
const JWT_EXPIRES_IN = `${SESSION_TIMEOUT_MINUTES}m`;

// 資料檔案路徑
const DATA_FILE = path.join(__dirname, 'data', 'users.json');
const VERIFICATION_FILE = path.join(__dirname, 'data', 'verification.json');
const AI_CONFIG_FILE = path.join(__dirname, 'data', 'ai-config.json');

// 確保資料目錄存在
const ensureDataDir = async () => {
    const dataDir = path.dirname(DATA_FILE);
    try {
        await fs.access(dataDir);
    } catch {
        await fs.mkdir(dataDir, { recursive: true });
    }
};

// 載入用戶資料
const loadUsers = async () => {
    try {
        await ensureDataDir();
        const data = await fs.readFile(DATA_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.log('📁 創建新的用戶資料檔案');
        return [];
    }
};

// 保存用戶資料
const saveUsers = async (users) => {
    try {
        await ensureDataDir();
        await fs.writeFile(DATA_FILE, JSON.stringify(users, null, 2));
        console.log('✅ 用戶資料已保存');
    } catch (error) {
        console.error('❌ 保存用戶資料失敗:', error);
    }
};

// 載入驗證碼資料
const loadVerificationCodes = async () => {
    try {
        await ensureDataDir();
        const data = await fs.readFile(VERIFICATION_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.log('📁 創建新的驗證碼資料檔案');
        return [];
    }
};

// 保存驗證碼資料
const saveVerificationCodes = async (codes) => {
    try {
        await ensureDataDir();
        await fs.writeFile(VERIFICATION_FILE, JSON.stringify(codes, null, 2));
    } catch (error) {
        console.error('❌ 保存驗證碼資料失敗:', error);
    }
};

// 載入 AI 助理配置
const loadAIConfig = async () => {
    try {
        await ensureDataDir();
        const data = await fs.readFile(AI_CONFIG_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.log('📁 創建新的 AI 配置檔案');
        return {};
    }
};

// 保存 AI 助理配置
const saveAIConfig = async (config) => {
    try {
        await ensureDataDir();
        await fs.writeFile(AI_CONFIG_FILE, JSON.stringify(config, null, 2));
        console.log('✅ AI 配置已保存');
    } catch (error) {
        console.error('❌ 保存 AI 配置失敗:', error);
    }
};

// 初始化資料
let users = [];
let verificationCodes = [];
let aiConfigs = {};

// 初始化資料存儲
const initializeData = async () => {
    users = await loadUsers();
    verificationCodes = await loadVerificationCodes();
    aiConfigs = await loadAIConfig();
    console.log(`📊 已載入 ${users.length} 個用戶、${verificationCodes.length} 個驗證碼和 ${Object.keys(aiConfigs).length} 個 AI 配置`);
};

// 在伺服器啟動時初始化資料
initializeData();

// 中間件
app.use(cors({
    origin: '*',
    credentials: true
}));
app.use(express.json());

// 測試模式標誌
const TEST_MODE = process.env.TEST_MODE === 'true' || false;

// JWT 認證中間件
const authenticateJWT = (req, res, next) => {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
        return res.status(401).json({
            success: false,
            error: '缺少認證標頭'
        });
    }
    
    const token = authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({
            success: false,
            error: '無效的認證令牌'
        });
    }
    
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(401).json({
            success: false,
            error: '無效的認證令牌'
        });
    }
};

// 電子郵件配置
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER || 'echochatsup@gmail.com',
        pass: process.env.EMAIL_PASS || 'skoh eqrm behq twmt'
    },
    tls: {
        rejectUnauthorized: false
    }
});

// 驗證電子郵件配置
const verifyEmailConfig = async () => {
    try {
        await transporter.verify();
        console.log('✅ 電子郵件配置驗證成功');
        return true;
    } catch (error) {
        console.error('❌ 電子郵件配置驗證失敗:', error);
        return false;
    }
};

// 在伺服器啟動時驗證電子郵件配置
verifyEmailConfig();

// 生成驗證碼
const generateVerificationCode = () => {
    return Math.floor(100000 + Math.random() * 900000).toString();
};

// 發送驗證碼
const sendVerificationEmail = async (email, code) => {
    const mailOptions = {
        from: process.env.EMAIL_USER || 'echochatsup@gmail.com',
        to: email,
        subject: 'EchoChat - 電子郵件驗證碼',
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #667eea;">EchoChat 電子郵件驗證</h2>
                <p>您的驗證碼是：</p>
                <div style="background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; color: #667eea; border-radius: 8px; margin: 20px 0;">
                    ${code}
                </div>
                <p>此驗證碼將在10分鐘後過期。</p>
                <p style="color: #666; font-size: 12px; margin-top: 20px;">
                    如果您沒有請求此驗證碼，請忽略此郵件。
                </p>
            </div>
        `,
        text: `EchoChat 驗證碼: ${code}\n\n此驗證碼將在10分鐘後過期。`
    };
    
    try {
        console.log(`📧 嘗試發送驗證碼到: ${email}`);
        const result = await transporter.sendMail(mailOptions);
        console.log(`✅ 郵件發送成功: ${result.messageId}`);
        return result;
    } catch (error) {
        console.error(`❌ 郵件發送失敗: ${error.message}`);
        throw error;
    }
};

// 健康檢查端點
app.get('/api/health', (req, res) => {
    res.json({
        success: true,
        message: 'EchoChat API 伺服器運行正常',
        timestamp: new Date().toISOString()
    });
});

// 電子郵件配置測試端點
app.get('/api/test-email', async (req, res) => {
    try {
        const isConfigValid = await verifyEmailConfig();
        res.json({
            success: isConfigValid,
            message: isConfigValid ? '電子郵件配置正常' : '電子郵件配置有問題',
            emailUser: process.env.EMAIL_USER || 'echochatsup@gmail.com',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: '電子郵件配置測試失敗',
            details: error.message
        });
    }
});

// 資料庫狀態檢查端點
app.get('/api/database-status', (req, res) => {
    try {
        res.json({
            success: true,
            message: '資料庫狀態檢查',
            totalUsers: users.length,
            totalVerificationCodes: verificationCodes.length,
            totalAIConfigs: Object.keys(aiConfigs).length,
            users: users.map(u => ({
                id: u.id,
                email: u.email,
                username: u.username,
                createdAt: u.createdAt
            })),
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: '資料庫狀態檢查失敗',
            details: error.message
        });
    }
});

// AI 助理配置端點
app.get('/api/ai-assistant-config', authenticateJWT, (req, res) => {
    try {
        const userId = req.user.id;
        const userConfig = aiConfigs[userId] || getDefaultAIConfig();
        
        res.json({
            success: true,
            config: userConfig,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('獲取 AI 配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 AI 配置失敗'
        });
    }
});

// 更新 AI 助理配置
app.post('/api/ai-assistant-config', authenticateJWT, (req, res) => {
    try {
        const userId = req.user.id;
        const config = req.body;
        
        // 驗證配置資料
        if (!config || typeof config !== 'object') {
            return res.status(400).json({
                success: false,
                error: '無效的配置資料'
            });
        }
        
        // 保存用戶配置
        aiConfigs[userId] = {
            ...getDefaultAIConfig(),
            ...config,
            updatedAt: new Date().toISOString()
        };
        
        saveAIConfig(aiConfigs);
        
        console.log('✅ AI 配置已更新:', userId);
        
        res.json({
            success: true,
            message: 'AI 配置已更新',
            config: aiConfigs[userId],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('更新 AI 配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新 AI 配置失敗'
        });
    }
});

// 重設 AI 助理配置
app.post('/api/ai-assistant-config/reset', authenticateJWT, (req, res) => {
    try {
        const userId = req.user.id;
        
        // 重設為預設配置
        aiConfigs[userId] = getDefaultAIConfig();
        
        saveAIConfig(aiConfigs);
        
        console.log('✅ AI 配置已重設:', userId);
        
        res.json({
            success: true,
            message: 'AI 配置已重設為預設值',
            config: aiConfigs[userId],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('重設 AI 配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '重設 AI 配置失敗'
        });
    }
});

// 獲取預設 AI 配置
function getDefaultAIConfig() {
    return {
        aiServiceEnabled: true,
        selectedAIModel: "客服專家",
        maxTokens: 1000,
        temperature: 0.7,
        systemPrompt: "你是一個專業的客服代表，請用友善、專業的態度回答客戶問題。",
        aiName: "EchoChat 助理",
        aiPersonality: "友善、專業、耐心",
        aiSpecialties: "產品諮詢、技術支援、訂單處理",
        aiResponseStyle: "正式",
        aiLanguage: "繁體中文",
        aiAvatar: "robot",
        maxContextLength: 10,
        enableResponseFiltering: true,
        enableSentimentAnalysis: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
    };
}

// 發送驗證碼
app.post('/api/send-verification-code', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件地址'
            });
        }
        
        // 檢查電子郵件是否已存在
        const existingUser = users.find(user => user.email === email);
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: '此電子郵件已被註冊'
            });
        }
        
        // 生成驗證碼
        const code = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10分鐘後過期
        
        // 儲存驗證碼
        verificationCodes = verificationCodes.filter(v => v.email !== email);
        verificationCodes.push({
            email: email,
            code: code,
            expiresAt: expiresAt.toISOString()
        });
        
        // 發送電子郵件
        try {
            if (TEST_MODE) {
                console.log('🧪 測試模式：跳過實際郵件發送');
                console.log(`📧 模擬驗證碼: ${code} (發送到 ${email})`);
                
                res.json({
                    success: true,
                    message: `測試模式：驗證碼 ${code} 已生成（未實際發送郵件）`,
                    email: email,
                    code: code, // 在測試模式下返回驗證碼
                    testMode: true,
                    timestamp: new Date().toISOString()
                });
            } else {
                await sendVerificationEmail(email, code);
                console.log('✅ 驗證碼已發送到:', email);
                
                res.json({
                    success: true,
                    message: '驗證碼已發送到您的電子郵件',
                    email: email,
                    timestamp: new Date().toISOString()
                });
            }
        } catch (error) {
            console.error('❌ 發送郵件失敗:', error);
            
            // 如果郵件發送失敗，提供測試模式選項
            if (!TEST_MODE) {
                console.log('🔄 切換到測試模式以繼續測試');
                console.log(`📧 模擬驗證碼: ${code} (發送到 ${email})`);
                
                res.json({
                    success: true,
                    message: `郵件發送失敗，但驗證碼 ${code} 已生成（測試模式）`,
                    email: email,
                    code: code,
                    testMode: true,
                    fallback: true,
                    timestamp: new Date().toISOString()
                });
            } else {
                // 提供更詳細的錯誤訊息
                let errorMessage = '發送驗證碼失敗';
                if (error.code === 'EAUTH') {
                    errorMessage = '電子郵件認證失敗，請檢查伺服器配置';
                } else if (error.code === 'ECONNECTION') {
                    errorMessage = '無法連接到郵件伺服器';
                } else if (error.code === 'ETIMEDOUT') {
                    errorMessage = '郵件發送超時';
                }
                
                res.status(500).json({
                    success: false,
                    error: errorMessage,
                    details: error.message
                });
            }
        }
    } catch (error) {
        console.error('發送驗證碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '伺服器錯誤'
        });
    }
});

// 驗證碼驗證
app.post('/api/verify-code', async (req, res) => {
    try {
        const { email, code } = req.body;
        
        if (!email || !code) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件和驗證碼'
            });
        }
        
        const verification = verificationCodes.find(v => v.email === email);
        
        if (!verification) {
            return res.status(400).json({
                success: false,
                error: '驗證碼不存在'
            });
        }
        
        if (verification.code !== code) {
            return res.status(400).json({
                success: false,
                error: '驗證碼錯誤'
            });
        }
        
        if (new Date() > new Date(verification.expiresAt)) {
            return res.status(400).json({
                success: false,
                error: '驗證碼已過期'
            });
        }
        
        // 移除已使用的驗證碼
        verificationCodes = verificationCodes.filter(v => v.email !== email);
        
        res.json({
            success: true,
            message: '驗證碼驗證成功'
        });
    } catch (error) {
        console.error('驗證碼驗證錯誤:', error);
        res.status(500).json({
            success: false,
            error: '伺服器錯誤'
        });
    }
});

// 註冊
app.post('/api/register', async (req, res) => {
    try {
        const { username, email, password } = req.body;
        
        if (!username || !email || !password) {
            return res.status(400).json({
                success: false,
                error: '請提供所有必要資訊'
            });
        }
        
        // 檢查用戶是否已存在
        const existingUser = users.find(user => user.email === email || user.username === username);
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: '用戶已存在'
            });
        }
        
        // 創建新用戶
        const hashedPassword = await bcrypt.hash(password, 10);
        const newUser = {
            id: uuidv4(),
            username: username,
            email: email,
            password: hashedPassword,
            name: username,
            role: 'user',
            createdAt: new Date().toISOString()
        };
        
        users.push(newUser);
        await saveUsers(users); // 保存用戶資料
        
        // 生成 JWT Token
        const token = jwt.sign(
            { 
                id: newUser.id, 
                username: newUser.username, 
                name: newUser.name, 
                role: newUser.role 
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );
        
        res.json({
            success: true,
            token: token,
            user: {
                id: newUser.id,
                username: newUser.username,
                name: newUser.name,
                role: newUser.role
            }
        });
    } catch (error) {
        console.error('註冊錯誤:', error);
        res.status(500).json({
            success: false,
            error: '註冊失敗'
        });
    }
});

// 登入
app.post('/api/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({
                success: false,
                error: '請提供用戶名和密碼'
            });
        }
        
        const user = users.find(u => u.username === username || u.email === username);
        
        if (!user) {
            return res.status(401).json({
                success: false,
                error: '用戶名或密碼錯誤'
            });
        }
        
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            return res.status(401).json({
                success: false,
                error: '用戶名或密碼錯誤'
            });
        }
        
        // 生成 JWT Token
        const token = jwt.sign(
            { 
                id: user.id, 
                username: user.username, 
                name: user.name, 
                role: user.role 
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );
        
        res.json({
            success: true,
            token: token,
            user: {
                id: user.id,
                username: user.username,
                name: user.name,
                role: user.role
            }
        });
    } catch (error) {
        console.error('登入錯誤:', error);
        res.status(500).json({
            success: false,
            error: '登入失敗'
        });
    }
});

// Google 登入
app.post('/api/google-login', async (req, res) => {
    try {
        const { idToken, email, name } = req.body;
        
        if (!idToken || !email) {
            return res.status(400).json({
                success: false,
                error: '請提供 Google ID Token 和電子郵件'
            });
        }
        
        // 檢查用戶是否已存在
        let user = users.find(u => u.email === email);
        
        if (!user) {
            // 如果用戶不存在，創建新用戶
            const newUser = {
                id: uuidv4(),
                username: email,
                email: email,
                name: name || email.split('@')[0],
                password: await bcrypt.hash(idToken, 10), // 使用 ID Token 作為密碼
                role: 'user',
                createdAt: new Date().toISOString()
            };
            
            users.push(newUser);
            await saveUsers(users); // 保存用戶資料
            user = newUser;
            
            console.log('✅ 新 Google 用戶已創建:', email);
        }
        
        // 生成 JWT Token
        const token = jwt.sign(
            { 
                id: user.id, 
                username: user.username, 
                name: user.name, 
                role: user.role 
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );
        
        res.json({
            success: true,
            token: token,
            user: {
                id: user.id,
                username: user.username,
                name: user.name,
                role: user.role
            }
        });
    } catch (error) {
        console.error('Google 登入錯誤:', error);
        res.status(500).json({
            success: false,
            error: 'Google 登入失敗'
        });
    }
});

// 忘記密碼 - 發送驗證碼
app.post('/api/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件地址'
            });
        }
        
        // 檢查用戶是否存在
        const user = users.find(u => u.email === email);
        if (!user) {
            return res.status(400).json({
                success: false,
                error: '此電子郵件未註冊'
            });
        }
        
        // 生成驗證碼
        const code = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10分鐘後過期
        
        // 儲存驗證碼
        verificationCodes = verificationCodes.filter(v => v.email !== email);
        verificationCodes.push({
            email: email,
            code: code,
            expiresAt: expiresAt.toISOString(),
            type: 'password_reset'
        });
        
        await saveVerificationCodes(verificationCodes);
        
        // 發送電子郵件
        try {
            const mailOptions = {
                from: process.env.EMAIL_USER || 'echochatsup@gmail.com',
                to: email,
                subject: 'EchoChat - 密碼重設驗證碼',
                html: `
                    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                        <h2 style="color: #667eea;">EchoChat 密碼重設</h2>
                        <p>您的密碼重設驗證碼是：</p>
                        <div style="background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; color: #667eea; border-radius: 8px; margin: 20px 0;">
                            ${code}
                        </div>
                        <p>此驗證碼將在10分鐘後過期。</p>
                        <p style="color: #666; font-size: 12px; margin-top: 20px;">
                            如果您沒有請求密碼重設，請忽略此郵件。
                        </p>
                    </div>
                `
            };
            
            await transporter.sendMail(mailOptions);
            console.log('✅ 密碼重設驗證碼已發送到:', email);
            
            res.json({
                success: true,
                message: '密碼重設驗證碼已發送到您的電子郵件'
            });
        } catch (error) {
            console.error('❌ 發送密碼重設郵件失敗:', error);
            res.status(500).json({
                success: false,
                error: '發送驗證碼失敗'
            });
        }
    } catch (error) {
        console.error('忘記密碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '伺服器錯誤'
        });
    }
});

// 重設密碼
app.post('/api/reset-password', async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;
        
        if (!email || !code || !newPassword) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件、驗證碼和新密碼'
            });
        }
        
        // 驗證驗證碼
        const verification = verificationCodes.find(v => 
            v.email === email && 
            v.code === code && 
            v.type === 'password_reset'
        );
        
        if (!verification) {
            return res.status(400).json({
                success: false,
                error: '驗證碼錯誤或不存在'
            });
        }
        
        if (new Date() > new Date(verification.expiresAt)) {
            return res.status(400).json({
                success: false,
                error: '驗證碼已過期'
            });
        }
        
        // 更新用戶密碼
        const userIndex = users.findIndex(u => u.email === email);
        if (userIndex === -1) {
            return res.status(400).json({
                success: false,
                error: '用戶不存在'
            });
        }
        
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        users[userIndex].password = hashedPassword;
        
        // 移除已使用的驗證碼
        verificationCodes = verificationCodes.filter(v => 
            !(v.email === email && v.type === 'password_reset')
        );
        
        await saveUsers(users);
        await saveVerificationCodes(verificationCodes);
        
        console.log('✅ 密碼重設成功:', email);
        
        res.json({
            success: true,
            message: '密碼重設成功'
        });
    } catch (error) {
        console.error('重設密碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '伺服器錯誤'
        });
    }
});

// 啟動伺服器
app.listen(PORT, () => {
    console.log(`🚀 EchoChat API 伺服器運行在端口 ${PORT}`);
    console.log(`📧 郵件服務: ${process.env.EMAIL_USER || 'echochatsup@gmail.com'}`);
    console.log(`💾 資料持久化: 已啟用`);
}); 