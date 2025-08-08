const jwt = require('jsonwebtoken');

// JWT 認證中間件
const validateToken = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: '缺少認證標頭'
      });
    }

    const token = authHeader.substring(7); // 移除 'Bearer ' 前綴
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: '缺少 JWT 令牌'
      });
    }

    // 驗證 JWT 令牌
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // 將用戶資訊添加到請求物件
    req.user = decoded;
    
    next();
  } catch (error) {
    console.error('JWT 驗證錯誤:', error);
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'JWT 令牌已過期'
      });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        message: '無效的 JWT 令牌'
      });
    }
    
    return res.status(500).json({
      success: false,
      message: '認證處理錯誤'
    });
  }
};

module.exports = {
  validateToken
}; 