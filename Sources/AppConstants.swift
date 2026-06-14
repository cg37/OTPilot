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
    
    static let verificationCodePatterns = [
        #"(?:验证码|校验码|确认码|安全码|动态码|激活码)[：:\s]*(\d{4,8})"#,
        #"(?:code|Code|CODE)[：:\s]*(\d{4,8})"#,
        #"(?:验证码|code|Code)[^\d]{0,10}(\d{4,8})"#,
        #"\b(\d{4,6})\b"#
    ]
    
    static let minCodeLength = 4
    static let maxCodeLength = 8
    
    static let menuItemWidth: CGFloat = 260
    static let menuItemHeight: CGFloat = 22
    static let detailPanelWidth: CGFloat = 280
    static let detailPanelMargin: CGFloat = 16
}
