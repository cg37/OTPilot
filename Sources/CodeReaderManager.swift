import Foundation
import AppKit
import UserNotifications
import SQLite3

class CodeReaderManager: ObservableObject {
    @Published var codes: [VerificationCode] = []
    @Published var hasNewCode: Bool = false
    
    private var timer: Timer?
    private var lastMessageID: Int64 = 0
    private let messagesDBPath = "~/Library/Messages/chat.db"
    
    init() {
        requestNotificationPermission()
        loadExistingCodes()
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        let group = DispatchGroup()
        group.enter()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
            group.leave()
        }
        
        _ = group.wait(timeout: .now() + 5)
    }
    
    // MARK: - Database Reading
    private func getMessagesDBPath() -> String {
        return (messagesDBPath as NSString).expandingTildeInPath
    }
    
    func loadExistingCodes() {
        guard let dbPath = getMessagesDB(), let conn = openDatabase(dbPath) else {
            print("无法打开 Messages 数据库，请确保:")
            print("1. 已启用 iCloud 短信同步")
            print("2. 已授予全磁盘访问权限")
            print("数据库路径: \(getMessagesDBPath())")
            return
        }
        defer { sqlite3_close(conn) }
        
        let query = """
            SELECT m.rowid, h.id, m.text, m.date
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.text IS NOT NULL
            AND m.is_from_me = 0
            ORDER BY m.date DESC
            LIMIT 100
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, query, -1, &stmt, nil) == SQLITE_OK else {
            print("SQL 准备失败: \(String(cString: sqlite3_errmsg(conn)))")
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        var newCodes: [VerificationCode] = []
        var maxID: Int64 = 0
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(stmt, 0)
            let senderPtr = sqlite3_column_text(stmt, 1)
            let textPtr = sqlite3_column_text(stmt, 2)
            
            guard let senderPtr = senderPtr, let textPtr = textPtr else { continue }
            
            let sender = String(cString: senderPtr)
            let text = String(cString: textPtr)
            let date = sqlite3_column_double(stmt, 3) + 978307200
            
            if rowID > maxID { maxID = rowID }
            
            if let code = extractVerificationCode(text) {
                let vc = VerificationCode(
                    code: code,
                    sender: sender,
                    message: text,
                    timestamp: Date(timeIntervalSince1970: date)
                )
                newCodes.append(vc)
            }
        }
        
        lastMessageID = maxID
        self.codes = newCodes.prefix(20).map { $0 }
        print("已加载 \(self.codes.count) 条验证码记录")
    }
    
    private func getMessagesDB() -> String? {
        let path = getMessagesDBPath()
        guard FileManager.default.fileExists(atPath: path) else {
            print("数据库文件不存在: \(path)")
            return nil
        }
        return path
    }
    
    private func openDatabase(_ path: String) -> OpaquePointer? {
        var db: OpaquePointer?
        if sqlite3_open(path, &db) == SQLITE_OK {
            return db
        }
        sqlite3_close(db)
        return nil
    }
    
    // MARK: - Verification Code Extraction
    func extractVerificationCode(_ text: String) -> String? {
        let patterns = [
            #"(?:验证码|校验码|确认码|安全码|动态码|激活码)[：:\s]*(\d{4,8})"#,
            #"(?:code|Code|CODE)[：:\s]*(\d{4,8})"#,
            #"(?:验证码|code|Code)[^\d]{0,10}(\d{4,8})"#,
            #"\b(\d{4,6})\b"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                if match.numberOfRanges >= 2 {
                    let codeRange = match.range(at: 1)
                    if let range = Range(codeRange, in: text) {
                        let code = String(text[range])
                        if code.count >= 4 && code.count <= 8 {
                            return code
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Monitoring
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkForNewMessages()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func checkForNewMessages() {
        guard let dbPath = getMessagesDB(), let conn = openDatabase(dbPath) else {
            return
        }
        defer { sqlite3_close(conn) }
        
        let query = """
            SELECT m.rowid, h.id, m.text, m.date
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.rowid
            WHERE m.rowid > \(lastMessageID)
            AND m.text IS NOT NULL
            AND m.is_from_me = 0
            ORDER BY m.date ASC
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, query, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(stmt, 0)
            let senderPtr = sqlite3_column_text(stmt, 1)
            let textPtr = sqlite3_column_text(stmt, 2)
            
            guard let senderPtr = senderPtr, let textPtr = textPtr else { continue }
            
            let sender = String(cString: senderPtr)
            let text = String(cString: textPtr)
            let date = sqlite3_column_double(stmt, 3) + 978307200
            
            if rowID > lastMessageID {
                lastMessageID = rowID
            }
            
            if let code = extractVerificationCode(text) {
                let vc = VerificationCode(
                    code: code,
                    sender: sender,
                    message: text,
                    timestamp: Date(timeIntervalSince1970: date)
                )
                
                codes.insert(vc, at: 0)
                if codes.count > 50 { codes.removeLast() }
                
                copyToClipboard(code)
                sendNotification(for: vc)
                
                hasNewCode = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.hasNewCode = false
                }
                
                print("检测到验证码: \(code) 来自: \(vc.displaySender)")
            }
        }
    }
    
    // MARK: - Clipboard
    func copyToClipboard(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        print("验证码已复制到剪贴板: \(code)")
    }
    
    // MARK: - Notification
    private func sendNotification(for vc: VerificationCode) {
        let content = UNMutableNotificationContent()
        content.title = "🔐 验证码已复制"
        content.body = "来自 \(vc.displaySender): \(vc.code)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshCodes() {
        loadExistingCodes()
    }
}
