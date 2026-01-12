# 开发指南

## 环境配置

### 前置要求

- macOS 13.0+
- Xcode 15+ (Swift 5.9+)
- Node.js 18+
- Obsidian app
- OpenRouter API Key

### 安装依赖

**Obsidian 插件**:
```bash
cd laterread-mvp/obsidian-plugin
npm install
```

**菜单栏 App**:
```bash
cd laterread-mvp/menubar-app
swift package resolve
```

---

## 开发模式

### Obsidian 插件

```bash
cd laterread-mvp/obsidian-plugin

# 监听模式（自动重新编译）
npm run dev

# 手动构建
npm run build

# 安装到 Obsidian
cp main.js manifest.json ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/.obsidian/plugins/laterread/
```

**开发调试**:
1. 在 Obsidian 中按 `⌘⌥I` 打开开发者工具
2. 查看 Console 输出
3. 修改代码后重新加载插件（设置 → 第三方插件 → 禁用 → 启用）

### 菜单栏 App

```bash
cd laterread-mvp/menubar-app

# 开发运行
swift run

# 调试构建
swift build

# Release 构建
swift build -c release
```

**调试技巧**:
- 使用 `print("[TAG] message")` 输出日志
- 打开 Console.app 查看输出（搜索 "LaterRead"）
- 使用 Xcode 的 LLDB 调试器

---

## 项目结构

### 菜单栏 App

```
menubar-app/
├── Package.swift              # Swift 包配置
├── Package.resolved           # 依赖版本锁定
└── LaterRead/                 # 源码目录
    ├── Config.swift           # 配置管理
    ├── Models.swift           # 数据模型
    ├── CategoryManager.swift  # 分类系统
    ├── KeychainManager.swift  # 安全存储
    ├── AIService.swift        # AI API
    ├── BrowserHelper.swift    # 浏览器抓取
    ├── InboxManager.swift     # 文件管理
    ├── LaterReadApp.swift     # App 入口
    └── Views.swift            # UI 界面
```

### Obsidian 插件

```
obsidian-plugin/
├── main.ts        # 主入口
├── manifest.json  # 插件元数据
├── package.json   # npm 配置
├── tsconfig.json  # TypeScript 配置
└── esbuild.config.mjs  # 构建配置
```

---

## 代码规范

### Swift

**命名约定**:
```swift
// 类名：大驼峰
class KeychainManager { }

// 函数名：小驼峰
func saveAPIKey(_ key: String) { }

// 常量：小驼峰
static let vaultName = "..."

// 私有：下划线前缀（可选）
private var _statusItem: NSStatusItem?
```

**注释风格**:
```swift
// ============== 模块标题 ==============

/// 保存 API Key 到 Keychain
/// - Parameter key: API Key 字符串
/// - Returns: 是否保存成功
func saveAPIKey(_ key: String) -> Bool { }
```

**错误处理**:
```swift
// 使用 Result 类型
func classify(...) async -> Result<ClassificationResult, APIError>

// 在调用方 switch 处理
switch result {
case .success(let data):
    // 处理成功
case .failure(let error):
    // 处理错误
}
```

### TypeScript

**命名约定**:
```typescript
// 接口：大驼峰 + I 前缀（可选）
interface ReadingItem { }

// 类：大驼峰
class LaterReadView { }

// 函数：小驼峰
async function classifyWithClaude() { }

// 常量：大写 + 下划线
const DEFAULT_SETTINGS = { }
```

**注释风格**:
```typescript
/**
 * 使用 Claude API 对文章进行分类
 * @param title 文章标题
 * @param url 文章 URL
 * @returns 分类结果
 */
async function classifyWithClaude(title: string, url: string) { }
```

---

## 添加新功能

### 添加新分类

1. **编辑分类定义** (`CategoryManager.swift`):
```swift
static var categories = [
    // 添加新分类
    "science": ("🔬", "Science", "physics, chemistry, biology"),
    ...
]

static let categoryOrder = [
    // 添加到顺序中
    "science",
    ...
]
```

2. **更新 AI Prompt** (自动包含新分类)

3. **测试**:
```bash
swift run
# 保存一篇科学文章，检查是否正确分类
```

### 添加新浏览器支持

编辑 `BrowserHelper.swift`:
```swift
private static let edgeScript = """
tell application "System Events"
    if not (exists process "Microsoft Edge") then return ""
end tell
tell application "Microsoft Edge"
    if (count of windows) = 0 then return ""
    set currentTab to active tab of front window
    return (URL of currentTab) & "|||" & (title of currentTab)
end tell
"""

static func getCurrentPage() -> PageInfo? {
    for script in [safariScript, chromeScript, arcScript, edgeScript] {
        if let result = runAppleScript(script) {
            return result
        }
    }
    return nil
}
```

### 添加新 UI 组件

在 `Views.swift` 中添加新的 SwiftUI View:
```swift
struct NewFeatureView: View {
    @State private var data: [Item] = []

    var body: some View {
        VStack {
            Text("New Feature")
            // UI 代码
        }
    }
}
```

---

## 测试

### 单元测试

创建 `Tests/LaterReadTests/` 目录:
```swift
import XCTest
@testable import LaterRead

class CategoryManagerTests: XCTestCase {
    func testEmojiForCategory() {
        XCTAssertEqual(CategoryManager.emoji(for: "ai-tech"), "🤖")
    }

    func testCategoryKeyFromEmoji() {
        XCTAssertEqual(CategoryManager.categoryKey(from: "🤖"), "ai-tech")
    }
}
```

运行测试:
```bash
swift test
```

### 手动测试清单

- [ ] 快捷键 `⌘⇧L` 捕获页面
- [ ] Safari、Chrome、Arc 都能正常工作
- [ ] AI 分类返回正确结果
- [ ] 批量分类限流正常
- [ ] 菜单栏界面显示正常
- [ ] 标记已读/删除功能正常
- [ ] Settings 界面保存 API Key
- [ ] Obsidian 插件同步数据

---

## 调试技巧

### 查看网络请求

在 `AIService.swift` 中添加日志:
```swift
print("[AI] Request: \(requestBody)")
print("[AI] Response: \(String(data: data, encoding: .utf8) ?? "")")
```

### 调试 Markdown 解析

在 `InboxManager.swift` 中:
```swift
func parseMarkdown(_ content: String) -> [ReadingItem] {
    print("[Parse] Content length: \(content.count)")
    print("[Parse] Lines: \(lines.count)")
    // ...
    print("[Parse] Parsed \(items.count) items")
    return items
}
```

### 使用断点

在 Xcode 中:
1. 打开 `.swift` 文件
2. 点击行号左侧添加断点
3. 运行 `swift run`
4. 在断点处检查变量值

### 监控文件变化

```bash
# 监控 inbox.md 变化
fswatch ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/【00】LaterRead/inbox.md
```

---

## 性能优化

### 减少 API 调用

- 缓存分类结果
- 使用批量分类而不是单次
- 避免重复分类已分类的条目

### 优化文件 I/O

```swift
// 使用 lazy parsing
func loadItems() -> [ReadingItem] {
    // 只在需要时解析
    guard needsRefresh else { return cachedItems }
    return parseMarkdown(content)
}
```

### 优化 UI 性能

```swift
// 使用 LazyVStack 而不是 VStack
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}
```

---

## 发布流程

### 1. 更新版本号

**menubar-app**:
- 编辑 `Info.plist` 中的 `CFBundleVersion`

**obsidian-plugin**:
- 编辑 `manifest.json` 中的 `version`

### 2. 构建 Release

```bash
# 菜单栏 App
cd laterread-mvp/menubar-app
swift build -c release

# Obsidian 插件
cd laterread-mvp/obsidian-plugin
npm run build
```

### 3. 创建 App Bundle

```bash
cd laterread-mvp/menubar-app
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
</dict>
</plist>
EOF
```

### 4. 代码签名（可选）

```bash
# 需要 Apple Developer 账号
codesign --force --sign "Developer ID Application: Your Name" LaterRead.app
```

### 5. 打包分发

```bash
# 创建 DMG
hdiutil create -volname "LaterRead" -srcfolder LaterRead.app -ov -format UDZO LaterRead.dmg
```

---

## 贡献指南

### 提交 Pull Request

1. Fork 项目
2. 创建功能分支：`git checkout -b feature/new-feature`
3. 提交更改：`git commit -m "Add new feature"`
4. 推送分支：`git push origin feature/new-feature`
5. 创建 Pull Request

### 代码审查要点

- [ ] 代码符合命名规范
- [ ] 添加了必要的注释
- [ ] 通过了所有测试
- [ ] 更新了相关文档
- [ ] 没有引入新的警告

---

## 常见问题

### Swift 编译错误

**错误**: `Cannot find type 'Config' in scope`

**原因**: 模块依赖顺序问题

**解决**: 确保 `Config.swift` 在编译列表最前面

### Obsidian 插件不加载

**检查**:
1. `manifest.json` 格式正确
2. `main.js` 存在
3. 插件目录名称正确：`laterread`

### iCloud 同步冲突

**避免方法**:
- 使用 `atomically: true` 写入
- 检查文件是否被占用
- 添加文件锁机制（未来改进）

---

## 参考资源

- [Swift 文档](https://swift.org/documentation/)
- [SwiftUI 教程](https://developer.apple.com/tutorials/swiftui)
- [Obsidian Plugin API](https://github.com/obsidianmd/obsidian-api)
- [OpenRouter API 文档](https://openrouter.ai/docs)
