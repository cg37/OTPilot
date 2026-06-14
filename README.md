# OTPilot - macOS 短信验证码自动读取工具

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg)](https://swift.org)

> 轻量级 macOS 菜单栏应用，自动监控短信验证码，一键复制到剪贴板。

## ✨ 特性

- 🔍 **自动监控** — 每 5 秒扫描新短信，自动提取验证码
- 📋 **一键复制** — 检测到验证码后自动复制到剪贴板
- 🔔 **静默通知** — 无声音干扰的横幅通知，不打扰你的工作流
- 🎯 **智能匹配** — 支持中英文验证码格式，自动过滤手机号/订单号
- 📜 **历史记录** — 菜单栏保留最近 50 条验证码，快速回溯
- ⌨️ **快捷键** — `Cmd+R` 刷新 / `Cmd+C` 复制最新 / `Cmd+Q` 退出
- 🖥️ **菜单栏常驻** — 不占 Dock 空间，随时可用

## 🚀 快速开始

### 一键构建

```bash
make          # 编译并运行
```

### 使用脚本

```bash
./run.sh                    # 编译并运行
./run.sh 1.1.0 debug        # 指定版本 + 调试模式
```

### 构建 DMG 安装包

```bash
make dmg APP_VERSION=1.0.0  # 生成 OTPilot-1.0.0.dmg
```

## 📖 使用方法

### 首次运行

1. **授予全磁盘访问权限**（必需）
   ```
   系统设置 > 隐私与安全性 > 全磁盘访问 > + 添加 OTPilot.app
   ```

2. **允许通知权限**（推荐）
   - 首次启动自动请求
   - 通知仅显示横幅，无声音

3. **确保短信同步开启**
   - iPhone: 设置 > 信息 > 短信转发 > 开启此 Mac

### 日常使用

- 点击菜单栏 🔑 图标查看最新验证码
- 点击验证码条目自动复制到剪贴板
- 图标变实心 🔑 表示有新验证码

## 🎯 验证码匹配规则

| 格式类型 | 示例 |
|---------|------|
| 中文关键词 | `验证码：123456`、`校验码 888888` |
| 英文关键词 | `Your code: 123456`、`Code: 888888` |
| 描述句式 | `验证码是 123456`、`登录码为 8888` |
| 后置括号 | `123456（验证码）`、`8888(动态码)` |

**自动排除：** 手机号、订单号、快递单号等长数字串

## 🏗️ 项目结构

```
OTPilot/
├── Sources/
│   ├── main.swift              # 应用入口 & AppDelegate
│   ├── AppConstants.swift      # 配置常量 & 正则规则
│   ├── CodeReaderManager.swift # 核心：数据库读取 & 验证码匹配
│   ├── MenuBuilder.swift       # 菜单栏 UI & 交互逻辑
│   ├── Models.swift            # 数据模型
│   └── PermissionManager.swift # 权限管理 (磁盘/通知)
├── scripts/
│   └── build-dmg.sh            # DMG 打包脚本
├── Makefile                    # 构建系统
├── run.sh                      # 编译启动脚本
├── build_dmg.sh                # DMG 构建入口
└── OTPilot.entitlements        # 应用权限声明
```

## ⚙️ 技术细节

| 项目 | 值 |
|------|-----|
| 语言 | Swift |
| 最低系统 | macOS 13.0+ |
| 架构 | Apple Silicon (arm64) |
| 数据源 | `~/Library/Messages/chat.db` (只读) |
| 监控间隔 | 5 秒 |
| 历史容量 | 50 条 |
| 菜单显示 | 最新 5 条 |

## 🛠️ 构建命令

| 命令 | 说明 |
|------|------|
| `make` | 编译并运行 |
| `make build` | 仅编译 |
| `make run` | 运行已编译应用 |
| `make clean` | 清理构建产物 |
| `make dmg APP_VERSION=x.x.x` | 构建 DMG |
| `make release APP_VERSION=x.x.x` | 发布构建 |

## 💡 优化特性

- **持久数据库连接** — 避免频繁打开/关闭的开销
- **只读模式** — `SQLITE_OPEN_READONLY` 避免与 Messages 冲突
- **参数化查询** — 防止 SQL 注入
- **增量编译** — 源码未变更时跳过编译
- **模块化设计** — 清晰的职责分离

## ❓ 常见问题

**Q: 无法读取短信？**
- 确认已授予「全磁盘访问」权限
- 检查数据库是否存在：`~/Library/Messages/chat.db`
- 确认 iPhone 短信转发已开启

**Q: 没有检测到验证码？**
- 验证码格式可能不在匹配规则内
- 运行 `./run.sh debug` 查看调试输出

**Q: 通知没有声音？**
- 这是设计如此 — 所有通知均为静默横幅
- 如需修改，可在代码中调整 `content.sound` 设置

## 📄 许可证

[MIT License](LICENSE)
