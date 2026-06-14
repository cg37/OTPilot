---
name: macos-messages-db
description: Read Apple Messages (iMessage/SMS) SQLite database correctly — handling Apple epoch, nanosecond timestamps, and Full Disk Access
source: auto-skill
extracted_at: '2026-06-14T12:39:21.830Z'
---

# macOS Messages Database Reading

## Key Pitfalls

### 1. `date` column is nanoseconds, not seconds

The `message.date` column in `~/Library/Messages/chat.db` stores **nanoseconds** since the Apple epoch (2001-01-01). Most examples online treat it as seconds, which produces dates ~25 million years in the future.

**Correct conversion:**
```swift
let dateNanoseconds = sqlite3_column_double(stmt, column)
let dateInSeconds = dateNanoseconds / 1_000_000_000.0
let unixTimestamp = dateInSeconds + 978307200  // Apple epoch → Unix epoch
let date = Date(timeIntervalSince1970: unixTimestamp)
```

**Common mistake:**
```swift
// WRONG — treats nanoseconds as seconds
let date = Date(timeIntervalSince1970: sqlite3_column_double(stmt, column) + 978307200)
```

### 2. Full Disk Access is mandatory

macOS sandboxing blocks access to `~/Library/Messages/chat.db` even for non-sandboxed apps without Full Disk Access.

**Symptom:** `sqlite3_open_v2` fails with "authorization denied" or `Operation not permitted`.

**Fix:** User must add the app in System Settings → Privacy & Security → Full Disk Access.

### 3. iCloud sync delay

Messages from iPhone may take minutes to hours to sync to the Mac's `chat.db`. If a user says "I just got a text but the app doesn't see it", check if the message exists in the database first before blaming the query.

**Debug query:**
```sql
SELECT m.rowid, h.id, m.text, m.date
FROM message m
LEFT JOIN handle h ON m.handle_id = h.rowid
WHERE m.text LIKE '%keyword%'
ORDER BY m.date DESC
LIMIT 10
```

### 4. Tracking new messages: use rowid, not date

The `rowid` column is monotonically increasing and safe for incremental polling (`WHERE m.rowid > ?`). Using `date` is unreliable because iCloud sync can backfill older messages with new rowids.

**Pattern:**
```sql
-- Initial load: get the max rowid
SELECT MAX(m.rowid) FROM message m WHERE m.text IS NOT NULL

-- Poll for new messages
WHERE m.rowid > ? ORDER BY m.date ASC
```

### 5. Opening database with SQLITE_OPEN_READONLY

Always use `sqlite3_open_v2` with `SQLITE_OPEN_READONLY` flag. Using `sqlite3_open` (defaults to readwrite) can cause lock conflicts with the Messages app.

```swift
let flags = SQLITE_OPEN_READONLY
sqlite3_open_v2(path, &db, flags, nil)
```

## Useful schema fields

| Column | Type | Notes |
|--------|------|-------|
| `message.rowid` | integer | Primary key, monotonically increasing |
| `message.date` | integer | **Nanoseconds** since Apple epoch (2001-01-01) |
| `message.text` | text | SMS/iMessage body (NULL for media-only) |
| `message.is_from_me` | integer | 1=sent, 0=received |
| `message.handle_id` | integer | FK to handle.rowid |
| `handle.id` | text | Phone number or email address |
| `message.service` | text | "iMessage", "SMS", etc. |
