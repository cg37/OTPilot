#!/usr/bin/env swift
import Foundation
import SQLite3

let dbPath = NSHomeDirectory() + "/Library/Messages/chat.db"

guard FileManager.default.fileExists(atPath: dbPath) else {
    print("❌ 数据库文件不存在: \(dbPath)")
    exit(1)
}

var db: OpaquePointer?
let flags = SQLITE_OPEN_READONLY
if sqlite3_open_v2(dbPath, &db, flags, nil) != SQLITE_OK {
    print("❌ 无法打开数据库")
    exit(1)
}

print("✅ 数据库连接成功\n")

// 1. 查看最近的 10 条消息（包括所有字段）
print("=== 最近 10 条消息 ===")
let query = """
    SELECT m.rowid, m.cache_has_attachments, m.cache_has_photos, m.cache_has_videos, m.cache_has_audio, m.is_from_me, h.id, m.text, m.date, m.service
    FROM message m
    LEFT JOIN handle h ON m.handle_id = h.rowid
    ORDER BY m.date DESC
    LIMIT 10
"""

var stmt: OpaquePointer?
if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let rowid = sqlite3_column_int64(stmt, 0)
        let hasAttachments = sqlite3_column_int(stmt, 1)
        let hasPhotos = sqlite3_column_int(stmt, 2)
        let hasVideos = sqlite3_column_int(stmt, 3)
        let hasAudio = sqlite3_column_int(stmt, 4)
        let isFromMe = sqlite3_column_int(stmt, 5)
        
        let sender = String(cString: sqlite3_column_text(stmt, 6))
        let text = sqlite3_column_text(stmt, 7) != nil ? String(cString: sqlite3_column_text(stmt, 7)) : "(nil)"
        let date = sqlite3_column_double(stmt, 8)
        let service = sqlite3_column_text(stmt, 9) != nil ? String(cString: sqlite3_column_text(stmt, 9)) : "unknown"
        
        let dateObj = Date(timeIntervalSince1970: date + 978307200)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeStr = dateFormatter.string(from: dateObj)
        
        let direction = isFromMe == 1 ? "发送" : "接收"
        let displayText = text.count > 50 ? String(text.prefix(50)) + "..." : text
        
        print("rowid=\(rowid) [\(direction)] 来自: \(sender) 时间: \(timeStr) 服务: \(service)")
        print("  附件: photo=\(hasPhotos) video=\(hasVideos) audio=\(hasAudio) other=\(hasAttachments)")
        print("  内容: \(displayText)")
        print()
    }
    sqlite3_finalize(stmt)
}

// 2. 查看包含"验证码"关键词的消息
print("\n=== 包含验证码的消息 (最近 5 条) ===")
let codeQuery = """
    SELECT m.rowid, h.id, m.text, m.date, m.is_from_me
    FROM message m
    LEFT JOIN handle h ON m.handle_id = h.rowid
    WHERE m.text LIKE '%验证码%' OR m.text LIKE '%校验码%' OR m.text LIKE '%确认码%'
    ORDER BY m.date DESC
    LIMIT 5
"""

if sqlite3_prepare_v2(db, codeQuery, -1, &stmt, nil) == SQLITE_OK {
    var count = 0
    while sqlite3_step(stmt) == SQLITE_ROW {
        count += 1
        let rowid = sqlite3_column_int64(stmt, 0)
        let sender = String(cString: sqlite3_column_text(stmt, 1))
        let text = String(cString: sqlite3_column_text(stmt, 2))
        let date = sqlite3_column_double(stmt, 3)
        let isFromMe = sqlite3_column_int(stmt, 4)
        
        let dateObj = Date(timeIntervalSince1970: date + 978307200)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd HH:mm"
        let timeStr = dateFormatter.string(from: dateObj)
        
        let direction = isFromMe == 1 ? "发送" : "接收"
        print("[\(count)] rowid=\(rowid) [\(direction)] \(sender) \(timeStr)")
        print("    \(text)")
        print()
    }
    if count == 0 {
        print("  (没有找到包含验证码的消息)")
    }
    sqlite3_finalize(stmt)
}

sqlite3_close(db)
