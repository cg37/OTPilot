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
- 🖱️ **悬停详情**: 鼠标悬停显示完整短信内容

## 快速开始

### 使用 Make (推荐)

```bash
# 编译并运行
make

# 仅编译
make build

# 构建 DMG
make dmg APP_VERSION=1.0.0

# 查看帮助
make help
```

### 使用脚本

```bash
# 编译并运行
./run.sh                    # 默认版本 1.0.0
./run.sh 1.1.0             # 指定版本
./run.sh 1.1.0 debug       # debug 模式

# 构建 DMG
./build_dmg.sh 1.0.0
```

## 使用方法

### 首次运行权限设置

1. **全磁盘访问权限** (必需)
   - 打开"系统设置" > "隐私与安全性" > "全磁盘访问"
   - 点击 "+" 添加 `OTPilot.app`
   - 路径: `/Applications/OTPilot.app`

2. **通知权限** (可选但推荐)
   - 首次运行时会自动请求
   - 可在"系统设置" > "通知"中管理

## 验证码匹配规则

支持以下格式的验证码:

- 中文: "验证码:123456", "校验码 1234"
- 英文: "Your code is 123456", "Code: 1234"
- 纯数字: 4-8 位连续数字

## 项目结构

```
OTPilot/
├── Sources/
│   ├── main.swift              # 应用入口和 AppDelegate
│   ├── AppConstants.swift      # 常量配置
│   ├── CodeReaderManager.swift # 核心逻辑:数据库读取、验证码匹配
│   ├── MenuBuilder.swift       # 菜单 UI 构建和交互
│   ├── Models.swift            # 数据模型定义
│   └── PermissionManager.swift # 权限管理 (全磁盘访问、通知)
├── OTPilot.app/                # macOS 应用包
│   └── Contents/
│       ├── Info.plist          # 应用配置
│       └── MacOS/
│           └── OTPilot         # 编译后的可执行文件
├── build/                      # 构建产物
├── Makefile                    # Make 构建系统
├── run.sh                      # 编译+启动脚本
├── build_dmg.sh               # DMG 打包脚本
└── README.md                   # 本文件
```

## 技术细节

| 项目 | 值 |
|------|-----|
| 开发语言 | Swift |
| 最低系统版本 | macOS 13.0+ |
| 架构 | Apple Silicon (arm64) |
| 数据来源 | `~/Library/Messages/chat.db` |
| 监控间隔 | 5 秒 |
| 历史容量 | 最多 50 条 |
| 显示数量 | 菜单最多 5 条 |

## 构建选项

| 命令 | 说明 |
|------|------|
| `make` | 编译并运行 |
| `make build` | 仅编译 |
| `make run` | 运行已编译的应用 |
| `make clean` | 清理构建产物 |
| `make dmg` | 构建 DMG 安装镜像 |
| `make release APP_VERSION=x.x.x` | 发布构建 |

## 优化特性

- **持久数据库连接**: 避免重复打开/关闭数据库
- **只读模式**: 使用 `SQLITE_OPEN_READONLY` 避免与 Messages 应用锁冲突
- **参数化查询**: 防止 SQL 注入风险
- **增量编译**: 源代码未变更时跳过编译
- **模块化架构**: 清晰的职责分离

## 注意事项

- 需要启用 iPhone 短信同步功能 (iCloud 同步)
- 需要授予"全磁盘访问"权限才能读取 Messages 数据库
- 应用运行在菜单栏,不会占用 Dock 空间

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
