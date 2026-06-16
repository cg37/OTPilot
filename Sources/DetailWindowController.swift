import AppKit
import Foundation

/// 原生风格的验证码详情弹出窗口
final class DetailWindowController: NSObject {
    
    private var panel: NSPanel?
    private weak var targetView: NSView?
    
    /// 显示验证码详情弹出窗口
    /// - Parameters:
    ///   - code: 验证码
    ///   - sender: 发件人
    ///   - message: 原始短信内容
    ///   - timestamp: 接收时间字符串
    ///   - relativeTo: 关联的视图（用于定位）
    func show(code: String, sender: String, message: String, timestamp: String, relativeTo view: NSView) {
        hide()
        
        guard let menuWindow = view.window else { return }
        
        targetView = view
        
        // 构建内容视图
        let contentView = makeContentView(code: code, sender: sender, message: message, timestamp: timestamp)
        let contentHeight = contentView.frame.height
        let panelWidth: CGFloat = 300
        
        // 计算面板位置 - 相对于触发视图
        let viewFrameInScreen = menuWindow.convertToScreen(view.convert(view.bounds, to: nil))
        
        // 优先在菜单右侧显示，空间不足时显示在左侧
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let rightX = viewFrameInScreen.maxX + 8
        let leftX = viewFrameInScreen.minX - panelWidth - 8
        
        let panelX: CGFloat
        if rightX + panelWidth <= screenFrame.maxX {
            panelX = rightX
        } else {
            panelX = max(screenFrame.minX + 8, leftX)
        }
        
        // 垂直居中于触发视图
        let panelY = max(
            screenFrame.minY + 8,
            min(
                viewFrameInScreen.midY - contentHeight / 2,
                screenFrame.maxY - contentHeight - 8
            )
        )
        
        // 创建面板
        panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: contentHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        guard let panel = panel else { return }
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.animationBehavior = .alertPanel
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        
        // 使用 NSVisualEffectView 作为根视图
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: contentHeight))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 2)
        visualEffect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        
        panel.contentView = visualEffect
        visualEffect.addSubview(contentView)
        
        // 添加自动关闭点击外部
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowResignActive),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
        
        // 动画显示
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        
        // 添加鼠标追踪 - 悬停在面板外部时自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startMouseMonitor()
        }
    }
    
    func hide() {
        panel?.close()
        panel = nil
        targetView = nil
        removeMouseMonitor()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 鼠标监测
    
    private var mouseMonitor: Any?
    
    private func startMouseMonitor() {
        removeMouseMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }
    
    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    @objc private func handleWindowResignActive() {
        hide()
    }
    
    deinit {
        hide()
    }
    
    // MARK: - 内容视图构建
    
    private func makeContentView(code: String, sender: String, message: String, timestamp: String) -> NSView {
        let margin: CGFloat = 16
        let panelWidth: CGFloat = 300
        let contentWidth = panelWidth - margin * 2
        var y: CGFloat = margin
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 0))
        
        // === 顶部区域: 发件人 + 时间 ===
        
        // 发件人图标
        let iconView = NSImageView(frame: NSRect(x: margin, y: y + 2, width: 18, height: 18))
        iconView.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .controlAccentColor
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        container.addSubview(iconView)
        
        // 发件人名称
        let senderLabel = NSTextField(labelWithString: sender)
        senderLabel.frame = NSRect(x: margin + 26, y: y, width: contentWidth - 26, height: 20)
        senderLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        senderLabel.textColor = .labelColor
        senderLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(senderLabel)
        y += 24
        
        // 时间
        if !timestamp.isEmpty {
            let clockIcon = NSImageView(frame: NSRect(x: margin, y: y + 2, width: 14, height: 14))
            clockIcon.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
            clockIcon.contentTintColor = .tertiaryLabelColor
            clockIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            container.addSubview(clockIcon)
            
            let timeLabel = NSTextField(labelWithString: timestamp)
            timeLabel.frame = NSRect(x: margin + 20, y: y, width: contentWidth - 20, height: 16)
            timeLabel.font = NSFont.systemFont(ofSize: 12)
            timeLabel.textColor = .tertiaryLabelColor
            container.addSubview(timeLabel)
            y += 22
        }
        
        // 分隔线
        y += 4
        let separator1 = NSBox(frame: NSRect(x: margin, y: y, width: contentWidth, height: 1))
        separator1.boxType = .separator
        container.addSubview(separator1)
        y += 12
        
        // === 短信内容 ===
        let msgFont = NSFont.systemFont(ofSize: 13)
        let msgHeight: CGFloat
        if message.isEmpty {
            msgHeight = 0
        } else {
            msgHeight = (message as NSString).boundingRect(
                with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: msgFont],
                context: nil
            ).height + 2
        }
        
        let msgLabel = NSTextField(frame: NSRect(x: margin, y: y, width: contentWidth, height: max(msgHeight, 16)))
        msgLabel.isEditable = false
        msgLabel.isBordered = false
        msgLabel.drawsBackground = false
        msgLabel.font = msgFont
        msgLabel.textColor = .labelColor
        msgLabel.stringValue = message
        msgLabel.lineBreakMode = .byWordWrapping
        msgLabel.usesSingleLineMode = false
        msgLabel.cell?.wraps = true
        msgLabel.cell?.lineBreakMode = .byWordWrapping
        container.addSubview(msgLabel)
        y += max(msgHeight, 16) + 8
        
        // 分隔线
        let separator2 = NSBox(frame: NSRect(x: margin, y: y, width: contentWidth, height: 1))
        separator2.boxType = .separator
        container.addSubview(separator2)
        y += 12
        
        // === 验证码区域 ===
        let codeTitleLabel = NSTextField(labelWithString: "验证码")
        codeTitleLabel.frame = NSRect(x: margin, y: y + 2, width: 50, height: 16)
        codeTitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        codeTitleLabel.textColor = .secondaryLabelColor
        container.addSubview(codeTitleLabel)
        
        // 验证码值 (等宽字体)
        let codeValueLabel = NSTextField(labelWithString: code)
        codeValueLabel.frame = NSRect(x: margin + 50, y: y, width: contentWidth - 50, height: 22)
        codeValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        codeValueLabel.textColor = .labelColor
        codeValueLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(codeValueLabel)
        y += 28
        
        // === 复制按钮 ===
        y += 4
        let buttonHeight: CGFloat = 32
        let copyButton = NSButton(frame: NSRect(x: margin, y: y, width: contentWidth, height: buttonHeight))
        copyButton.title = "复制验证码"
        copyButton.bezelStyle = .flexiblePush
        copyButton.controlSize = .regular
        copyButton.hasDestructiveAction = false
        copyButton.keyEquivalent = "\r" // Enter 键
        copyButton.action = #selector(copyButtonClicked(_:))
        copyButton.target = self
        copyButton.refusesFirstResponder = true
        
        // 设置按钮样式
        if #available(macOS 11.0, *) {
            copyButton.contentTintColor = .controlAccentColor
            copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
            copyButton.imagePosition = .imageLeading
            copyButton.imageHugsTitle = true
        }
        container.addSubview(copyButton)
        y += buttonHeight + margin
        
        // 设置容器高度
        container.frame.size.height = y
        
        return container
    }
    
    @objc private func copyButtonClicked(_ sender: NSButton) {
        // 查找 code 标签
        guard let panel = panel,
              let contentView = panel.contentView?.subviews.first as? NSView else { return }
        
        // 从容器子视图中查找验证码值
        var codeToCopy = ""
        for subview in contentView.subviews {
            if let label = subview as? NSTextField,
               label.font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true {
                codeToCopy = label.stringValue
                break
            }
        }
        
        if !codeToCopy.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(codeToCopy, forType: .string)
            
            // 按钮反馈动画
            let originalTitle = sender.title
            sender.title = "✅ 已复制"
            sender.isEnabled = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sender.title = originalTitle
                sender.isEnabled = true
            }
            
            // 触觉反馈
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            
            print("📋 从详情窗口复制验证码: \(codeToCopy)")
        }
    }
}

// MARK: - 共享实例

extension DetailWindowController {
    /// 共享实例，确保一次只显示一个详情窗口
    static let shared = DetailWindowController()
}

// MARK: - 菜单栏快捷访问

extension MenuActions {
    /// 显示详情窗口并复制验证码
    @objc static func showDetailAndCopyCode(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String,
              let view = sender.view else {
            // 回退：只复制
            copyCode(sender)
            return
        }
        
        // 先复制验证码到剪贴板
        manager?.copyToClipboard(code)
        showCopiedNotification(code: code)
        
        // 获取详情信息并显示窗口
        if let menuItemView = view as? MenuItemView {
            let timestamp: String
            if !menuItemView.timestampText.isEmpty {
                timestamp = menuItemView.timestampText
            } else if let date = menuItemView.timestampDate {
                timestamp = formatDetailTimestamp(date)
            } else {
                timestamp = ""
            }
            
            DetailWindowController.shared.show(
                code: menuItemView.codeText,
                sender: menuItemView.senderText,
                message: menuItemView.messageText,
                timestamp: timestamp,
                relativeTo: view
            )
        }
    }
    
    private static func formatDetailTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return formatter.string(from: date)
    }
}
