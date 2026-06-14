---
name: swift-menubar-app-optimization
description: Optimize single-file Swift macOS menu bar apps by refactoring into modular architecture, fixing database safety issues, and adding incremental build support
source: auto-skill
extracted_at: '2026-06-14T04:27:44.301Z'
---

# Swift Menu Bar App Optimization

## When to apply

- User has a small macOS menu bar app written primarily in one or two Swift files
- The app reads from SQLite databases (e.g., Messages chat.db)
- Build scripts lack incremental compilation or version management
- Code mixes UI, business logic, and permissions handling in a single file

## Procedure

### 1. Split monolithic source into focused modules

| File | Responsibility |
|------|---------------|
| `main.swift` | App entry point + AppDelegate only |
| `AppConstants.swift` | All magic numbers, strings, intervals, regex patterns |
| `MenuBuilder.swift` | Menu UI construction, hover effects, detail panels |
| `PermissionManager.swift` | Full Disk Access + Notification permission checks/alerts |
| `CodeReaderManager.swift` (domain-specific) | Core business logic |
| `Models.swift` | Data models |

Key: `MenuBuilder` and `PermissionManager` are reusable across any menu bar app. Domain-specific managers (like `CodeReaderManager`) stay per-project.

### 2. Connect static action targets to the menu

Use a static `MenuActions` class inside `MenuBuilder.swift` that holds weak references to the manager and a rebuild callback. This avoids needing the AppDelegate as the target for every menu item.

```swift
@objc class MenuActions: NSObject {
    static weak var manager: SomeManager?
    static var rebuildMenu: (() -> Void)?
    // @objc static func actions...
}
```

In AppDelegate setup:
```swift
MenuActions.manager = manager
MenuActions.rebuildMenu = { [weak self] in self?.rebuildMenu() }
```

### 3. Fix SQLite database handling

**Problem**: Opening/closing the database on every query is slow and risks lock conflicts with the Messages app.

**Solution**: Maintain a persistent connection opened with `SQLITE_OPEN_READONLY`:

```swift
private var dbConnection: OpaquePointer?

private func getDatabaseConnection() -> OpaquePointer? {
    if let existing = dbConnection { return existing }
    var db: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY  // Critical: avoids lock conflicts
    if sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK {
        dbConnection = db
        return db
    }
    return nil
}

deinit {
    if let db = dbConnection { sqlite3_close(db) }
}
```

### 4. Fix SQL injection in parameterized queries

**Problem**: Direct string interpolation of `lastMessageID` into SQL:
```swift
// BAD
let query = "WHERE m.rowid > \(lastMessageID)"
```

**Solution**: Use parameterized queries with `sqlite3_bind_int64`:
```swift
// GOOD
let query = "WHERE m.rowid > ?"
// ... after prepare ...
sqlite3_bind_int64(stmt, 1, lastMessageID)
```

Create a generic `executeQuery` helper that accepts a `[Any]` params array and binds Int64/String values by index.

### 5. Add incremental compilation to build script

Check source file modification times against the binary before compiling:

```bash
NEED_COMPILE=true
if [ -f "$BINARY_PATH" ]; then
    BINARY_MTIME=$(stat -f %m "$BINARY_PATH")
    SOURCE_MTIME=0
    for src in "$SCRIPT_DIR/Sources/"*.swift; do
        SRC_MTIME=$(stat -f %m "$src")
        [ "$SRC_MTIME" -gt "$SOURCE_MTIME" ] && SOURCE_MTIME=$SRC_MTIME
    done
    [ "$BINARY_MTIME" -ge "$SOURCE_MTIME" ] && NEED_COMPILE=false
fi
```

### 6. Auto-generate Info.plist during build

Embed a heredoc in the build script to generate `Info.plist` with:
- `CFBundleIdentifier` (required for notifications)
- `CFBundleVersion` / `CFBundleShortVersionString`
- `LSUIElement = true` (menu bar app, no Dock icon)
- `LSMinimumSystemVersion`
- Permission usage descriptions

### 7. Add Makefile wrapper

Provide standard targets: `build`, `run`, `clean`, `dmg`, `release`, `help`. Pass through `APP_VERSION` and `BUILD_MODE` variables to shell scripts.

## Pitfalls

- **Missing `import UserNotifications`**: The `MenuBuilder` file needs this import if it sends notifications — easy to forget when splitting files.
- **`[weak self]` warnings**: Remove `weak self` in closures where `self` is never actually used (compiler warns but doesn't error).
- **`sqlite3_open` vs `sqlite3_open_v2`**: Use `open_v2` with explicit flags; plain `open` defaults to readwrite which can lock out the Messages app.
- **Apple epoch offset**: Messages `date` column uses Apple's epoch (2001-01-01), add `978307200` seconds to convert to Unix timestamp.
