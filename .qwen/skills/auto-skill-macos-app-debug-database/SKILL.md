---
name: macos-app-debug-database
description: Debug macOS app SQLite database access and message filtering — using NSLog, /tmp/ debug files, and Console.app to diagnose Full Disk Access and query issues
source: auto-skill
extracted_at: '2026-06-14T12:23:01.073Z'
---

# Debugging macOS App SQLite Database Access

When a macOS app reads from a protected database (like `~/Library/Messages/chat.db`), follow this debugging approach:

## 1. Use NSLog instead of print

`print()` output goes to stdout/stderr which is not visible in Console.app for GUI apps launched via Finder or `open`. Use `NSLog()` to write to the unified logging system:

```swift
// ❌ Won't appear in Console.app
print("Loaded \(count) records")

// ✅ Appears in Console.app under the process name
NSLog("Loaded \(count) records")
```

## 2. Write debug output to /tmp/

For structured debug data, write to `/tmp/` which is accessible without special permissions:

```swift
let debugContent = debugLines.joined(separator: "\n")
try? debugContent.write(toFile: "/tmp/appname_debug.log", atomically: true, encoding: .utf8)
```

Read it with: `cat /tmp/appname_debug.log`

## 3. Full Disk Access diagnosis

If you see `Operation not permitted` when opening a database:
- The app lacks Full Disk Access permission
- Check with: `log show --predicate 'process == "AppName"' --last 2m | grep -i "not permitted"`
- User must grant it in: System Settings → Privacy & Security → Full Disk Access → add the .app bundle

## 4. SQLite error logging

Always log SQLite errors with the query:

```swift
guard sqlite3_prepare_v2(conn, query, -1, &stmt, nil) == SQLITE_OK else {
    let error = String(cString: sqlite3_errmsg(conn))
    NSLog("⚠️ SQL prepare failed: \(error)")
    NSLog("   Query: \(query)")
    return nil
}
```

## 5. Verify what the database actually contains

Before blaming the query, dump a sample of raw data to see if the issue is:
- No matching records in the database
- Wrong filter conditions
- Missing JOIN data

```swift
// Debug query: show ALL recent records regardless of filters
let debugQuery = """
    SELECT m.rowid, h.id, m.text, m.date, m.is_from_me
    FROM message m
    LEFT JOIN handle h ON m.handle_id = h.rowid
    WHERE m.text IS NOT NULL
    ORDER BY m.date DESC
    LIMIT 15
"""
```

## 6. Common Messages.db pitfalls

- **Apple epoch offset**: `date` column needs `+ 978307200` to convert to Unix timestamp
- **handle table**: `sender` comes from `handle.id` via `message.handle_id`, may be NULL for some messages
- **iCloud sync delays**: Messages may not appear immediately if iCloud sync is slow
- **WAL files**: Check for `chat.db-wal` and `chat.db-shm` — incomplete transactions may be there
