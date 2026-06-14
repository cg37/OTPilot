import Foundation
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var manager: CodeReaderManager!
    var menu: NSMenu!

    /// 当前高亮的 MenuItemView，用于追踪 hover 状态
    private var highlightedView: MenuItemView?
    /// hover 时在菜单左侧弹出的详情窗口
    private var detailPanel: NSPanel?
    /// 详情面板当前关联的菜单项视图
    private weak var detailPanelTarget: MenuItemView?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化验证码管理器
        manager = CodeReaderManager()

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon()

        // 创建菜单
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        updateMenu()

        // 定期更新菜单
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }

        print("OTPilot 已启动")
        print("正在监控短信验证码...")

        // 请求通知权限（延迟确保 UI 就绪）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.requestNotificationPermission()
        }

        // 延迟检查全磁盘访问权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.checkAndRequestFullDiskAccess()
        }
    }
    
    func updateStatusItemIcon() {
        if let button = statusItem.button {
            if manager?.hasNewCode == true {
                button.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: "新验证码")
            } else {
                button.image = NSImage(systemSymbolName: "message", accessibilityDescription: "OTPilot")
            }
            button.image?.isTemplate = true
        }
    }
    
    func updateMenu() {
        menu.removeAllItems()
        
        updateStatusItemIcon()
        
        // 标题
        let titleItem = NSMenuItem(title: "OTPilot", action: nil, keyEquivalent: "")
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
                let itemView = makeCodeItemView(code: code.code, sender: code.displaySender, message: code.message, timestamp: code.timestamp, isHeader: false)
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

        let notifyStatusItem = NSMenuItem(title: "通知诊断", action: #selector(diagnoseNotificationStatus), keyEquivalent: "")
        menu.addItem(notifyStatusItem)

        let resetNotifyItem = NSMenuItem(title: "重置通知权限", action: #selector(resetNotificationPermission), keyEquivalent: "")
        menu.addItem(resetNotifyItem)

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
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🔔 OTPilot 通知测试"
        content.body = "如果你能看到这条通知，说明通知权限正常。"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-" + UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("测试通知发送失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "通知发送失败"
                    alert.informativeText = """
                    错误: \(error.localizedDescription)
                    
                    通知权限可能被系统拒绝，请执行以下步骤重置：
                    
                    1. 打开终端，运行以下命令：
                        tccutil reset All com.otpilot.app
                    
                    2. 重新启动 OTPilot 并允许通知权限
                    """
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "复制命令")
                    alert.addButton(withTitle: "打开通知设置")
                    alert.addButton(withTitle: "关闭")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("tccutil reset All com.otpilot.app", forType: .string)
                    } else if response == .alertSecondButtonReturn {
                        self.openNotificationSettings()
                    }
                }
            } else {
                print("✅ 测试通知已发送")
            }
        }
    }
    
    // MARK: - 通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            // 如果已经授权或临时授权，直接注册
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                self?.registerAppInNotificationCenter()
                return
            }

            // 如果被拒绝，提示用户重置
            if settings.authorizationStatus == .denied {
                print("⚠️ 通知权限已被拒绝，请通过菜单中的'重置通知权限'选项重置")
                return
            }

            // 未请求过权限，发起请求
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("通知权限请求失败: \(error.localizedDescription)")
                    return
                }
                if granted {
                    print("✅ 通知权限已授予")
                    DispatchQueue.main.async {
                        self?.registerAppInNotificationCenter()
                    }
                } else {
                    print("⚠️ 未获得通知权限")
                }
            }
        }
    }

    /// 重置通知权限（使用 tccutil）
    @objc func resetNotificationPermission() {
        let alert = NSAlert()
        alert.messageText = "重置通知权限"
        alert.informativeText = """
        这将执行以下命令重置通知权限：

            tccutil reset All com.otpilot.app

        命令已复制到剪贴板，请打开终端粘贴运行。
        运行后请重新启动 OTPilot 以重新请求权限。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "复制命令并退出")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("tccutil reset All com.otpilot.app", forType: .string)
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// 发送一条即时消失的静默通知，让 app 出现在系统设置 > 通知列表中
    private func registerAppInNotificationCenter() {
        let content = UNMutableNotificationContent()
        content.title = "OTPilot"
        content.body = "验证码监控已就绪"
        content.sound = .default
        
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
        OTPilot 需要通知权限才能显示验证码复制提醒。
        
        如果在系统设置中找不到 OTPilot，请在终端运行：
            tccutil reset All com.otpilot.app
        然后重新启动 OTPilot 即可重新弹出权限请求。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "复制命令")
        alert.addButton(withTitle: "打开通知设置")
        alert.addButton(withTitle: "稍后")
        alert.icon = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("tccutil reset All com.otpilot.app", forType: .string)
        } else if response == .alertSecondButtonReturn {
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
                    DispatchQueue.main.async {
                        self.sendTestNotification()
                    }
                } else if response == .alertSecondButtonReturn {
                    self.openNotificationSettings()
                }
            }
        }
    }
    
    // MARK: - NSMenuDelegate (hover 效果 + 详情面板)

    func menuWillOpen(_ menu: NSMenu) {
        highlightedView = nil
    }

    func menuDidClose(_ menu: NSMenu) {
        // 菜单关闭时清除所有高亮和详情面板
        if let view = highlightedView {
            view.isHighlighted = false
            highlightedView = nil
        }
        hideDetailPanel()
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // 清除旧高亮
        if let oldView = highlightedView {
            oldView.isHighlighted = false
        }

        // 设置新高亮
        if let item = item, let view = item.view as? MenuItemView {
            view.isHighlighted = true
            highlightedView = view
            showDetailPanel(for: view, item: item)
        } else if item != nil {
            // 高亮到非验证码条目（如"刷新"、"退出"等），隐藏面板
            highlightedView = nil
            hideDetailPanel()
        }
        // item == nil 时不隐藏面板：用户可能正将鼠标移向详情面板
    }
    
    // MARK: - 详情面板
    
    private func showDetailPanel(for view: MenuItemView, item: NSMenuItem) {
        guard !view.isHeader, !view.messageText.isEmpty else {
            hideDetailPanel()
            return
        }
        
        // 如果已有面板且对应同一个 view，不重复创建
        if let existing = detailPanel, existing.isVisible,
           detailPanelTarget == view {
            return
        }
        
        hideDetailPanel()
        
        // 获取菜单项在屏幕中的位置
        guard let menuWindow = view.window else { return }
        let viewFrameInScreen = menuWindow.convertToScreen(view.convert(view.bounds, to: nil))
        
        let panelWidth: CGFloat = 280
        let timeStr: String
        if let date = view.timestampDate {
            timeStr = formatTimestamp(date)
        } else {
            timeStr = ""
        }
        print("📋 showDetailPanel: code=\(view.codeText), sender=\(view.senderText), timestamp=\(timeStr), msgLen=\(view.messageText.count)")
        let contentView = makeDetailContentView(code: view.codeText,
                                                 sender: view.senderText,
                                                 message: view.messageText,
                                                 timestamp: timeStr,
                                                 width: panelWidth)
        
        // 面板放在菜单项左侧，垂直居中对齐
        let panelX = viewFrameInScreen.minX - panelWidth - 12
        let panelY = viewFrameInScreen.midY - contentView.frame.height / 2
        
        let panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: contentView.frame.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        detailPanelTarget = view
        
        // 添加 Visual Effect 背景
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: contentView.frame.height))
        visualEffect.material = .menu
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 8
        visualEffect.layer?.masksToBounds = true
        panel.contentView = visualEffect
        
        visualEffect.addSubview(contentView)
        
        panel.orderFront(nil)
        detailPanel = panel
    }
    
    private func hideDetailPanel() {
        detailPanel?.close()
        detailPanel = nil
        detailPanelTarget = nil
    }
    
    /// 计算文本在指定宽度下换行后的高度
    private func calculateTextHeight(text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let size = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(size.height)
    }
    
    /// 构建详情面板内容视图
    private func makeDetailContentView(code: String, sender: String, message: String, timestamp: String, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        
        let margin: CGFloat = 16
        var y: CGFloat = 12
        
        // --- 第一行: 图标 + 发送者 + 时间 ---
        let iconView = NSImageView(image: NSImage(systemSymbolName: "message.fill", accessibilityDescription: nil)!)
        iconView.frame = NSRect(x: margin, y: y, width: 18, height: 18)
        iconView.contentTintColor = .secondaryLabelColor
        container.addSubview(iconView)
        
        let senderLabel = NSTextField(labelWithString: sender)
        senderLabel.frame = NSRect(x: margin + 24, y: y - 1, width: width - margin * 2 - 24, height: 18)
        senderLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        senderLabel.textColor = .labelColor
        senderLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(senderLabel)
        y += 20
        
        // --- 第二行: 时间 ---
        let timeDisplay = timestamp.isEmpty ? "时间未知" : timestamp
        let timeLabel = NSTextField(labelWithString: timeDisplay)
        timeLabel.frame = NSRect(x: margin + 24, y: y, width: width - margin * 2 - 24, height: 15)
        timeLabel.font = NSFont.systemFont(ofSize: 12)
        timeLabel.textColor = .labelColor
        container.addSubview(timeLabel)
        y += 20
        
        // --- 分隔线 ---
        let separator = NSBox(frame: NSRect(x: margin, y: y, width: width - margin * 2, height: 1))
        separator.boxType = .separator
        container.addSubview(separator)
        y += 12
        
        // --- 短信内容 ---
        let msgWidth = width - margin * 2
        let msgFont = NSFont.systemFont(ofSize: 12)
        let msgHeight = self.calculateTextHeight(text: message, font: msgFont, width: msgWidth)
        
        let msgLabel = NSTextField(frame: NSRect(x: margin, y: y, width: msgWidth, height: msgHeight))
        msgLabel.isEditable = false
        msgLabel.isBordered = false
        msgLabel.drawsBackground = false
        msgLabel.font = msgFont
        msgLabel.textColor = .labelColor
        msgLabel.stringValue = message
        msgLabel.lineBreakMode = .byWordWrapping
        msgLabel.usesSingleLineMode = false
        msgLabel.cell?.wraps = true
        container.addSubview(msgLabel)
        y += msgHeight + 12
        
        // --- 分隔线 ---
        let separator2 = NSBox(frame: NSRect(x: margin, y: y, width: width - margin * 2, height: 1))
        separator2.boxType = .separator
        container.addSubview(separator2)
        y += 12
        
        // --- 验证码 ---
        let codeTitleLabel = NSTextField(labelWithString: "验证码")
        codeTitleLabel.frame = NSRect(x: margin, y: y, width: 50, height: 16)
        codeTitleLabel.font = NSFont.systemFont(ofSize: 11)
        codeTitleLabel.textColor = .secondaryLabelColor
        container.addSubview(codeTitleLabel)
        
        let codeValueLabel = NSTextField(labelWithString: code)
        codeValueLabel.frame = NSRect(x: margin + 54, y: y, width: width - margin * 2 - 54, height: 16)
        codeValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        codeValueLabel.textColor = .labelColor
        container.addSubview(codeValueLabel)
        y += 24
        
        // 设置最终高度
        container.frame.size.height = y + 4
        
        return container
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
        OTPilot 需要"全磁盘访问"权限才能读取短信中的验证码。
        
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
        var isHighlighted: Bool = false {
            didSet {
                if oldValue != isHighlighted {
                    needsDisplay = true
                }
            }
        }

        /// 验证码文本
        var codeText: String = ""
        /// 完整短信内容（用于详情面板）
        var messageText: String = ""
        /// 发送者名称（用于详情面板）
        var senderText: String = ""
        /// 时间文本（用于详情面板）
        var timestampText: String = ""
        /// 原始时间戳（用于详情面板格式化）
        var timestampDate: Date?
        /// 是否为表头行
        var isHeader: Bool = false

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            return self
        }

        override func mouseUp(with event: NSEvent) {
            super.mouseUp(with: event)
            guard let item = enclosingMenuItem, item.action != nil else { return }
            NSApp.sendAction(item.action!, to: item.target, from: item)
            item.menu?.cancelTracking()
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            if isHighlighted {
                let highlightColor = NSColor.selectedContentBackgroundColor
                highlightColor.setFill()
                let insetRect = bounds.insetBy(dx: 2, dy: 1)
                let path = NSBezierPath(roundedRect: insetRect, xRadius: 4, yRadius: 4)
                path.fill()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        let result = formatter.string(from: date)
        print("🕐 formatTimestamp: \(result)")
        return result
    }
    
    private func makeCodeItemView(code: String, sender: String, message: String = "", timestamp: Date? = nil, isHeader: Bool = false) -> NSView {
        let container = MenuItemView(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        container.codeText = code
        container.messageText = message
        container.senderText = sender
        container.timestampDate = timestamp
        container.isHeader = isHeader
        
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
            codeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            codeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            codeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),
            
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
