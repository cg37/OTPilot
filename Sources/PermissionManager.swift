import Foundation
import AppKit
import UserNotifications

/// 管理应用权限（全磁盘访问、通知权限）
final class PermissionManager {
    
    // MARK: - 全磁盘访问权限
    
    static func checkFullDiskAccess() -> Bool {
        let dbPath = (AppConstants.messagesDBPath as NSString).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("⚠️ Messages 数据库不存在: \(dbPath)")
            return false
        }
        
        let fd = open(dbPath, O_RDONLY)
        if fd != -1 {
            close(fd)
            return true
        }
        
        let err = errno
        print("⚠️ 无法读取 Messages 数据库, errno: \(err)")
        return false
    }
    
    static func showFullDiskAccessAlert() {
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
    
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - 通知权限
    
    static func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                DispatchQueue.main.async {
                    completion(true)
                }
                return
            }
            
            if settings.authorizationStatus == .denied {
                print("⚠️ 通知权限已被拒绝")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("⚠️ 通知权限请求失败: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }
    
    static func registerAppInNotificationCenter() {
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
                print("⚠️ 注册通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 已在通知中心注册")
            }
        }
    }
    
    static func showNotificationDeniedAlert() {
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
    
    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    static func diagnoseNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let status: String
                switch settings.authorizationStatus {
                case .notDetermined: status = "未请求"
                case .denied: status = "已拒绝"
                case .authorized: status = "已授权"
                case .provisional: status = "临时授权"
                case .ephemeral: status = "App Clips 授权"
                @unknown default: status = "未知"
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
                    sendTestNotification()
                } else if response == .alertSecondButtonReturn {
                    openNotificationSettings()
                }
            }
        }
    }
    
    static func sendTestNotification() {
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
                print("⚠️ 测试通知发送失败: \(error.localizedDescription)")
            } else {
                print("✅ 测试通知已发送")
            }
        }
    }
    
    static func resetNotificationPermission() {
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
}
