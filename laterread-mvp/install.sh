#!/bin/bash

# LaterRead 安装脚本
# 用法: ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww"
PLUGIN_DIR="$VAULT_PATH/.obsidian/plugins/laterread"

echo "🚀 开始安装 LaterRead..."

# ============== 1. 构建 Obsidian 插件 ==============
echo ""
echo "📦 构建 Obsidian 插件..."
cd "$SCRIPT_DIR/obsidian-plugin"

if ! command -v npm &> /dev/null; then
    echo "❌ 需要安装 npm，请先安装 Node.js"
    exit 1
fi

npm install
npm run build

# 创建插件目录并复制文件
mkdir -p "$PLUGIN_DIR"
cp main.js manifest.json "$PLUGIN_DIR/"

echo "✅ Obsidian 插件已安装到: $PLUGIN_DIR"

# ============== 2. 构建菜单栏 App ==============
echo ""
echo "🔨 构建菜单栏 App..."
cd "$SCRIPT_DIR/menubar-app"

if ! command -v swift &> /dev/null; then
    echo "❌ 需要安装 Xcode Command Line Tools"
    echo "   运行: xcode-select --install"
    exit 1
fi

swift build -c release

# 创建 App Bundle
APP_PATH="$SCRIPT_DIR/LaterRead.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"

cp .build/release/LaterRead "$APP_PATH/Contents/MacOS/"

cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LaterRead</string>
    <key>CFBundleIdentifier</key>
    <string>com.joey.laterread</string>
    <key>CFBundleName</key>
    <string>LaterRead</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>LaterRead needs to access browsers to capture page information.</string>
</dict>
</plist>
EOF

echo "✅ App 已构建: $APP_PATH"

# ============== 3. 安装到 Applications ==============
echo ""
read -p "是否安装到 /Applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo rm -rf /Applications/LaterRead.app
    sudo cp -r "$APP_PATH" /Applications/
    echo "✅ 已安装到 /Applications/LaterRead.app"
fi

# ============== 4. 创建 LaterRead 目录 ==============
LATERREAD_DIR="$VAULT_PATH/【00】LaterRead"
if [ ! -d "$LATERREAD_DIR" ]; then
    mkdir -p "$LATERREAD_DIR"
    echo "# 📖 LaterRead Inbox" > "$LATERREAD_DIR/inbox.md"
    echo "✅ 已创建 LaterRead 目录: $LATERREAD_DIR"
fi

# ============== 完成 ==============
echo ""
echo "🎉 安装完成！"
echo ""
echo "接下来需要手动操作："
echo "1. 打开 Obsidian → 设置 → 第三方插件 → 启用 LaterRead"
echo "2. 打开 LaterRead.app（首次需要授权）"
echo "3. 系统设置 → 隐私与安全性 → 辅助功能 → 添加 LaterRead"
echo "4. 系统设置 → 隐私与安全性 → 自动化 → 允许控制浏览器"
echo ""
echo "使用方法："
echo "- 按 ⌘⇧L 保存当前浏览器页面"
echo "- 点击菜单栏 📖 图标查看列表"
echo "- 在 Obsidian 侧边栏管理阅读列表"
