# LaterRead MVP

LaterRead 的 MVP 实现，包含 macOS 菜单栏 App 和 Obsidian 插件。

完整文档见项目根目录 [README.md](../README.md)

---

## 快速安装

```bash
./install.sh
```

安装脚本会自动：
1. 构建 Obsidian 插件并安装到 vault
2. 构建菜单栏 App 并创建 .app bundle
3. 创建 `【00】LaterRead` 目录和 `inbox.md`

---

## 手动安装

### 1. Obsidian 插件

```bash
cd obsidian-plugin
npm install
npm run build
cp main.js manifest.json ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/.obsidian/plugins/laterread/
```

然后在 Obsidian → 设置 → 第三方插件 → 启用 LaterRead

### 2. 菜单栏 App

```bash
cd menubar-app
swift build -c release

# 创建 App Bundle
mkdir -p LaterRead.app/Contents/MacOS
cp .build/release/LaterRead LaterRead.app/Contents/MacOS/

# 创建 Info.plist
cat > LaterRead.app/Contents/Info.plist << 'EOF'
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
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>LaterRead needs to access browsers to capture page information.</string>
</dict>
</plist>
EOF

# 移动到 Applications
mv LaterRead.app /Applications/
```

---

## 开发

### Obsidian 插件

```bash
cd obsidian-plugin
npm run dev  # 监听模式
```

### 菜单栏 App

```bash
cd menubar-app
swift run  # 开发运行
```

---

## 文档

- [使用指南](../docs/USAGE.md)
- [故障排除](../docs/TROUBLESHOOTING.md)
- [架构设计](../docs/ARCHITECTURE.md)
- [开发指南](../docs/DEVELOPMENT.md)
