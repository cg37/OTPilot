# OTPilot - macOS 验证码自动读取工具

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg)](https://swift.org)

自动读取 macOS 短信中的验证码，并自动复制到剪贴板。

## 功能

- 🔍 **自动监控**: 每 5 秒自动检查新短信
- 📋 **自动复制**: 检测到验证码后自动复制到剪贴板
- 🔔 **系统通知**: 收到验证码时发送系统通知
- 📜 **历史记录**: 菜单栏显示最近的验证码历史
- ⌨️ **快捷键支持**:
  - `Cmd+R` 刷新
  - `Cmd+C` 复制最新验证码
  - `Cmd+Q` 退出

## 使用方法

### 运行应用

```bash
cd ~/Code/OTPilot
./run.sh
```

应用会自动编译并部署到 `/Applications/OTPilot.app`。

### 首次运行权限设置

1. **全磁盘访问权限** (必需)
   - 打开"系统设置" > "隐私与安全性" > "全磁盘访问"
   - 点击 "+" 添加 `OTPilot.app`
   - 路径: `~/Desktop/OTPilot.app`

2. **通知权限** (可选但推荐)
   - 首次运行时会自动请求
   - 可在"系统设置" > "通知"中管理

## 验证码匹配规则

支持以下格式的验证码:

- 中文: "验证码:123456", "校验码 1234"
- 英文: "Your code is 123456", "Code: 1234"
- 纯数字: 4-6 位连续数字

## 技术细节

- **开发语言**: Swift
- **最低系统要求**: macOS 13.0+
- **数据来源**: `~/Library/Messages/chat.db` (Messages 应用数据库)
- **监控间隔**: 5 秒
- **历史记录**: 最多保存 50 条

## 注意事项

- 需要启用 iPhone 短信同步功能 (iCloud 同步)
- 需要授予"全磁盘访问"权限才能读取 Messages 数据库
- 应用运行在菜单栏,不会占用 Dock 空间

## 重新编译

运行 `./run.sh` 会自动重新编译并部署到桌面。

也可以手动编译:

```bash
cd ~/Code/OTPilot
swiftc -target arm64-apple-macos13 \
    -o OTPilot.app/Contents/MacOS/OTPilot \
    Sources/*.swift \
    -framework AppKit \
    -framework UserNotifications \
    -lsqlite3
```

## 项目结构

```
OTPilot/
├── Sources/
│   ├── main.swift              # 应用入口和菜单栏 UI
│   ├── CodeReaderManager.swift # 核心逻辑:数据库读取、验证码匹配
│   └── Models.swift            # 数据模型定义
├── OTPilot.app/                # macOS 应用包
│   └── Contents/
│       ├── Info.plist          # 应用配置
│       └── MacOS/
│           └── OTPilot         # 编译后的可执行文件
├── run.sh                      # 编译+启动脚本
└── README.md                   # 本文件
```

## 故障排除

### 无法读取短信?

1. 确认已启用 iCloud 短信同步
2. 确认已授予"全磁盘访问"权限
3. 检查数据库文件是否存在: `~/Library/Messages/chat.db`

### 没有检测到验证码?

- 检查短信格式是否匹配正则表达式
- 在终端运行应用查看调试输出

### 应用崩溃?

- 检查 macOS 版本是否为 13.0 或更高
- 查看控制台日志获取错误信息

## 许可证

本项目采用 [MIT License](LICENSE)。
