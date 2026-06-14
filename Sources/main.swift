import Foundation
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var manager: CodeReaderManager!
    var menu: NSMenu!
    var menuBuilder: MenuBuilder!
    
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
        
        // 初始化菜单构建器
        menuBuilder = MenuBuilder(menu: menu, manager: manager)
        MenuActions.manager = manager
        MenuActions.rebuildMenu = { [weak self] in self?.menuBuilder.rebuildMenu() }
        
        rebuildMenu()
        
        // 定期更新菜单
        Timer.scheduledTimer(withTimeInterval: AppConstants.menuUpdateInterval, repeats: true) { [weak self] _ in
            self?.rebuildMenu()
        }
        
        print("✅ \(AppConstants.appName) v\(AppConstants.appVersion) 已启动")
        print("📡 正在监控短信验证码...")
        
        // 请求通知权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            PermissionManager.requestNotificationPermission { granted in
                if granted {
                    PermissionManager.registerAppInNotificationCenter()
                }
            }
        }
        
        // 检查全磁盘访问权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.checkFullDiskAccess()
        }
    }
    
    private func rebuildMenu() {
        menuBuilder.rebuildMenu()
        updateStatusItemIcon()
    }
    
    private func updateStatusItemIcon() {
        if let button = statusItem.button {
            if manager?.hasNewCode == true {
                button.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: "新验证码")
            } else {
                button.image = NSImage(systemSymbolName: "message", accessibilityDescription: AppConstants.appName)
            }
            button.image?.isTemplate = true
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        menuBuilder.menuWillOpen()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuBuilder.menuDidClose()
    }
    
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        menuBuilder.menuWillHighlight(item: item)
    }
    
    // MARK: - 权限检查
    
    private func checkFullDiskAccess() {
        if !PermissionManager.checkFullDiskAccess() {
            PermissionManager.showFullDiskAccessAlert()
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
