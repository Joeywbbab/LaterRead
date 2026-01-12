# 架构设计

## 系统概览

LaterRead 采用**双端架构**：macOS 菜单栏 App + Obsidian 插件，共享同一份 Markdown 数据文件。

```
┌─────────────────────────────────────┐
│  macOS 菜单栏 App (Swift/SwiftUI)   │
│  • 全局快捷键捕获浏览器页面          │
│  • OpenRouter AI 自动分类            │
│  • 批量处理 + 限流控制               │
│  • 菜单栏下拉界面                    │
└─────────────────────────────────────┘
                ↓ ↑ 读写
┌─────────────────────────────────────┐
│  共享数据层 (Markdown)              │
│  ~/Library/.../Joeyyyyuwww/         │
│  【00】LaterRead/                    │
│  ├── inbox.md     ← 待读列表        │
│  ├── archive.md   ← 已读归档        │
│  └── YYYY-WXX.md  ← 周末 Digest     │
└─────────────────────────────────────┘
                ↓ ↑ 读写
┌─────────────────────────────────────┐
│  Obsidian 插件 (TypeScript)         │
│  • 侧边栏视图                        │
│  • 手动添加和管理                    │
│  • 归档和 Digest 生成                │
│  • 文件变更监听                      │
└─────────────────────────────────────┘
```

---

## 菜单栏 App 架构

### 分层设计

```
┌──────────────────────────────┐
│  LaterReadApp (应用层)       │
│  • App 生命周期管理          │
│  • AppDelegate               │
│  • 菜单栏状态管理            │
│  • 通知系统                  │
└──────────────────────────────┘
         ↓ 调用
┌──────────────────────────────┐
│  Views (UI 层)               │
│  • MenuBarView - 主界面      │
│  • ItemRow - 列表项          │
│  • QuickAddView - 快速添加   │
│  • SettingsView - 设置界面   │
└──────────────────────────────┘
         ↓ 调用
┌──────────────────────────────┐
│  Services (服务层)           │
│  • AIService - AI 分类       │
│  • InboxManager - 文件管理   │
└──────────────────────────────┘
         ↓ 调用
┌──────────────────────────────┐
│  Utils (工具层)              │
│  • KeychainManager - 安全存储│
│  • BrowserHelper - 浏览器抓取│
└──────────────────────────────┘
         ↓ 依赖
┌──────────────────────────────┐
│  Core (核心层)               │
│  • Models - 数据模型         │
│  • CategoryManager - 分类    │
│  • Config - 配置管理         │
└──────────────────────────────┘
```

### 模块说明

| 模块 | 大小 | 职责 |
|------|------|------|
| **Config.swift** | 1.1KB | Vault 路径、API 配置、URL 生成 |
| **Models.swift** | 786B | ReadingItem 数据结构 |
| **CategoryManager.swift** | 2.4KB | 10 大分类定义、关键词、Prompt |
| **KeychainManager.swift** | 2.0KB | API Key 安全存储（macOS Keychain）|
| **AIService.swift** | 4.8KB | OpenRouter API 调用、错误处理 |
| **BrowserHelper.swift** | 2.0KB | AppleScript 抓取浏览器信息 |
| **InboxManager.swift** | 5.1KB | Markdown 解析/生成、文件 I/O |
| **LaterReadApp.swift** | 5.9KB | App 入口、生命周期、菜单栏 |
| **Views.swift** | 19KB | 所有 SwiftUI 视图组件 |

### 设计原则

1. **单一职责**：每个模块负责一个明确的功能
2. **依赖注入**：通过 `shared` 单例管理服务
3. **分层清晰**：高层依赖低层，低层不依赖高层
4. **易于测试**：各模块独立，可单独测试
5. **便于维护**：小文件，职责清晰

---

## 数据流

### 保存流程

```
1. 用户按 ⌘⇧L
   ↓
2. HotKey 触发 captureCurrentPage()
   ↓
3. BrowserHelper 通过 AppleScript 获取页面信息
   ↓
4. QuickAddWindow 显示快速添加界面
   ↓
5. 用户确认 → saveItem()
   ↓
6. InboxManager.appendItem() 写入 inbox.md
   ↓
7. 后台 Task 调用 AIService.classify()
   ↓
8. OpenRouter API 返回分类和摘要
   ↓
9. InboxManager.updateItem() 更新 inbox.md
   ↓
10. 刷新 MenuBarView
```

### AI 分类流程

```
1. AIService.classify(title, url, domain, apiKey)
   ↓
2. 构建 Prompt（包含 CategoryManager 的分类定义）
   ↓
3. POST https://openrouter.ai/api/v1/chat/completions
   ↓
4. 解析 JSON 响应 {"summary": "...", "category": "..."}
   ↓
5. 返回 Result<ClassificationResult, APIError>
   ↓
6. 调用方处理成功/失败
```

### 错误处理

```swift
enum APIError: LocalizedError {
    case unauthorized       // 401/403 - API Key 无效
    case rateLimited        // 429 - 请求过于频繁
    case serverError(Int)   // 5xx - 服务器错误
    case invalidResponse    // 响应格式错误
    case networkError(Error) // 网络连接失败
}
```

每种错误都有清晰的中文提示，便于用户理解。

---

## Obsidian 插件架构

### 组件结构

```typescript
Plugin (main.ts)
├── Settings (LaterReadSettings)
│   ├── claudeApiKey
│   ├── inboxPath
│   ├── archivePath
│   └── autoClassify
│
├── View (LaterReadView)
│   ├── Header
│   ├── ItemList
│   │   ├── ItemRow
│   │   │   ├── Title
│   │   │   ├── Summary
│   │   │   ├── Actions (Read/Delete)
│   │   │   └── Note
│   │   └── ...
│   └── Footer (Add/Digest/Archive)
│
└── Services
    ├── loadItems()
    ├── saveItems()
    ├── classifyWithClaude()
    ├── generateDigest()
    └── archiveRead()
```

### 关键功能

1. **文件监听**：自动监听 `inbox.md` 变更并刷新界面
2. **Claude API**：调用 Claude API 进行分类
3. **Digest 生成**：按周生成阅读清单
4. **归档管理**：已读条目自动归档

---

## 数据格式

### Markdown 结构

```markdown
# 📖 LaterRead Inbox

## 🤖 AI/Tech

- [ ] 🤖 [Title](url) | domain | 2025-01-12
>  Summary text
> 📝 Note text

## 🛠️ Dev Tools

- [x] 🛠️ [Title](url) | domain | 2025-01-11
```

### 解析规则

正则表达式：
```swift
let pattern = #"^- \[([ x])\] (emoji) \[(.+?)\]\((.+?)\) \| (.+?) \| (.+?)$"#
```

字段映射：
- Group 1: `[ ]` 或 `[x]` → `isRead`
- Group 2: Emoji → `category`
- Group 3: Title → `title`
- Group 4: URL → `url`
- Group 5: Domain → `domain`
- Group 6: Date → `createdAt`

摘要和备注：
- 下一行 `>  ` 开头 → `summary`
- 下一行 `> 📝 ` 开头 → `note`

---

## 技术栈

### macOS App

- **语言**：Swift 5.9+
- **UI 框架**：SwiftUI
- **依赖**：
  - [HotKey](https://github.com/soffes/HotKey) - 全局快捷键
  - Keychain Services - 安全存储
  - URLSession - 网络请求

### Obsidian 插件

- **语言**：TypeScript
- **框架**：Obsidian Plugin API
- **构建工具**：esbuild

---

## API 设计

### OpenRouter API

**Endpoint**: `https://openrouter.ai/api/v1/chat/completions`

**Request**:
```json
{
  "model": "google/gemini-2.5-flash-preview-05-20",
  "max_tokens": 200,
  "messages": [
    {
      "role": "user",
      "content": "分析这篇文章并提供：\n1. 中文摘要...\n2. 分类..."
    }
  ]
}
```

**Response**:
```json
{
  "choices": [
    {
      "message": {
        "content": "{\"summary\": \"...\", \"category\": \"ai-tech\"}"
      }
    }
  ]
}
```

### 限流策略

- **单次请求**：立即执行
- **批量分类**：每次请求间隔 0.5 秒
- **重试机制**：429 错误自动等待

---

## 安全设计

### API Key 存储

- **macOS App**：使用系统 Keychain
  ```swift
  KeychainManager.shared.saveAPIKey(key)
  ```

- **Obsidian 插件**：存储在插件设置中（Obsidian 负责加密）

### 权限管理

需要的 macOS 权限：
1. **辅助功能**：全局快捷键
2. **自动化**：控制浏览器（AppleScript）
3. **文件访问**：读写 Obsidian vault

---

## 性能优化

### 文件 I/O

- 使用 `atomically: true` 确保写入安全
- 读取时使用 lazy parsing
- 避免频繁写入（批量操作）

### UI 刷新

- 使用 `@State` 和 `@MainActor` 管理状态
- 后台任务使用 `Task` 异步执行
- 避免阻塞主线程

### API 调用

- 批量分类自动限流
- 使用 `URLSession` 连接池
- 30 秒超时保护

---

## 扩展性

### 添加新分类

1. 编辑 `CategoryManager.swift`:
   ```swift
   "new-cat": ("🎉", "New Category", "keywords")
   ```

2. 更新 `categoryOrder`:
   ```swift
   static let categoryOrder = [..., "new-cat"]
   ```

### 更换 AI 模型

编辑 `Config.swift`:
```swift
static let aiModel = "anthropic/claude-3-sonnet"
static let apiEndpoint = "https://..."
```

### 支持新浏览器

添加到 `BrowserHelper.swift`:
```swift
private static let newBrowserScript = """
tell application "NewBrowser"
    ...
end tell
"""
```

---

## 测试策略

### 单元测试

```swift
// 测试分类逻辑
func testCategoryDetection() {
    let result = CategoryManager.emoji(for: "ai-tech")
    XCTAssertEqual(result, "🤖")
}

// 测试 Markdown 解析
func testMarkdownParsing() {
    let content = "- [ ] 🤖 [Title](url) | domain | 2025-01-12"
    let items = InboxManager.shared.parseMarkdown(content)
    XCTAssertEqual(items.count, 1)
}
```

### 集成测试

- 测试完整的保存流程
- 测试 AI 分类（使用 mock API）
- 测试文件同步

---

## 部署

### 构建 Release

```bash
cd laterread-mvp/menubar-app
swift build -c release
```

### 创建 App Bundle

```bash
mkdir -p LaterRead.app/Contents/MacOS
cp .build/release/LaterRead LaterRead.app/Contents/MacOS/
# 创建 Info.plist
# 代码签名（可选）
```

### 分发

- 直接分发 `.app` 文件
- 或使用 DMG 打包
- 未来：App Store 上架（需要证书）
