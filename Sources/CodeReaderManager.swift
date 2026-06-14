import Foundation
import AppKit
import UserNotifications
import SQLite3

/// 验证码管理器：负责数据库读取、验证码匹配和监控
final class CodeReaderManager {
    @Published var codes: [VerificationCode] = []
    @Published var hasNewCode: Bool = false
    
    private var timer: Timer?
    private var lastMessageID: Int64 = 0
    private var dbConnection: OpaquePointer?
    
    init() {
        loadExistingCodes()
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
        closeDatabase()
    }
    
    // MARK: - 数据库连接管理
    
    private func getMessagesDBPath() -> String {
        return (AppConstants.messagesDBPath as NSString).expandingTildeInPath
    }
    
    /// 获取或创建持久数据库连接
    private func getDatabaseConnection() -> OpaquePointer? {
        if let existing = dbConnection {
            return existing
        }
        
        let path = getMessagesDBPath()
        guard FileManager.default.fileExists(atPath: path) else {
            print("⚠️ 数据库文件不存在: \(path)")
            return nil
        }
        
        var db: OpaquePointer?
        // 使用 SQLITE_OPEN_READONLY 避免锁冲突
        let flags = SQLITE_OPEN_READONLY
        if sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK {
            dbConnection = db
            print("✅ 数据库连接已建立")
            return db
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("⚠️ 数据库打开失败: \(error)")
            sqlite3_close(db)
            return nil
        }
    }
    
    private func closeDatabase() {
        if let db = dbConnection {
            sqlite3_close(db)
            dbConnection = nil
            print("🔒 数据库连接已关闭")
        }
    }
    
    /// 执行查询的通用方法
    private func executeQuery(_ query: String, params: [Any] = []) -> OpaquePointer? {
        guard let conn = getDatabaseConnection() else { return nil }
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, query, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(conn))
            print("⚠️ SQL 准备失败: \(error)")
            print("   查询: \(query)")
            return nil
        }
        
        // 绑定参数
        for (index, param) in params.enumerated() {
            let sqlIndex = Int32(index + 1)
            if let intValue = param as? Int64 {
                sqlite3_bind_int64(stmt, sqlIndex, intValue)
            } else if let stringValue = param as? String {
                sqlite3_bind_text(stmt, sqlIndex, stringValue, -1, nil)
            }
        }
        
        return stmt
    }
    
    // MARK: - 验证码加载
    
    func loadExistingCodes() {
        // 先输出调试信息：查看数据库中实际的消息
        printDebugMessages()
        
        let query = """
            SELECT m.rowid, h.id, m.text, m.date
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.text IS NOT NULL
            AND m.is_from_me = 0
            ORDER BY m.date DESC
            LIMIT 100
        """

        guard let stmt = executeQuery(query) else {
            NSLog("⚠️ 无法加载验证码，请确保:")
            NSLog("   1. 已启用 iCloud 短信同步")
            NSLog("   2. 已授予全磁盘访问权限")
            return
        }
        defer { sqlite3_finalize(stmt) }

        var newCodes: [VerificationCode] = []
        var maxID: Int64 = 0
        var totalMessagesScanned = 0

        while sqlite3_step(stmt) == SQLITE_ROW {
            totalMessagesScanned += 1
            let rowID = sqlite3_column_int64(stmt, 0)
            guard let senderPtr = sqlite3_column_text(stmt, 1),
                  let textPtr = sqlite3_column_text(stmt, 2) else { continue }

            let sender = String(cString: senderPtr)
            let text = String(cString: textPtr)
            // Apple date 是纳秒级时间戳，需要转换为秒
            let dateInSeconds = sqlite3_column_double(stmt, 3) / 1_000_000_000.0
            let unixTimestamp = dateInSeconds + 978307200  // Apple epoch (2001-01-01) to Unix epoch (1970-01-01)

            if rowID > maxID { maxID = rowID }

            if let code = extractVerificationCode(text) {
                let vc = VerificationCode(
                    code: code,
                    sender: sender,
                    message: text,
                    timestamp: Date(timeIntervalSince1970: unixTimestamp)
                )
                newCodes.append(vc)
            }
        }

        lastMessageID = maxID
        self.codes = Array(newCodes.prefix(AppConstants.maxHistoryCodes))
        NSLog("📥 扫描了 \(totalMessagesScanned) 条消息，加载了 \(self.codes.count) 条验证码记录")
    }
    
    /// 调试：输出最近消息到文件，帮助排查问题
    private func printDebugMessages() {
        // 先查看数据库的 date 列实际存储情况
        let dateCheckQuery = """
            SELECT m.rowid, m.date, typeof(m.date), h.id, substr(m.text, 1, 50)
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.text IS NOT NULL
            ORDER BY m.rowid DESC
            LIMIT 10
        """
        
        if let stmt = executeQuery(dateCheckQuery) {
            defer { sqlite3_finalize(stmt) }
            NSLog("=== Date 列类型检查 ===")
            while sqlite3_step(stmt) == SQLITE_ROW {
                let rowid = sqlite3_column_int64(stmt, 0)
                let dateVal = sqlite3_column_double(stmt, 1)
                let dateType = String(cString: sqlite3_column_text(stmt, 2))
                let sender = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : "(nil)"
                let textPreview = String(cString: sqlite3_column_text(stmt, 4))
                
                NSLog("  rowid=\(rowid) date=\(dateVal) (typeof: \(dateType)) sender=\(sender)")
                NSLog("    text=\(textPreview)")
            }
            NSLog("=== Date 列检查结束 ===")
        }
        
        // 统计信息
        let statsQuery = """
            SELECT COUNT(*) as total,
                   SUM(CASE WHEN m.date IS NULL OR m.date = 0 THEN 1 ELSE 0 END) as no_date,
                   SUM(CASE WHEN m.date > 0 THEN 1 ELSE 0 END) as has_date,
                   MAX(m.date) as max_date,
                   MIN(m.date) as min_date
            FROM message m
            WHERE m.text IS NOT NULL
        """

        if let stmt = executeQuery(statsQuery) {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                let total = sqlite3_column_int(stmt, 0)
                let noDate = sqlite3_column_int(stmt, 1)
                let hasDate = sqlite3_column_int(stmt, 2)
                let maxDate = sqlite3_column_double(stmt, 3)
                let minDate = sqlite3_column_double(stmt, 4)

                if maxDate > 0 {
                    // Apple date 是纳秒，需要转换为秒
                    let maxDateInSeconds = maxDate / 1_000_000_000.0
                    let minDateInSeconds = minDate / 1_000_000_000.0
                    let maxDateObj = Date(timeIntervalSince1970: maxDateInSeconds + 978307200)
                    let minDateObj = Date(timeIntervalSince1970: minDateInSeconds + 978307200)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let maxStr = formatter.string(from: maxDateObj)
                    let minStr = formatter.string(from: minDateObj)
                    NSLog("📊 数据库统计: 共 \(total) 条, 有日期: \(hasDate), 无日期: \(noDate)")
                    NSLog("📊 消息时间范围: 最早 \(minStr) → 最新 \(maxStr)")
                } else {
                    NSLog("📊 数据库统计: 共 \(total) 条, 有日期: \(hasDate), 无日期: \(noDate), 最新日期: 无有效日期")
                }
            }
        }
        
        // 查找小米相关短信
        let xiaomiQuery = """
            SELECT m.rowid, h.id, m.text, m.date, m.is_from_me
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.text LIKE '%小米%' OR m.text LIKE '%323506%' OR m.text LIKE '%246337%'
            ORDER BY m.date DESC
            LIMIT 10
        """
        
        if let stmt = executeQuery(xiaomiQuery) {
            defer { sqlite3_finalize(stmt) }
            NSLog("=== 小米相关短信 ===")
            var xiaomiCount = 0
            while sqlite3_step(stmt) == SQLITE_ROW {
                xiaomiCount += 1
                let rowid = sqlite3_column_int64(stmt, 0)
                let sender = sqlite3_column_text(stmt, 1) != nil ? String(cString: sqlite3_column_text(stmt, 1)) : "(nil)"
                let text = String(cString: sqlite3_column_text(stmt, 2))
                let date = sqlite3_column_double(stmt, 3)
                let isFromMe = sqlite3_column_int(stmt, 4)
                
                let dateInSeconds = date / 1_000_000_000.0
                let dateObj = Date(timeIntervalSince1970: dateInSeconds + 978307200)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let timeStr = formatter.string(from: dateObj)
                
                let direction = isFromMe == 1 ? "📤发送" : "📥接收"
                NSLog("  [\(xiaomiCount)] rowid=\(rowid) \(direction) \(sender) \(timeStr)")
                NSLog("      \(text)")
            }
            if xiaomiCount == 0 {
                NSLog("  ⚠️ 数据库中没有找到小米相关短信！可能还没同步到 Mac")
            }
            NSLog("=== 小米短信查询结束 ===")
        }
        
        // 按 rowid 排序查看最近的消息
        let debugQuery = """
            SELECT m.rowid, h.id, m.text, m.date, m.is_from_me
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.text IS NOT NULL
            ORDER BY m.rowid DESC
            LIMIT 20
        """
        
        guard let stmt = executeQuery(debugQuery) else {
            NSLog("⚠️ 无法执行调试查询")
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        var debugLines: [String] = []
        debugLines.append("=== 按 rowid 排序最近 20 条消息 ===")
        
        var count = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            count += 1
            let rowid = sqlite3_column_int64(stmt, 0)
            let sender = sqlite3_column_text(stmt, 1) != nil ? String(cString: sqlite3_column_text(stmt, 1)) : "(nil)"
            let text = String(cString: sqlite3_column_text(stmt, 2))
            let date = sqlite3_column_double(stmt, 3)
            let isFromMe = sqlite3_column_int(stmt, 4)
            
            let timeStr: String
            if date > 0 {
                // Apple date 是纳秒，需要转换为秒
                let dateInSeconds = date / 1_000_000_000.0
                let dateObj = Date(timeIntervalSince1970: dateInSeconds + 978307200)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                timeStr = formatter.string(from: dateObj)
            } else {
                timeStr = "(无日期 date=\(date))"
            }
            
            let direction = isFromMe == 1 ? "📤发送" : "📥接收"
            let displayText = text.count > 100 ? String(text.prefix(100)) + "..." : text
            let hasKeyword = text.range(of: #"验证码|校验码|确认码"#, options: [.regularExpression, .caseInsensitive]) != nil ? "⭐" : ""
            
            debugLines.append("  [\(count)] rowid=\(rowid) \(direction) \(sender) \(timeStr) \(hasKeyword)")
            debugLines.append("      \(displayText)")
        }
        debugLines.append("=== 调试结束 ===")
        
        // 写入文件
        let debugContent = debugLines.joined(separator: "\n")
        let debugPath = "/tmp/otpilot_debug.log"
        try? debugContent.write(toFile: debugPath, atomically: true, encoding: .utf8)
        
        for line in debugLines {
            NSLog(line)
        }
    }
    
    // MARK: - 验证码提取
    
    func extractVerificationCode(_ text: String) -> String? {
        // 第一关: 短信必须包含至少一个验证码关键词，否则直接跳过
        let keywordCheck = #"验证码|校验码|确认码|安全码|动态码|激活码|登录码|注册码|身份验证码|verification\s*code"#
        guard text.range(of: keywordCheck, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        
        // 第二关: 排除含手机号/订单号等非验证码内容的短信
        for exclusionPattern in AppConstants.exclusionPatterns {
            if text.range(of: exclusionPattern, options: .regularExpression) != nil {
                return nil
            }
        }
        
        // 第三关: 用精确的验证码模式匹配
        for pattern in AppConstants.verificationCodePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(
                    in: text,
                    options: [],
                    range: NSRange(text.startIndex..., in: text)
                  ),
                  match.numberOfRanges >= 2,
                  let codeRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            
            let code = String(text[codeRange])
            if (AppConstants.minCodeLength...AppConstants.maxCodeLength).contains(code.count) {
                // 最后确认: code 本身不是手机号片段的一部分
                if isContainedInPhoneMask(text, code: code) {
                    continue
                }
                return code
            }
        }
        return nil
    }
    
    /// 检查 code 是否被包裹在手机号掩码中（如 166***6012）
    private func isContainedInPhoneMask(_ text: String, code: String) -> Bool {
        // 查找 code 在原文中出现的位置，检查前后是否有手机号掩码特征
        let maskPatterns = [
            #"\d{3}\*{2,4}\#(code)\b"#,
            #"\b\#(code)\*{2,4}\d{3,4}"#,
        ]
        for pattern in maskPatterns {
            let filledPattern = pattern.replacingOccurrences(of: "#(code)", with: code)
            if text.range(of: filledPattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    // MARK: - 监控
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.monitorInterval, repeats: true) { [weak self] _ in
            self?.checkForNewMessages()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func checkForNewMessages() {
        // 使用参数化查询防止 SQL 注入
        let query = """
            SELECT m.rowid, h.id, m.text, m.date
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.rowid > ?
            AND m.text IS NOT NULL
            AND m.is_from_me = 0
            ORDER BY m.date ASC
        """
        
        guard let stmt = executeQuery(query, params: [lastMessageID]) else { return }
        defer { sqlite3_finalize(stmt) }
        
        var foundNewCode = false
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(stmt, 0)
            guard let senderPtr = sqlite3_column_text(stmt, 1),
                  let textPtr = sqlite3_column_text(stmt, 2) else { continue }
            
            let sender = String(cString: senderPtr)
            let text = String(cString: textPtr)
            // Apple date 是纳秒级时间戳，需要转换为秒
            let dateInSeconds = sqlite3_column_double(stmt, 3) / 1_000_000_000.0
            let unixTimestamp = dateInSeconds + 978307200
            
            if rowID > lastMessageID {
                lastMessageID = rowID
            }
            
            if let code = extractVerificationCode(text) {
                let vc = VerificationCode(
                    code: code,
                    sender: sender,
                    message: text,
                    timestamp: Date(timeIntervalSince1970: unixTimestamp)
                )
                
                codes.insert(vc, at: 0)
                if codes.count > AppConstants.maxHistoryCodes {
                    codes.removeLast()
                }
                
                copyToClipboard(code)
                sendNotification(for: vc)
                
                hasNewCode = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.hasNewCode = false
                }
                
                foundNewCode = true
                print("🔔 检测到验证码: \(code) 来自: \(vc.displaySender)")
            }
        }
        
        if !foundNewCode {
            // 静默检查，不输出日志
        }
    }
    
    // MARK: - 剪贴板
    
    func copyToClipboard(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        print("📋 验证码已复制到剪贴板: \(code)")
    }
    
    // MARK: - 通知
    
    private func sendNotification(for vc: VerificationCode) {
        let content = UNMutableNotificationContent()
        content.title = "🔐 验证码已复制"
        content.body = "来自 \(vc.displaySender): \(vc.code)"
        content.sound = nil
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ 通知发送失败: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshCodes() {
        print("🔄 手动刷新验证码...")
        loadExistingCodes()
    }
}
