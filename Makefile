# OTPilot Makefile
# 用法:
#   make          - 编译并运行
#   make build    - 仅编译
#   make run      - 运行已编译的应用
#   make clean    - 清理构建产物
#   make dmg      - 构建 DMG 安装镜像
#   make release  - 发布构建 (带版本号)

SHELL := /bin/bash

APP_NAME := OTPilot
APP_VERSION ?= 1.0.0
BUILD_MODE ?= release

SOURCES_DIR := Sources
BUILD_DIR := build
APP_BUNDLE := $(APP_NAME).app
BINARY_PATH := $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

# 所有 Swift 源文件
SOURCES := $(wildcard $(SOURCES_DIR)/*.swift)

.PHONY: all build run clean dmg release help

all: build run

# 编译应用
build: $(BINARY_PATH)

$(BINARY_PATH): $(SOURCES)
	@echo "🔨 编译 $(APP_NAME) v$(APP_VERSION) ($(BUILD_MODE) 模式)..."
	@bash run.sh $(APP_VERSION) $(BUILD_MODE)

# 运行应用
run:
	@echo "🚀 启动 $(APP_NAME)..."
	@open /Applications/$(APP_NAME).app

# 清理构建产物
clean:
	@echo "🧹 清理构建产物..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@rm -rf $(APP_BUNDLE)/Contents/Info.plist
	@echo "✅ 清理完成"

# 构建 DMG
dmg:
	@bash build_dmg.sh $(APP_VERSION)

# 发布构建
release:
	@echo "📦 发布 $(APP_NAME) v$(APP_VERSION)..."
	@$(MAKE) build BUILD_MODE=release
	@$(MAKE) dmg

# 帮助信息
help:
	@echo "OTPilot 构建系统"
	@echo ""
	@echo "用法:"
	@echo "  make          - 编译并运行"
	@echo "  make build    - 仅编译"
	@echo "  make run      - 运行已编译的应用"
	@echo "  make clean    - 清理构建产物"
	@echo "  make dmg      - 构建 DMG 安装镜像"
	@echo "  make release  - 发布构建 (带版本号)"
	@echo "  make help     - 显示此帮助信息"
	@echo ""
	@echo "选项:"
	@echo "  APP_VERSION=x.x.x  - 设置版本号 (默认: 1.0.0)"
	@echo "  BUILD_MODE=debug   - 设置构建模式 (默认: release)"
	@echo ""
	@echo "示例:"
	@echo "  make release APP_VERSION=1.1.0"
	@echo "  make build BUILD_MODE=debug"
