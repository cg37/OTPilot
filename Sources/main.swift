import Foundation
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var manager: CodeReaderManager!
    var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限并检查状态
        requestNotificationPermission()
        
        // 初始化验证码管理器
        manager = CodeReaderManager()
        
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon()
        
        // 创建菜单
        menu = NSMenu()
        statusItem.menu = menu
        
        updateMenu()
        
        // 定期更新菜单
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }
        
        print("SMSCodeReader 已启动")
        print("正在监控短信验证码...")
        
        // 延迟检查权限（等菜单栏图标就绪后再弹窗）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAndRequestFullDiskAccess()
        }
    }
    
    func updateStatusItemIcon() {
        if let button = statusItem.button {
            if manager?.hasNewCode == true {
                button.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: "新验证码")
            } else {
                button.image = NSImage(systemSymbolName: "message", accessibilityDescription: "验证码监控")
            }
            button.image?.isTemplate = true
        }
    }
    
    func updateMenu() {
        menu.removeAllItems()
        
        updateStatusItemIcon()
        
        // 标题
        let titleItem = NSMenuItem(title: "验证码监控", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 最新验证码
        if let codes = manager?.codes, !codes.isEmpty {
            let headerView = makeCodeItemView(code: "验证码", sender: "来源", isHeader: true)
            let headerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            headerItem.view = headerView
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            
            for (index, code) in codes.prefix(5).enumerated() {
                let itemView = makeCodeItemView(code: code.code, sender: code.displaySender, isHeader: false)
                let item = NSMenuItem(title: "", action: #selector(copyCode(_:)), keyEquivalent: "")
                item.view = itemView
                item.representedObject = code.code
                item.tag = index
                menu.addItem(item)
            }
            
            if codes.count > 5 {
                let moreItem = NSMenuItem(title: "... 还有 \(codes.count - 5) 条", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        } else {
            let noCodeItem = NSMenuItem(title: "暂无验证码", action: nil, keyEquivalent: "")
            noCodeItem.isEnabled = false
            menu.addItem(noCodeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 操作菜单
        let refreshItem = NSMenuItem(title: "刷新", action: #selector(refreshCodes), keyEquivalent: "r")
        menu.addItem(refreshItem)
        
        let copyLatestItem = NSMenuItem(title: "复制最新验证码", action: #selector(copyLatestCode), keyEquivalent: "c")
        menu.addItem(copyLatestItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let permissionItem = NSMenuItem(title: "权限设置", action: #selector(openFullDiskAccessSettings), keyEquivalent: "")
        menu.addItem(permissionItem)
        
        let notifyDiagItem = NSMenuItem(title: "通知诊断", action: #selector(diagnoseNotificationStatus), keyEquivalent: "")
        menu.addItem(notifyDiagItem)
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
    
    @objc func copyCode(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String {
            manager.copyToClipboard(code)
            showCopiedNotification(code: code)
        }
    }
    
    @objc func refreshCodes() {
        manager.refreshCodes()
        updateMenu()
    }
    
    @objc func copyLatestCode() {
        if let latestCode = manager.codes.first {
            manager.copyToClipboard(latestCode.code)
            showCopiedNotification(code: latestCode.code)
        }
    }
    
    private func showCopiedNotification(code: String) {
        let content = UNMutableNotificationContent()
        content.title = "📋 已复制到剪贴板"
        content.body = "验证码: \(code)"
        content.sound = nil
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - 通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
                return
            }
            if granted {
                print("✅ 通知权限已授予")
                // 发送一条静默通知让 app 注册到系统通知列表
                self?.registerAppInNotificationCenter()
            } else {
                print("⚠️ 未获得通知权限")
                DispatchQueue.main.async {
                    self?.showNotificationDeniedAlert()
                }
            }
        }
    }
    
    /// 发送一条即时消失的静默通知，让 app 出现在系统设置 > 通知列表中
    private func registerAppInNotificationCenter() {
        let content = UNMutableNotificationContent()
        content.title = "SMSCodeReader"
        content.body = "验证码监控已就绪"
        content.sound = nil
        
        let request = UNNotificationRequest(
            identifier: "app-register",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("注册通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 已在通知中心注册")
            }
        }
    }
    
    private func showNotificationDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "需要通知权限"
        alert.informativeText = """
        SMSCodeReader 需要通知权限才能显示验证码复制提醒。
        
        请前往系统设置开启通知。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开通知设置")
        alert.addButton(withTitle: "稍后")
        alert.icon = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openNotificationSettings()
        }
    }
    
    @objc func openNotificationSettings() {
        // macOS 13+ 通知设置
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 诊断当前通知权限状态
    @objc func diagnoseNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let status: String
                switch settings.authorizationStatus {
                case .notDetermined:
                    status = "未请求"
                case .denied:
                    status = "已拒绝"
                case .authorized:
                    status = "已授权"
                case .provisional:
                    status = "临时授权"
                case .ephemeral:
                    status = "App Clips 授权"
                @unknown default:
                    status = "未知"
                }
                
                let alert = NSAlert()
                alert.messageText = "通知权限状态"
                alert.informativeText = """
                当前状态: \(status)
                弹窗样式: \(settings.alertSetting == .enabled ? "横幅" : "关闭")
                提示音: \(settings.soundSetting == .enabled ? "开启" : "关闭")
                角标: \(settings.badgeSetting == .enabled ? "开启" : "关闭")
                
                如果在系统设置中找不到本应用，
                请尝试点击下方按钮发送一条测试通知。
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "发送测试通知")
                alert.addButton(withTitle: "打开通知设置")
                alert.addButton(withTitle: "关闭")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.showCopiedNotification(code: "000000")
                } else if response == .alertSecondButtonReturn {
                    self.openNotificationSettings()
                }
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - 权限检查
    private func checkAndRequestFullDiskAccess() {
        let dbPath = ("~/Library/Messages/chat.db" as NSString).expandingTildeInPath
        
        // 检查数据库文件是否存在
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("Messages 数据库不存在: \(dbPath)")
            print("请确保已启用 iCloud 短信同步")
            return
        }
        
        // 尝试用 POSIX open() 读取文件 — 无全磁盘访问会返回 -1
        let fd = open(dbPath, O_RDONLY)
        if fd != -1 {
            close(fd)
            print("✅ 全磁盘访问权限正常")
            return
        }
        
        let err = errno
        print("⚠️ 无法读取 Messages 数据库, errno: \(err)")
        showFullDiskAccessAlert()
    }
    
    private func showFullDiskAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "需要全磁盘访问权限"
        alert.informativeText = """
        SMSCodeReader 需要"全磁盘访问"权限才能读取短信中的验证码。
        
        请在系统设置中授予权限后，返回本应用刷新即可。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        alert.icon = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openFullDiskAccessSettings()
        }
    }
    
    @objc func openFullDiskAccessSettings() {
        // macOS 13+ URL scheme for Privacy > Full Disk Access
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Custom Menu Item View
    
    /// 可响应点击的自定义菜单视图，将点击转发给所在的 NSMenuItem
    private class MenuItemView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            return self
        }
        
        override func mouseUp(with event: NSEvent) {
            super.mouseUp(with: event)
            guard let item = enclosingMenuItem, item.action != nil else { return }
            NSApp.sendAction(item.action!, to: item.target, from: item)
            item.menu?.cancelTracking()
        }
    }
    
    private func makeCodeItemView(code: String, sender: String, isHeader: Bool) -> NSView {
        let container = MenuItemView(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        
        let codeLabel = NSTextField(labelWithString: code)
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        codeLabel.font = isHeader
            ? NSFont.menuBarFont(ofSize: NSFont.smallSystemFontSize)
            : NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        codeLabel.textColor = isHeader ? .secondaryLabelColor : .labelColor
        codeLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(codeLabel)
        
        let senderLabel = NSTextField(labelWithString: sender)
        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        senderLabel.font = isHeader
            ? NSFont.menuBarFont(ofSize: NSFont.smallSystemFontSize)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        senderLabel.textColor = isHeader ? .secondaryLabelColor : .secondaryLabelColor
        senderLabel.lineBreakMode = .byTruncatingTail
        senderLabel.alignment = .right
        container.addSubview(senderLabel)
        
        NSLayoutConstraint.activate([
            // 验证码左对齐
            codeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            codeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            codeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),
            
            // 来源右对齐
            senderLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            senderLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            senderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: codeLabel.trailingAnchor, constant: 16),
            senderLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100)
        ])
        
        return container
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
