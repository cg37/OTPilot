import Foundation

enum AppConstants {
    static let appName = "OTPilot"
    static let bundleIdentifier = "com.otpilot.app"
    static let appVersion = "1.0.0"
    
    static let monitorInterval: TimeInterval = 5.0
    static let menuUpdateInterval: TimeInterval = 2.0
    
    static let maxHistoryCodes = 50
    static let maxDisplayCodes = 5
    
    static let messagesDBPath = "~/Library/Messages/chat.db"
    
    /// 验证码正则：必须包含明确的验证码关键词上下文，避免误判电话号码/订单号等
    static let verificationCodePatterns = [
        // 关键词直接后跟数字: "验证码：123456"、"校验码 888888"
        #"(?:验证码|校验码|确认码|安全码|动态码|激活码|登录码|注册码|身份验证码)[：:\s]*(\d{4,8})"#,
        // 英文关键词: "code: 123456"、"Code:888888"
        #"(?:code|Code|CODE)\s*[：:\s]\s*(\d{4,8})"#,
        // "验证码是/为 123456"
        #"(?:验证码|校验码|动态码|登录码)\s*[是为][：:\s]*(\d{4,8})"#,
        // "输入验证码 123456"
        #"输入.*?(?:验证)?码[：:\s]*(\d{4,8})"#,
        // "123456（验证码）" / "123456(动态码)"
        #"(\d{4,8})\s*[（(]\s*(?:验证码|校验码|动态码|安全码|登录码)\s*[）)]"#,
        // "123456 是您的验证码"
        #"(\d{4,8})\s*[是为].*?(?:验证码|校验码|登录验证码)"#,
    ]
    
    /// 要排除的短信特征（即使匹配了验证码模式也要拒绝）
    /// 用于过滤快递单号、订单号、手机号片段等误判
    static let exclusionPatterns: [String] = [
        // 手机号掩码: 138****1234 或 166***6012
        #"\d{3}\*{2,4}\d{3,4}"#,
        // 完整手机号
        #"1[3-9]\d{9}"#,
        // 电话号码: 010-12345678
        #"\d{3,4}-\d{7,8}"#,
        // 纯快递单号/订单号特征 (长数字串)
        #"\b\d{10,}\b"#,
    ]
    
    static let minCodeLength = 4
    static let maxCodeLength = 8
    
    static let menuItemWidth: CGFloat = 260
    static let menuItemHeight: CGFloat = 22
    static let detailPanelWidth: CGFloat = 280
    static let detailPanelMargin: CGFloat = 16
}
