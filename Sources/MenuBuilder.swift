import AppKit
import UserNotifications

/// 负责构建和更新菜单栏 UI
final class MenuBuilder {
    
    private weak var menu: NSMenu?
    private weak var manager: CodeReaderManager?
    
    /// 当前高亮的 MenuItemView，用于追踪 hover 状态
    private var highlightedView: MenuItemView?
    /// hover 时在菜单左侧弹出的详情面板
    private var detailPanel: NSPanel?
    /// 详情面板当前关联的菜单项视图
    private weak var detailPanelTarget: MenuItemView?
    
    init(menu: NSMenu, manager: CodeReaderManager) {
        self.menu = menu
        self.manager = manager
    }
    
    // MARK: - 菜单更新
    
    func rebuildMenu() {
        guard let menu = menu, let manager = manager else { return }
        
        menu.removeAllItems()
        
        // 标题
        let titleItem = NSMenuItem(title: AppConstants.appName, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 验证码列表
        buildCodeListSection(menu: menu, manager: manager)
        
        menu.addItem(NSMenuItem.separator())
        
        // 操作项
        buildActionsSection(menu: menu)
    }
    
    private func buildCodeListSection(menu: NSMenu, manager: CodeReaderManager) {
        let codes = manager.codes
        
        if codes.isEmpty {
            let noCodeItem = NSMenuItem(title: "暂无验证码", action: nil, keyEquivalent: "")
            noCodeItem.isEnabled = false
            menu.addItem(noCodeItem)
            return
        }
        
        // 表头
        let headerView = makeCodeItemView(code: "验证码", sender: "来源", isHeader: true)
        let headerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        headerItem.view = headerView
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        // 验证码条目
        for (index, code) in codes.prefix(AppConstants.maxDisplayCodes).enumerated() {
            let itemView = makeCodeItemView(
                code: code.code,
                sender: code.displaySender,
                message: code.message,
                timestamp: code.timestamp,
                isHeader: false
            )
            let item = NSMenuItem(title: "", action: #selector(MenuActions.showDetailAndCopyCode(_:)), keyEquivalent: "")
            item.target = MenuActions.self
            item.view = itemView
            item.representedObject = code.code
            item.tag = index
            item.toolTip = "点击查看详情并复制验证码"
            menu.addItem(item)
        }
        
        // 更多提示
        if codes.count > AppConstants.maxDisplayCodes {
            let moreItem = NSMenuItem(
                title: "... 还有 \(codes.count - AppConstants.maxDisplayCodes) 条",
                action: nil,
                keyEquivalent: ""
            )
            moreItem.isEnabled = false
            menu.addItem(moreItem)
        }
    }
    
    private func buildActionsSection(menu: NSMenu) {
        let refreshItem = NSMenuItem(title: "刷新", action: #selector(MenuActions.refreshCodes), keyEquivalent: "r")
        refreshItem.target = MenuActions.self
        menu.addItem(refreshItem)
        
        let copyLatestItem = NSMenuItem(title: "复制最新验证码", action: #selector(MenuActions.copyLatestCode), keyEquivalent: "c")
        copyLatestItem.target = MenuActions.self
        menu.addItem(copyLatestItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let permissionItem = NSMenuItem(title: "权限设置", action: #selector(MenuActions.openFullDiskAccessSettings), keyEquivalent: "")
        permissionItem.target = MenuActions.self
        menu.addItem(permissionItem)
        
        let notifyStatusItem = NSMenuItem(title: "通知诊断", action: #selector(MenuActions.diagnoseNotificationStatus), keyEquivalent: "")
        notifyStatusItem.target = MenuActions.self
        menu.addItem(notifyStatusItem)
        
        let resetNotifyItem = NSMenuItem(title: "重置通知权限", action: #selector(MenuActions.resetNotificationPermission), keyEquivalent: "")
        resetNotifyItem.target = MenuActions.self
        menu.addItem(resetNotifyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(MenuActions.quitApp), keyEquivalent: "q")
        quitItem.target = MenuActions.self
        menu.addItem(quitItem)
    }
    
    // MARK: - 自定义菜单项视图
    
    func makeCodeItemView(code: String, sender: String, message: String = "", timestamp: Date? = nil, isHeader: Bool = false) -> NSView {
        let container = MenuItemView(frame: NSRect(x: 0, y: 0, width: AppConstants.menuItemWidth, height: AppConstants.menuItemHeight))
        container.codeText = code
        container.messageText = message
        container.senderText = sender
        container.timestampDate = timestamp
        container.timestampText = timestamp.map { formatTimestamp($0) } ?? ""
        container.isHeader = isHeader
        
        let codeLabel = NSTextField(labelWithString: code)
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        codeLabel.font = isHeader
            ? NSFont.menuBarFont(ofSize: NSFont.smallSystemFontSize)
            : NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        codeLabel.textColor = isHeader ? .secondaryLabelColor : .labelColor
        codeLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(codeLabel)
        container.codeLabel = codeLabel
        
        let senderLabel = NSTextField(labelWithString: sender)
        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        senderLabel.font = isHeader
            ? NSFont.menuBarFont(ofSize: NSFont.smallSystemFontSize)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        senderLabel.textColor = .secondaryLabelColor
        senderLabel.lineBreakMode = .byTruncatingTail
        senderLabel.alignment = .right
        container.addSubview(senderLabel)
        container.senderLabel = senderLabel
        
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
    
    // MARK: - NSMenuDelegate (hover 效果 + 详情面板)
    
    func menuWillOpen() {
        highlightedView = nil
    }
    
    func menuDidClose() {
        if let view = highlightedView {
            view.isHighlighted = false
            highlightedView = nil
        }
        hideDetailPanel()
    }
    
    func menuWillHighlight(item: NSMenuItem?) {
        if let oldView = highlightedView {
            oldView.isHighlighted = false
        }
        
        if let item = item, let view = item.view as? MenuItemView {
            view.isHighlighted = true
            highlightedView = view
            showDetailPanel(for: view, item: item)
        } else if item != nil {
            highlightedView = nil
            hideDetailPanel()
        }
    }
    
    // MARK: - 详情面板
    
    private func showDetailPanel(for view: MenuItemView, item: NSMenuItem) {
        guard !view.isHeader, !view.messageText.isEmpty else {
            hideDetailPanel()
            return
        }
        
        if let existing = detailPanel, existing.isVisible, detailPanelTarget == view {
            return
        }
        
        hideDetailPanel()
        
        guard let menuWindow = view.window else { return }
        let viewFrameInScreen = menuWindow.convertToScreen(view.convert(view.bounds, to: nil))
        
        // 优先使用创建 view 时预格式化的时间戳文本，确保数据一致性
        let timeStr: String
        if !view.timestampText.isEmpty {
            timeStr = view.timestampText
        } else if let date = view.timestampDate {
            timeStr = formatTimestamp(date)
        } else {
            timeStr = ""
        }
        
        let contentView = makeDetailContentView(
            code: view.codeText,
            sender: view.senderText,
            message: view.messageText,
            timestamp: timeStr,
            width: AppConstants.detailPanelWidth
        )
        
        let panelX = viewFrameInScreen.minX - AppConstants.detailPanelWidth - 12
        let panelY = viewFrameInScreen.midY - contentView.frame.height / 2
        
        let panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: AppConstants.detailPanelWidth, height: contentView.frame.height),
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
        
        let visualEffect = NSVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: AppConstants.detailPanelWidth, height: contentView.frame.height)
        )
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
    
    private func calculateTextHeight(text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let size = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(size.height)
    }
    
    private func makeDetailContentView(code: String, sender: String, message: String, timestamp: String, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        let margin = AppConstants.detailPanelMargin
        var y: CGFloat = 12
        
        // 第一行: 图标 + 发送者
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
        
        // 第二行: 时间
        let timeDisplay = timestamp.isEmpty ? "时间未知" : timestamp
        let timeLabel = NSTextField(labelWithString: timeDisplay)
        timeLabel.frame = NSRect(x: margin + 24, y: y, width: width - margin * 2 - 24, height: 15)
        timeLabel.font = NSFont.systemFont(ofSize: 12)
        timeLabel.textColor = .labelColor
        container.addSubview(timeLabel)
        y += 20
        
        // 分隔线
        let separator = NSBox(frame: NSRect(x: margin, y: y, width: width - margin * 2, height: 1))
        separator.boxType = .separator
        container.addSubview(separator)
        y += 12
        
        // 短信内容
        let msgWidth = width - margin * 2
        let msgFont = NSFont.systemFont(ofSize: 12)
        let msgHeight = calculateTextHeight(text: message, font: msgFont, width: msgWidth)
        
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
        
        // 分隔线
        let separator2 = NSBox(frame: NSRect(x: margin, y: y, width: width - margin * 2, height: 1))
        separator2.boxType = .separator
        container.addSubview(separator2)
        y += 12
        
        // 验证码
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
        
        container.frame.size.height = y + 4
        return container
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - 菜单动作目标
@objc class MenuActions: NSObject {
    static weak var manager: CodeReaderManager?
    static var rebuildMenu: (() -> Void)?
    
    @objc static func copyCode(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String {
            manager?.copyToClipboard(code)
            showCopiedNotification(code: code)
        }
    }
    
    @objc static func refreshCodes() {
        manager?.refreshCodes()
        rebuildMenu?()
    }
    
    @objc static func copyLatestCode() {
        if let latestCode = manager?.codes.first {
            manager?.copyToClipboard(latestCode.code)
            showCopiedNotification(code: latestCode.code)
        }
    }
    
    @objc static func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc static func openFullDiskAccessSettings() {
        PermissionManager.openFullDiskAccessSettings()
    }
    
    @objc static func diagnoseNotificationStatus() {
        PermissionManager.diagnoseNotificationStatus()
    }
    
    @objc static func resetNotificationPermission() {
        PermissionManager.resetNotificationPermission()
    }
    
    static func showCopiedNotification(code: String) {
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
                print("⚠️ 发送通知失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - MenuItemView

class MenuItemView: NSView {
    var isHighlighted: Bool = false {
        didSet {
            guard oldValue != isHighlighted else { return }
            needsDisplay = true
            // 原生菜单行为：高亮时切换文字颜色为白色
            let textColor: NSColor = isHighlighted ? .selectedMenuItemTextColor : .labelColor
            let secondaryColor: NSColor = isHighlighted ? .selectedMenuItemTextColor.withAlphaComponent(0.85) : .secondaryLabelColor
            codeLabel?.textColor = textColor
            senderLabel?.textColor = secondaryColor
        }
    }

    var codeText: String = ""
    var messageText: String = ""
    var senderText: String = ""
    var timestampText: String = ""
    var timestampDate: Date?
    var isHeader: Bool = false

    weak var codeLabel: NSTextField?
    weak var senderLabel: NSTextField?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func mouseUp(with event: NSEvent) {
        // 将点击事件转发给 enclosing NSMenuItem，触发其 action
        if let item = self.enclosingMenuItem, let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
            // 点击后关闭菜单
            item.menu?.cancelTracking()
        }
        super.mouseUp(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHighlighted {
            // 原生 macOS 菜单高亮：solid selectedContentBackgroundColor + system 圆角
            let insetRect = bounds.insetBy(dx: 2, dy: 1)
            let path = NSBezierPath(roundedRect: insetRect, xRadius: 5, yRadius: 5)
            NSColor.selectedContentBackgroundColor.setFill()
            path.fill()
        }
    }
}
