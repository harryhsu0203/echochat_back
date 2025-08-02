# 後端用戶專屬 Webhook URL 整合指南

## 概述

本文件說明如何實現類似 seachat 的用戶專屬 webhook URL 功能，每個用戶都有基於其用戶 ID 的獨特 webhook 端點。

## API 端點設計

### 1. 獲取用戶資料端點

```javascript
// GET /api/user/profile
// 獲取當前登入用戶的資料，包括用戶 ID

app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    // 從資料庫獲取用戶資料
    const user = await User.findById(userId).select('-password');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: '用戶不存在'
      });
    }
    
    res.json({
      success: true,
      data: {
        id: user._id.toString(),
        username: user.username,
        email: user.email,
        companyName: user.companyName,
        role: user.role,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: '獲取用戶資料失敗'
    });
  }
});
```

### 2. 用戶專屬 Webhook URL 端點

```javascript
// POST /api/user/webhook-url
// 同步用戶的 webhook URL 設定

app.post('/api/user/webhook-url', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { webhookUrl, platform } = req.body;
    
    // 驗證 webhook URL 格式
    if (!webhookUrl || !webhookUrl.includes('/webhook/line/')) {
      return res.status(400).json({
        success: false,
        error: '無效的 webhook URL 格式'
      });
    }
    
    // 檢查 URL 是否包含用戶 ID
    const urlUserId = webhookUrl.split('/webhook/line/')[1];
    if (urlUserId !== userId) {
      return res.status(403).json({
        success: false,
        error: 'webhook URL 與當前用戶不匹配'
      });
    }
    
    // 更新或創建用戶的 webhook 設定
    await UserWebhookSetting.findOneAndUpdate(
      { userId },
      {
        userId,
        webhookUrl,
        platform: platform || 'line',
        isActive: true,
        updatedAt: new Date()
      },
      { upsert: true, new: true }
    );
    
    res.json({
      success: true,
      data: {
        message: 'Webhook URL 同步成功',
        webhookUrl
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: '同步 webhook URL 失敗'
    });
  }
});

// GET /api/user/webhook-url
// 獲取用戶的 webhook URL 設定

app.get('/api/user/webhook-url', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const webhookSetting = await UserWebhookSetting.findOne({ userId });
    
    if (!webhookSetting) {
      return res.status(404).json({
        success: false,
        error: '未找到 webhook 設定'
      });
    }
    
    res.json({
      success: true,
      data: {
        webhookUrl: webhookSetting.webhookUrl,
        platform: webhookSetting.platform,
        isActive: webhookSetting.isActive,
        createdAt: webhookSetting.createdAt,
        updatedAt: webhookSetting.updatedAt
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: '獲取 webhook URL 失敗'
    });
  }
});
```

### 3. 用戶專屬 Webhook 處理端點

```javascript
// POST /api/webhook/line/:userId
// 處理特定用戶的 LINE webhook 事件

app.post('/api/webhook/line/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const signature = req.headers['x-line-signature'];
    const body = req.body;
    
    // 驗證用戶是否存在
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: '用戶不存在'
      });
    }
    
    // 獲取用戶的 LINE 設定
    const lineSettings = await LineAPISetting.findOne({ userId });
    if (!lineSettings) {
      return res.status(400).json({
        success: false,
        error: '用戶未設定 LINE API'
      });
    }
    
    // 驗證 LINE 簽名
    const hash = crypto
      .createHmac('SHA256', lineSettings.channelSecret)
      .update(JSON.stringify(body))
      .digest('base64');
    
    if (signature !== hash) {
      return res.status(401).json({
        success: false,
        error: '簽名驗證失敗'
      });
    }
    
    // 處理 webhook 事件
    const events = body.events || [];
    
    for (const event of events) {
      await handleLineWebhookEvent(userId, event, lineSettings);
    }
    
    res.json({
      success: true,
      message: 'Webhook 事件處理成功'
    });
  } catch (error) {
    console.error('Webhook 處理錯誤:', error);
    res.status(500).json({
      success: false,
      error: 'Webhook 處理失敗'
    });
  }
});

// 處理 LINE webhook 事件的函數
async function handleLineWebhookEvent(userId, event, lineSettings) {
  try {
    const { type, message, replyToken, source } = event;
    
    // 記錄事件
    await LineWebhookEvent.create({
      userId,
      eventType: type,
      sourceId: source.userId || source.groupId || source.roomId,
      message: message,
      replyToken,
      timestamp: new Date(event.timestamp),
      processed: false
    });
    
    // 根據事件類型處理
    switch (type) {
      case 'message':
        await handleMessageEvent(userId, event, lineSettings);
        break;
      case 'follow':
        await handleFollowEvent(userId, event, lineSettings);
        break;
      case 'unfollow':
        await handleUnfollowEvent(userId, event, lineSettings);
        break;
      default:
        console.log(`未處理的事件類型: ${type}`);
    }
  } catch (error) {
    console.error('處理 webhook 事件錯誤:', error);
  }
}

// 處理訊息事件
async function handleMessageEvent(userId, event, lineSettings) {
  const { message, replyToken, source } = event;
  
  if (message.type === 'text') {
    // 保存訊息到資料庫
    await LineMessage.create({
      userId,
      sourceId: source.userId,
      content: message.text,
      messageType: 'text',
      timestamp: new Date(event.timestamp),
      direction: 'inbound'
    });
    
    // 檢查是否啟用自動回應
    const userSettings = await UserSetting.findOne({ userId });
    if (userSettings && userSettings.autoResponseEnabled) {
      // 生成 AI 回應
      const aiResponse = await generateAIResponse(userId, message.text);
      
      // 發送回覆
      await sendLineReply(lineSettings.channelAccessToken, replyToken, aiResponse);
      
      // 保存 AI 回應
      await LineMessage.create({
        userId,
        sourceId: source.userId,
        content: aiResponse,
        messageType: 'text',
        timestamp: new Date(),
        direction: 'outbound'
      });
    }
  }
}
```

## 資料庫模型

### UserWebhookSetting 模型

```javascript
const mongoose = require('mongoose');

const userWebhookSettingSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  webhookUrl: {
    type: String,
    required: true
  },
  platform: {
    type: String,
    enum: ['line', 'telegram', 'whatsapp'],
    default: 'line'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('UserWebhookSetting', userWebhookSettingSchema);
```

### LineWebhookEvent 模型

```javascript
const lineWebhookEventSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  eventType: {
    type: String,
    required: true
  },
  sourceId: {
    type: String,
    required: true
  },
  message: {
    type: mongoose.Schema.Types.Mixed
  },
  replyToken: String,
  timestamp: {
    type: Date,
    required: true
  },
  processed: {
    type: Boolean,
    default: false
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('LineWebhookEvent', lineWebhookEventSchema);
```

## 安全性考慮

### 1. 用戶認證
- 所有 API 端點都需要有效的 JWT token
- 驗證用戶只能訪問自己的 webhook URL

### 2. LINE 簽名驗證
- 使用 LINE Channel Secret 驗證 webhook 簽名
- 防止偽造請求

### 3. URL 驗證
- 確保 webhook URL 包含正確的用戶 ID
- 防止用戶訪問其他用戶的端點

### 4. 速率限制
```javascript
const rateLimit = require('express-rate-limit');

const webhookLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 分鐘
  max: 100, // 限制每個 IP 15 分鐘內最多 100 個請求
  message: {
    success: false,
    error: '請求過於頻繁，請稍後再試'
  }
});

app.use('/api/webhook/line/:userId', webhookLimiter);
```

## 使用範例

### 1. 生成用戶專屬 URL
```javascript
// 用戶 ID: 507f1f77bcf86cd799439011
// 生成的 URL: https://ai-chatbot-umqm.onrender.com/api/webhook/line/507f1f77bcf86cd799439011
```

### 2. LINE Developers Console 設定
1. 登入 LINE Developers Console
2. 選擇您的 Channel
3. 在 Messaging API 設定中
4. 將 Webhook URL 設為：`https://ai-chatbot-umqm.onrender.com/api/webhook/line/507f1f77bcf86cd799439011`
5. 啟用 Use webhook

### 3. 測試 webhook
```bash
curl -X POST https://ai-chatbot-umqm.onrender.com/api/webhook/line/507f1f77bcf86cd799439011 \
  -H "Content-Type: application/json" \
  -H "X-Line-Signature: YOUR_SIGNATURE" \
  -d '{
    "events": [{
      "type": "message",
      "message": {
        "type": "text",
        "text": "Hello"
      },
      "source": {
        "type": "user",
        "userId": "U1234567890"
      },
      "replyToken": "reply-token",
      "timestamp": 1234567890
    }]
  }'
```

## 監控和日誌

### 1. Webhook 事件日誌
```javascript
// 記錄所有 webhook 事件
app.use('/api/webhook/line/:userId', (req, res, next) => {
  console.log(`[${new Date().toISOString()}] Webhook 事件:`, {
    userId: req.params.userId,
    method: req.method,
    headers: req.headers,
    body: req.body
  });
  next();
});
```

### 2. 錯誤監控
```javascript
// 全局錯誤處理
app.use((error, req, res, next) => {
  console.error('Webhook 錯誤:', error);
  
  // 發送錯誤通知
  sendErrorNotification({
    userId: req.params.userId,
    error: error.message,
    stack: error.stack,
    timestamp: new Date()
  });
  
  res.status(500).json({
    success: false,
    error: '內部伺服器錯誤'
  });
});
```

這個實作提供了完整的用戶專屬 webhook URL 功能，確保每個用戶都有獨立的端點，並且具有適當的安全性和監控機制。 