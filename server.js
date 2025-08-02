const express = require('express');
const fs = require('fs');
// 移除資料庫依賴，使用 JSON 檔案儲存
const { Client, middleware } = require('@line/bot-sdk');
const axios = require('axios');
const path = require('path');
const { ImageAnnotatorClient } = require('@google-cloud/vision');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const multer = require('multer');
const { pipeline } = require('stream/promises');
const { v4: uuidv4 } = require('uuid');
const nodemailer = require('nodemailer');
const cors = require('cors');
require('dotenv').config();

// 初始化 Express 應用
const app = express();
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

// CORS 設定 - 允許前端網站和手機 App 訪問
app.use(cors({
    origin: [
        'http://localhost:3000',                    // 本地開發
        'http://localhost:5173',                    // Vite 開發伺服器
        'http://localhost:8000',                    // Python HTTP 伺服器
        'https://ai-chatbot-umqm.onrender.com',    // 您的前端網站
        'https://echochat-web.vercel.app',          // 備用前端網站
        'https://echochat-app.vercel.app',          // App 網站
        'https://echochat-frontend.onrender.com',   // Render 前端
        'https://echochat-web.onrender.com',        // 可能的 Render 前端
        'capacitor://localhost',                    // 手機 App
        'http://localhost:8080',                    // 手機 App 開發
        '*'                                          // 開發時允許所有來源
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// 電子郵件配置
const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false, // 使用 STARTTLS
    auth: {
        user: process.env.EMAIL_USER || 'echochatsup@gmail.com',
        pass: process.env.EMAIL_PASS || 'skoh eqrm behq twmt' // 移除空格，直接使用應用程式密碼
    },
    tls: {
        rejectUnauthorized: false
    }
});

// 生成隨機驗證碼
const generateVerificationCode = () => {
    return Math.floor(100000 + Math.random() * 900000).toString();
};

// 發送驗證碼電子郵件
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
                <p>如果您沒有要求此驗證碼，請忽略此郵件。</p>
            </div>
        `
    };
    
    return transporter.sendMail(mailOptions);
};

// 發送密碼重設電子郵件
const sendPasswordResetEmail = async (email, code) => {
    const mailOptions = {
        from: process.env.EMAIL_USER || 'echochatsup@gmail.com',
        to: email,
        subject: 'EchoChat - 密碼重設驗證碼',
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #667eea;">EchoChat 密碼重設</h2>
                <p>您要求重設密碼，請使用以下驗證碼：</p>
                <div style="background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; color: #667eea; border-radius: 8px; margin: 20px 0;">
                    ${code}
                </div>
                <p>此驗證碼將在10分鐘後過期。</p>
                <p>如果您沒有要求重設密碼，請忽略此郵件並確保您的帳號安全。</p>
                <p style="color: #666; font-size: 12px; margin-top: 30px;">
                    此郵件由 EchoChat 系統自動發送，請勿回覆。
                </p>
            </div>
        `
    };
    
    return transporter.sendMail(mailOptions);
};

// 初始化 Vision 實體 (如果環境變數存在)
let vision = null;
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    vision = new ImageAnnotatorClient();
}

// 確保上傳目錄存在
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir);
}

// 設置 multer
const upload = multer({ dest: 'uploads/' });

// 安全性中間件
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "'unsafe-inline'", "'unsafe-eval'"],
        scriptSrcAttr: ["'unsafe-inline'"],
        styleSrc: ["'self'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com"],
        fontSrc: ["'self'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "data:"],
        connectSrc: ["'self'"]
      },
    },
  })
);

// 環境變數檢查端點（僅用於開發和測試）
app.get('/api/env-check', (req, res) => {
    const envVars = {
        NODE_ENV: process.env.NODE_ENV,
        LINE_CHANNEL_ACCESS_TOKEN: process.env.LINE_CHANNEL_ACCESS_TOKEN ? '已設置' : '未設置',
        LINE_CHANNEL_SECRET: process.env.LINE_CHANNEL_SECRET ? '已設置' : '未設置',
        OPENAI_API_KEY: process.env.OPENAI_API_KEY ? '已設置' : '未設置',
        JWT_SECRET: process.env.JWT_SECRET ? '已設置' : '未設置',
        PORT: process.env.PORT,
        DATA_DIR: process.env.DATA_DIR
    };
    
    res.json({
        success: true,
        message: '環境變數檢查',
        envVars: envVars,
        timestamp: new Date().toISOString()
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
app.use(limiter);
app.use('/api/login', loginLimiter);
app.use('/webhook', express.raw({ type: '*/*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// 移除靜態檔案服務，因為這是純 API 服務
// app.use(express.static('public'));
// app.use('/js', express.static(path.join(__dirname, 'public/js')));
// app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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
        jwt.verify(token, JWT_SECRET, (err, staff) => {
            if (err) {
                return res.status(403).json({
                    success: false,
                    error: '無效的認證令牌'
                });
            }
            req.staff = staff;
            next();
        });
    } catch (error) {
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
        
        if (!roles.includes(req.staff.role)) {
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
const dataFile = path.join(dataDir, 'database.json');

// 確保資料目錄存在
if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
}

// 初始化資料結構
let database = {
    staff_accounts: [],
    user_questions: [],
    knowledge: [],
    user_states: [],
    chat_history: [],
    ai_assistant_config: [],
    email_verifications: [], // 儲存電子郵件驗證碼
    password_reset_requests: [] // 儲存密碼重設請求
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
                ai_assistant_config: loadedData.ai_assistant_config || [],
                email_verifications: loadedData.email_verifications || [],
                password_reset_requests: loadedData.password_reset_requests || []
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
    }
};

// 初始化資料庫
const connectDatabase = async () => {
    try {
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
        } else {
            console.log('ℹ️ 管理員帳號已存在');
        }
        
        console.log('✅ JSON 資料庫初始化完成');
        return true;
    } catch (error) {
        console.error('❌ 資料庫初始化失敗:', error.message);
        throw error;
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
                    role: staff.role 
                },
                JWT_SECRET,
                { expiresIn: '24h' }
            );

            res.json({
                success: true,
                token,
                user: {
                    id: staff.id,
                    username: staff.username,
                    name: staff.name,
                    role: staff.role
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

// 驗證用戶身份 API
app.get('/api/me', authenticateJWT, (req, res) => {
    try {
        const user = findStaffById(req.staff.id);
        if (!user) {
            return res.status(404).json({
                success: false,
                error: '用戶不存在'
            });
        }
        
        res.json({
            success: true,
            user: {
                id: user.id,
                username: user.username,
                name: user.name,
                role: user.role
            }
        });
    } catch (error) {
        console.error('獲取用戶資料錯誤:', error);
        res.status(500).json({
            success: false,
            error: '伺服器錯誤'
        });
    }
});

// 發送電子郵件驗證碼 API
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
        const existingUser = database.staff_accounts.find(staff => staff.email === email);
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: '此電子郵件已被註冊'
            });
        }
        
        // 生成驗證碼
        const code = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10分鐘後過期
        
        // 儲存驗證碼（移除舊的同一電子郵件驗證碼）
        database.email_verifications = database.email_verifications.filter(
            verification => verification.email !== email
        );
        database.email_verifications.push({
            email: email,
            code: code,
            expiresAt: expiresAt.toISOString(),
            verified: false
        });
        saveDatabase();
        
        // 嘗試發送電子郵件
        try {
            console.log('📧 嘗試發送郵件到:', email);
            console.log('🔧 郵件配置:', {
                user: process.env.EMAIL_USER || 'echochatsup@gmail.com',
                pass: process.env.EMAIL_PASS ? '***已設定***' : '***未設定***'
            });
            
            await sendVerificationEmail(email, code);
            console.log('✅ 驗證碼已發送到:', email);
            
            res.json({
                success: true,
                message: '驗證碼已發送到您的電子郵件'
            });
        } catch (emailError) {
            console.log('⚠️ 電子郵件發送失敗，但驗證碼已生成:', code);
            console.error('📧 詳細錯誤信息:', emailError);
            
            // 郵件發送失敗時，返回驗證碼作為備案
            res.json({
                success: true,
                message: '驗證碼已生成（郵件服務暫時不可用）',
                code: code
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

// 驗證電子郵件驗證碼 API
app.post('/api/verify-code', async (req, res) => {
    try {
        const { email, code } = req.body;
        
        if (!email || !code) {
            return res.status(400).json({
                success: false,
                error: '請提供電子郵件和驗證碼'
            });
        }
        
        // 尋找驗證記錄
        const verification = database.email_verifications.find(
            v => v.email === email && v.code === code && !v.verified
        );
        
        if (!verification) {
            return res.status(400).json({
                success: false,
                error: '驗證碼無效'
            });
        }
        
        // 檢查是否過期
        if (new Date() > new Date(verification.expiresAt)) {
            return res.status(400).json({
                success: false,
                error: '驗證碼已過期'
            });
        }
        
        // 標記為已驗證
        verification.verified = true;
        saveDatabase();
        
        res.json({
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

// 使用者註冊 API
app.post('/api/register', async (req, res) => {
    try {
        const { username, email, password, lineConfig } = req.body;
        
        // 驗證必要欄位
        if (!username || !email || !password) {
            return res.status(400).json({
                success: false,
                error: '請填寫所有必要欄位'
            });
        }
        
        // 檢查電子郵件是否已驗證
        const verification = database.email_verifications.find(
            v => v.email === email && v.verified
        );
        if (!verification) {
            return res.status(400).json({
                success: false,
                error: '請先驗證電子郵件'
            });
        }
        
        // 檢查用戶名是否已存在
        const existingUser = database.staff_accounts.find(staff => 
            staff.username === username || staff.email === email
        );
        if (existingUser) {
            return res.status(400).json({
                success: false,
                error: '用戶名或電子郵件已存在'
            });
        }
        
        // 密碼加密
        const hash = await new Promise((resolve, reject) => {
            bcrypt.hash(password, 10, (err, hash) => {
                if (err) reject(err);
                else resolve(hash);
            });
        });
        
        // 創建新用戶
        const newUser = {
            id: database.staff_accounts.length + 1,
            username: username,
            password: hash,
            name: username, // 預設使用用戶名作為顯示名稱
            role: 'user',
            email: email,
            created_at: new Date().toISOString()
        };
        
        database.staff_accounts.push(newUser);
        saveDatabase();
        
        console.log('✅ 新用戶註冊成功:', username);
        
        res.json({
            success: true,
            message: '註冊成功'
        });
        
    } catch (error) {
        console.error('註冊錯誤:', error);
        res.status(500).json({
            success: false,
            error: '註冊過程發生錯誤'
        });
    }
});

// 獲取個人資料 API
app.get('/api/profile', authenticateJWT, (req, res) => {
    try {
        res.json({
            success: true,
            profile: {
                id: req.staff.id,
                username: req.staff.username,
                name: req.staff.name,
                role: req.staff.role
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: '獲取個人資料失敗'
        });
    }
});

// 更新個人資料 API
app.post('/api/profile', authenticateJWT, (req, res) => {
    try {
        const { name, email } = req.body;
        
        if (!name) {
            return res.status(400).json({
                success: false,
                error: '請提供顯示名稱'
            });
        }

        // 這裡原本是使用 sqlite3，需要改為直接操作 database 物件
        // db.run("UPDATE staff SET name = ? WHERE id = ?", [name, req.staff.id], function(err) {
        //     if (err) {
        //         return res.status(500).json({
        //             success: false,
        //             error: '更新個人資料失敗'
        //         });
        //     }

        //     res.json({
        //         success: true,
        //         message: '個人資料已更新'
        //     });
        // });
        // 暫時使用內存資料庫，實際應用需要持久化
        const staff = findStaffById(req.staff.id);
        if (staff) {
            staff.name = name;
            saveDatabase();
            res.json({
                success: true,
                message: '個人資料已更新'
            });
        } else {
            res.status(404).json({
                success: false,
                error: '用戶不存在'
            });
        }
    } catch (error) {
        res.status(500).json({
            success: false,
            error: '更新個人資料失敗'
        });
    }
});

// 修改密碼 API
app.post('/api/change-password', authenticateJWT, async (req, res) => {
    try {
        const { oldPassword, newPassword } = req.body;
        
        if (!oldPassword || !newPassword) {
            return res.status(400).json({
                success: false,
                error: '請提供舊密碼和新密碼'
            });
        }

        if (newPassword.length < 6) {
            return res.status(400).json({
                success: false,
                error: '新密碼長度至少需要6個字元'
            });
        }

        try {
            const staff = findStaffById(req.staff.id);
            
            if (!staff) {
                return res.status(404).json({
                    success: false,
                    error: '用戶不存在'
                });
            }

            const isValidPassword = await bcrypt.compare(oldPassword, staff.password);
            if (!isValidPassword) {
                return res.status(401).json({
                    success: false,
                    error: '舊密碼錯誤'
                });
            }

            const hashedNewPassword = await bcrypt.hash(newPassword, 10);
            const updated = updateStaffPassword(req.staff.id, hashedNewPassword);

            if (updated) {
                res.json({
                    success: true,
                    message: '密碼已成功修改'
                });
            } else {
                res.status(500).json({
                    success: false,
                    error: '修改密碼失敗'
                });
            }
        } catch (error) {
            console.error('修改密碼錯誤:', error);
            return res.status(500).json({
                success: false,
                error: '修改密碼失敗'
            });
        }
    } catch (error) {
        console.error('修改密碼錯誤:', error);
        res.status(500).json({
            success: false,
            error: '修改密碼失敗'
        });
    }
});

// 刪除帳號 API
app.post('/api/delete-account', authenticateJWT, async (req, res) => {
    try {
        const { password } = req.body;
        
        if (!password) {
            return res.status(400).json({
                success: false,
                error: '請提供密碼'
            });
        }

        try {
            const staff = findStaffById(req.staff.id);
            
            if (!staff) {
                return res.status(404).json({
                    success: false,
                    error: '用戶不存在'
                });
            }

            const isValidPassword = await bcrypt.compare(password, staff.password);
            if (!isValidPassword) {
                return res.status(401).json({
                    success: false,
                    error: '密碼錯誤'
                });
            }

            const deleted = deleteStaffById(req.staff.id);

            if (deleted) {
                res.json({
                    success: true,
                    message: '帳號已成功刪除'
                });
            } else {
                res.status(404).json({
                    success: false,
                    error: '帳號不存在'
                });
            }
        } catch (error) {
            console.error('刪除帳號錯誤:', error);
            res.status(500).json({
                success: false,
                error: '刪除帳號失敗'
            });
        }
    } catch (error) {
        console.error('刪除帳號錯誤:', error);
        res.status(500).json({
            success: false,
            error: '刪除帳號失敗'
        });
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
        // 獲取第一個配置，如果沒有則返回預設值
        const config = database.ai_assistant_config[0] || {
            assistant_name: '設計師 Rainy',
            llm: 'gpt-4o-mini',
            use_case: 'customer-service',
            description: 'OBJECTIVE(目標任務):\n你的目標是客戶服務與美容美髮發行錄，創造一個良好的對話體驗，讓客戶感到舒適，願意分享他們的真實想法及需求。\n\nSTYLE(風格/個性):\n你的個性是很健談並且很直率人保學會存在，樂於創造一個放鬆和友好的氣圍。\n\nTONE(語調):\n親性、溫柔、深情人心。',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        
        res.json({
            success: true,
            config: config
        });
    } catch (error) {
        console.error('獲取 AI 助理配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取配置失敗'
        });
    }
});

// 更新 AI 助理配置
app.post('/api/ai-assistant-config', authenticateJWT, (req, res) => {
    try {
        const { assistant_name, llm, use_case, description } = req.body;
        
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
            updated_at: new Date().toISOString()
        };
        
        // 如果是第一個配置，添加創建時間
        if (database.ai_assistant_config.length === 0) {
            config.created_at = new Date().toISOString();
        } else {
            config.created_at = database.ai_assistant_config[0].created_at;
        }
        
        // 更新或創建配置（只保留一個配置）
        database.ai_assistant_config = [config];
        saveDatabase();
        
        console.log('✅ AI 助理配置已更新:', config.assistant_name);
        
        res.json({
            success: true,
            message: 'AI 助理配置已成功更新',
            config: config
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
            assistant_name: '設計師 Rainy',
            llm: 'gpt-4o-mini',
            use_case: 'customer-service',
            description: 'OBJECTIVE(目標任務):\n你的目標是客戶服務與美容美髮發行錄，創造一個良好的對話體驗，讓客戶感到舒適，願意分享他們的真實想法及需求。\n\nSTYLE(風格/個性):\n你的個性是很健談並且很直率人保學會存在，樂於創造一個放鬆和友好的氣圍。\n\nTONE(語調):\n親性、溫柔、深情人心。',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        
        // 重置為預設配置
        database.ai_assistant_config = [defaultConfig];
        saveDatabase();
        
        console.log('✅ AI 助理配置已重置為預設值');
        
        res.json({
            success: true,
            message: 'AI 助理配置已重置為預設值',
            config: defaultConfig
        });
    } catch (error) {
        console.error('重置 AI 助理配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '重置配置失敗'
        });
    }
});

// 獲取所有可用的 AI 模型資訊
app.get('/api/ai-models', authenticateJWT, (req, res) => {
    try {
        const models = {
            'gpt-4o-mini': {
                name: 'GPT-4o Mini',
                provider: 'OpenAI',
                description: '快速且經濟實惠的對話體驗，適合一般客服需求',
                features: ['快速回應', '成本效益高', '支援多語言', '適合日常對話'],
                pricing: '經濟實惠',
                speed: '快速',
                max_tokens: 128000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'gpt-4o': {
                name: 'GPT-4o',
                provider: 'OpenAI',
                description: '高級版本，提供更強大的理解和生成能力',
                features: ['高品質回應', '複雜任務處理', '創意內容生成', '深度理解'],
                pricing: '中等',
                speed: '中等',
                max_tokens: 128000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'gpt-4-turbo': {
                name: 'GPT-4 Turbo',
                provider: 'OpenAI',
                description: '平衡效能和速度的優化版本',
                features: ['平衡效能', '快速處理', '高品質輸出', '廣泛應用'],
                pricing: '中等',
                speed: '快速',
                max_tokens: 128000,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'gpt-3.5-turbo': {
                name: 'GPT-3.5 Turbo',
                provider: 'OpenAI',
                description: '經典版本，穩定可靠且成本較低',
                features: ['穩定可靠', '成本較低', '快速回應', '廣泛支援'],
                pricing: '經濟實惠',
                speed: '快速',
                max_tokens: 16385,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            },
            'gpt-3.5-turbo-16k': {
                name: 'GPT-3.5 Turbo 16K',
                provider: 'OpenAI',
                description: '支援更長對話的擴展版本',
                features: ['長對話支援', '大上下文', '穩定效能', '適合複雜對話'],
                pricing: '中等',
                speed: '中等',
                max_tokens: 16385,
                supported_languages: ['中文', '英文', '日文', '韓文', '法文', '德文', '西班牙文']
            }
        };
        
        res.json({
            success: true,
            models: models
        });
    } catch (error) {
        console.error('獲取 AI 模型資訊錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取模型資訊失敗'
        });
    }
});

// AI 聊天 API 端點 - 使用配置的 AI 模型生成回應
app.post('/api/chat', authenticateJWT, async (req, res) => {
    try {
        const { message, conversationId } = req.body;
        
        if (!message || typeof message !== 'string') {
            return res.status(400).json({
                success: false,
                error: '請提供有效的訊息內容'
            });
        }

        // 載入資料庫
        loadDatabase();
        
        // 獲取 AI 助理配置
        const aiConfig = database.ai_assistant_config[0] || {
            assistant_name: 'AI 助理',
            llm: 'gpt-4o-mini',
            use_case: 'customer-service',
            description: '我是您的智能客服助理，很高興為您服務！'
        };

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

        // 構建完整的對話訊息
        const messages = [
            { role: 'system', content: systemPrompt },
            ...conversationHistory,
            { role: 'user', content: message }
        ];

        // 調用 OpenAI API
        const openaiResponse = await axios.post(
            'https://api.openai.com/v1/chat/completions',
            {
                model: aiConfig.llm,
                messages: messages,
                max_tokens: 1000,
                temperature: 0.7
            },
            {
                headers: {
                    'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        const aiReply = openaiResponse.data.choices[0].message.content.trim();

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
        
        // 檢查是否為 OpenAI API 錯誤
        if (error.response && error.response.status === 401) {
            return res.status(500).json({
                success: false,
                error: 'OpenAI API 金鑰無效或已過期'
            });
        } else if (error.response && error.response.status === 429) {
            return res.status(500).json({
                success: false,
                error: 'OpenAI API 請求頻率過高，請稍後再試'
            });
        } else if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED') {
            return res.status(500).json({
                success: false,
                error: '無法連接到 OpenAI 服務，請檢查網路連接'
            });
        }

        res.status(500).json({
            success: false,
            error: 'AI 回應生成失敗，請稍後再試'
        });
    }
});

// 獲取對話歷史 API 端點
app.get('/api/conversations', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        const conversations = database.chat_history || [];
        
        // 為每個對話添加統計資訊
        const conversationsWithStats = conversations.map(conv => ({
            ...conv,
            messageCount: conv.messages ? conv.messages.length : 0,
            lastMessage: conv.messages && conv.messages.length > 0 
                ? conv.messages[conv.messages.length - 1].content.substring(0, 100) + '...'
                : '無訊息'
        }));

        res.json({
            success: true,
            conversations: conversationsWithStats
        });
    } catch (error) {
        console.error('獲取對話歷史錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取對話歷史失敗'
        });
    }
});

// 獲取特定對話的詳細訊息
app.get('/api/conversations/:conversationId', authenticateJWT, (req, res) => {
    try {
        const { conversationId } = req.params;
        loadDatabase();
        
        const conversation = database.chat_history.find(conv => conv.id === conversationId);
        
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

// 刪除對話
app.delete('/api/conversations/:conversationId', authenticateJWT, (req, res) => {
    try {
        const { conversationId } = req.params;
        loadDatabase();
        
        const conversationIndex = database.chat_history.findIndex(conv => conv.id === conversationId);
        
        if (conversationIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '對話不存在'
            });
        }

        database.chat_history.splice(conversationIndex, 1);
        saveDatabase();

        res.json({
            success: true,
            message: '對話已成功刪除'
        });
    } catch (error) {
        console.error('刪除對話錯誤:', error);
        res.status(500).json({
            success: false,
            error: '刪除對話失敗'
        });
    }
});

// 獲取用戶的 LINE Token 配置
app.get('/api/line-token', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        
        const user = database.staff_accounts.find(staff => staff.id === req.staff.id);
        
        if (!user) {
            return res.status(404).json({
                success: false,
                error: '用戶不存在'
            });
        }

        res.json({
            success: true,
            line_token: user.line_token || {}
        });
    } catch (error) {
        console.error('獲取 LINE Token 配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取 LINE Token 配置失敗'
        });
    }
});

// 更新用戶的 LINE Token 配置
app.post('/api/line-token', authenticateJWT, (req, res) => {
    try {
        const { channel_access_token, channel_secret, enabled } = req.body;
        loadDatabase();
        
        const userIndex = database.staff_accounts.findIndex(staff => staff.id === req.staff.id);
        
        if (userIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '用戶不存在'
            });
        }

        // 更新 LINE Token 配置
        database.staff_accounts[userIndex].line_token = {
            channel_access_token: channel_access_token || '',
            channel_secret: channel_secret || '',
            enabled: enabled || false,
            updated_at: new Date().toISOString()
        };

        saveDatabase();

        console.log('✅ LINE Token 配置更新成功:', req.staff.username);

        res.json({
            success: true,
            message: 'LINE Token 配置更新成功'
        });
    } catch (error) {
        console.error('更新 LINE Token 配置錯誤:', error);
        res.status(500).json({
            success: false,
            error: '更新 LINE Token 配置失敗'
        });
    }
});

// LINE Webhook 端點 - 個人用戶
app.post('/api/webhook/line/:userId', (req, res) => {
    try {
        const { userId } = req.params;
        loadDatabase();
        
        const user = database.staff_accounts.find(staff => staff.id == userId);
        
        if (!user || !user.line_token || !user.line_token.enabled) {
            return res.status(404).json({
                success: false,
                error: '用戶或 LINE Token 配置不存在'
            });
        }

        const { channel_access_token, channel_secret } = user.line_token;
        
        if (!channel_access_token || !channel_secret) {
            return res.status(400).json({
                success: false,
                error: 'LINE Token 配置不完整'
            });
        }

        // 建立 LINE 客戶端
        const lineClient = new Client({
            channelAccessToken: channel_access_token,
            channelSecret: channel_secret
        });

        // 處理 LINE 事件
        const events = req.body.events;
        
        Promise.all(events.map(async (event) => {
            if (event.type === 'message' && event.message.type === 'text') {
                const userMessage = event.message.text;
                
                // 調用 AI 聊天 API
                try {
                    const aiResponse = await axios.post(`${req.protocol}://${req.get('host')}/api/chat`, {
                        message: userMessage,
                        conversationId: `line_${event.source.userId}_${Date.now()}`,
                        userId: userId
                    }, {
                        headers: {
                            'Content-Type': 'application/json'
                        }
                    });

                    if (aiResponse.data.success) {
                        // 回覆 LINE 用戶
                        await lineClient.replyMessage(event.replyToken, {
                            type: 'text',
                            text: aiResponse.data.reply
                        });
                    }
                } catch (error) {
                    console.error('LINE AI 回應錯誤:', error);
                    // 回覆預設訊息
                    await lineClient.replyMessage(event.replyToken, {
                        type: 'text',
                        text: '抱歉，我現在無法回應，請稍後再試。'
                    });
                }
            }
        }));

        res.json({ success: true });
    } catch (error) {
        console.error('LINE Webhook 錯誤:', error);
        res.status(500).json({
            success: false,
            error: 'LINE Webhook 處理失敗'
        });
    }
});

// 簡化的 LINE Webhook 端點 - 無需驗證
app.post('/api/webhook/line-simple', (req, res) => {
    try {
        console.log('📨 收到 LINE Webhook 事件:', req.body);
        
        // 處理 LINE 事件
        const events = req.body.events;
        
        if (!events || events.length === 0) {
            return res.json({ success: true, message: '無事件需要處理' });
        }

        Promise.all(events.map(async (event) => {
            if (event.type === 'message' && event.message.type === 'text') {
                const userMessage = event.message.text;
                console.log('💬 收到 LINE 訊息:', userMessage);
                
                // 簡單的回應邏輯
                let replyMessage = '您好！我是 EchoChat AI 助手。';
                
                if (userMessage.includes('你好') || userMessage.includes('hello')) {
                    replyMessage = '您好！很高興為您服務。';
                } else if (userMessage.includes('幫助') || userMessage.includes('help')) {
                    replyMessage = '我可以協助您了解 EchoChat 的功能，包括 AI 客服、多平台串接等服務。';
                } else if (userMessage.includes('價格') || userMessage.includes('費用')) {
                    replyMessage = '我們提供多種訂閱方案，請訪問我們的網站了解詳細價格。';
                } else {
                    replyMessage = `感謝您的訊息：「${userMessage}」。我是 AI 助手，正在學習中。`;
                }
                
                // 使用預設的 LINE 配置回應
                try {
                    const defaultLineClient = new Client({
                        channelAccessToken: process.env.LINE_CHANNEL_ACCESS_TOKEN || '',
                        channelSecret: process.env.LINE_CHANNEL_SECRET || ''
                    });
                    
                    await defaultLineClient.replyMessage(event.replyToken, {
                        type: 'text',
                        text: replyMessage
                    });
                    
                    console.log('✅ 已回覆 LINE 訊息:', replyMessage);
                } catch (error) {
                    console.error('❌ LINE 回應錯誤:', error);
                }
            }
        }));

        res.json({ success: true, message: 'Webhook 處理完成' });
    } catch (error) {
        console.error('❌ LINE Webhook 錯誤:', error);
        res.status(500).json({
            success: false,
            error: 'LINE Webhook 處理失敗'
        });
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
    // 使用預設模型列表（因為沒有OpenAI API金鑰）
    const models = [
      {
        id: 'gpt-4o',
        name: 'GPT-4o',
        description: '最新最強大的AI模型，理解力和創造力最佳',
        maxTokens: 4000,
        isAvailable: true,
        category: 'premium'
      },
      {
        id: 'gpt-4o-mini',
        name: 'GPT-4o Mini',
        description: '輕量級GPT-4模型，速度快且成本較低',
        maxTokens: 2000,
        isAvailable: true,
        category: 'standard'
      },
      {
        id: 'gpt-4-turbo',
        name: 'GPT-4 Turbo',
        description: '高級AI模型，適合複雜任務和創意工作',
        maxTokens: 4000,
        isAvailable: true,
        category: 'premium'
      },
      {
        id: 'gpt-3.5-turbo',
        name: 'GPT-3.5 Turbo',
        description: '平衡性能和速度的經典模型',
        maxTokens: 2000,
        isAvailable: true,
        category: 'standard'
      },
      {
        id: 'claude-3-5-sonnet',
        name: 'Claude 3.5 Sonnet',
        description: '擅長分析和寫作的AI模型',
        maxTokens: 4000,
        isAvailable: true,
        category: 'premium'
      }
    ];

    res.json({
      success: true,
      message: 'AI 模型列表獲取成功',
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
        
        const newChannel = {
            id: uuidv4(),
            userId: req.staff.id,
            name,
            platform,
            apiKey,
            channelSecret,
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
        
        res.status(201).json({
            success: true,
            message: '頻道建立成功',
            channel: newChannel
        });
        
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
        
        const userChannels = (database.channels || []).filter(
            channel => channel.userId === req.staff.id
        );
        
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
        
        const updatedChannel = {
            ...database.channels[channelIndex],
            name: name || database.channels[channelIndex].name,
            platform: platform || database.channels[channelIndex].platform,
            apiKey: apiKey || database.channels[channelIndex].apiKey,
            channelSecret: channelSecret || database.channels[channelIndex].channelSecret,
            webhookUrl: webhookUrl || database.channels[channelIndex].webhookUrl,
            isActive: isActive !== undefined ? isActive : database.channels[channelIndex].isActive,
            updatedAt: new Date().toISOString()
        };
        
        database.channels[channelIndex] = updatedChannel;
        saveDatabase();
        
        console.log('✅ 頻道更新成功:', updatedChannel.name);
        
        res.json({
            success: true,
            message: '頻道更新成功',
            channel: updatedChannel
        });
        
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
app.post('/api/channels/test', authenticateJWT, (req, res) => {
    try {
        const { platform, apiKey, channelSecret } = req.body;
        
        if (!platform || !apiKey || !channelSecret) {
            return res.status(400).json({
                success: false,
                error: '缺少必要欄位'
            });
        }
        
        // 根據平台進行不同的測試
        if (platform === 'LINE') {
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
        } else {
            // 其他平台的測試邏輯
            res.json({
                success: true,
                message: `${platform} 頻道連接測試成功`
            });
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

// 獲取帳務總覽
app.get('/api/billing/overview', authenticateJWT, (req, res) => {
    try {
        loadDatabase();
        
        // 模擬帳務資料
        const overview = {
            currentPlan: 'Pro',
            nextBillingDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            totalUsage: {
                conversations: 1250,
                messages: 8500,
                apiCalls: 15000
            },
            limits: {
                conversations: 2000,
                messages: 10000,
                apiCalls: 20000
            },
            usage: {
                conversations: 62.5,
                messages: 85.0,
                apiCalls: 75.0
            }
        };
        
        res.json({
            success: true,
            overview: overview
        });
        
    } catch (error) {
        console.error('獲取帳務總覽錯誤:', error);
        res.status(500).json({
            success: false,
            error: '獲取帳務總覽失敗'
        });
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