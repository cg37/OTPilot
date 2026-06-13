import Foundation

struct VerificationCode: Identifiable, Equatable {
    let id: UUID
    let code: String
    let sender: String
    let message: String
    let timestamp: Date
    
    init(id: UUID = UUID(), code: String, sender: String, message: String, timestamp: Date) {
        self.id = id
        self.code = code
        self.sender = sender
        self.message = message
        self.timestamp = timestamp
    }
    
    /// 从短信内容中提取发送方名称（公司/部门），找不到则返回发件人号码
    var displaySender: String {
        if let name = Self.extractSenderName(from: message) {
            return name
        }
        return sender
    }
    
    /// 从短信内容中提取【...】或 [...] 中的发送方名称
    static func extractSenderName(from text: String) -> String? {
        // 1. 匹配中文方括号：【支付宝】、【XX银行】等
        let cnBracketPattern = #"【(.+?)】"#
        if let regex = try? NSRegularExpression(pattern: cnBracketPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: text) {
            let name = String(text[range]).trimmingCharacters(in: .whitespaces)
            if name.count >= 2 && name.count <= 30 { return name }
        }
        
        // 2. 匹配英文方括号：[Alibaba]、[Google] 等
        let enBracketPattern = #"\[(.+?)\]"#
        if let regex = try? NSRegularExpression(pattern: enBracketPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: text) {
            let name = String(text[range]).trimmingCharacters(in: .whitespaces)
            if name.count >= 2 && name.count <= 30 { return name }
        }
        
        // 3. 匹配 "Apple" 开头的常见英文发送方
        let applePattern = #"^(Apple)\b"#
        if let regex = try? NSRegularExpression(pattern: applePattern, options: []),
           regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
            return "Apple"
        }
        
        // 4. 匹配 "【" 开头到 "】" 或中文冒号之间的内容
        let prefixPattern = #"^【(.+?)】"#
        if let regex = try? NSRegularExpression(pattern: prefixPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: text) {
            let name = String(text[range]).trimmingCharacters(in: .whitespaces)
            if name.count >= 2 && name.count <= 30 { return name }
        }
        
        return nil
    }
}
