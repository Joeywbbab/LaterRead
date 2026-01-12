# LaterRead

**稍后阅读管理系统 + AI 智能分类**

一键保存网页，AI 自动分类，Obsidian 集中管理。

---

## ✨ 特性

- 🚀 全局快捷键 `⌘⇧L` 保存当前页面
- 🤖 OpenRouter AI 自动分类和摘要（Gemini 2.5 Flash）
- 📖 10 大智能分类系统
- 🔄 菜单栏 App 和 Obsidian 插件实时同步
- 🌐 支持 Safari、Chrome、Arc
- ⚡ 批量分类 + 进度提示

---

## 🚀 快速开始

### 安装

```bash
cd laterread-mvp
./install.sh
```

### 配置

1. 系统授权：设置 → 隐私与安全性 → 辅助功能 → 添加 LaterRead
2. API Key：菜单栏 → Settings → 填入 [OpenRouter API Key](https://openrouter.ai/keys)

### 使用

- 浏览器中按 `⌘⇧L` 保存当前页面
- 点击菜单栏 📖 图标查看列表
- Obsidian 侧边栏点击 📖 图标管理

详细说明见 [使用指南](docs/USAGE.md) | [故障排除](docs/TROUBLESHOOTING.md)

---

## 📂 项目结构

```
LaterRead/
├── README.md                   # 本文件
├── docs/                       # 文档
│   ├── USAGE.md               # 使用指南
│   ├── TROUBLESHOOTING.md     # 故障排除
│   ├── ARCHITECTURE.md        # 架构设计
│   └── DEVELOPMENT.md         # 开发指南
│
└── laterread-mvp/             # 源代码
    ├── menubar-app/           # macOS 菜单栏 App
    │   └── LaterRead/         # Swift 源码（9 个模块化文件）
    ├── obsidian-plugin/       # Obsidian 插件
    └── install.sh             # 安装脚本
```

---

## 🏗️ 系统架构

```
┌──────────────────────────────┐
│  macOS 菜单栏 App (Swift)    │
│  • 快捷键捕获                 │
│  • AI 自动分类                │
│  • 批量处理                   │
└──────────────────────────────┘
           ↓ ↑
┌──────────────────────────────┐
│  Obsidian Vault              │
│  【00】LaterRead/inbox.md    │
└──────────────────────────────┘
           ↓ ↑
┌──────────────────────────────┐
│  Obsidian 插件 (TypeScript)  │
│  • 侧边栏管理                 │
│  • 归档和 Digest              │
└──────────────────────────────┘
```

详见 [架构设计文档](docs/ARCHITECTURE.md)

---

## 📖 10 大分类

| Emoji | 分类 | 示例 |
|-------|------|------|
| 🤖 | AI/Tech | AI、LLM、机器学习 |
| 🛠️ | Dev Tools | 编程工具、框架 |
| 📦 | Product | SaaS、产品发布 |
| 🎨 | Design | UI/UX、设计系统 |
| 💼 | Business | 创业、投资、营销 |
| 📚 | Research | 学术论文、方法论 |
| 🎯 | Career | 求职、职业发展 |
| ⚡ | Productivity | 效率工具、工作流 |
| 📖 | Reading | 书籍、长文阅读 |
| 📌 | General | 其他 |

---

## 🛠️ 开发

```bash
# Obsidian 插件
cd laterread-mvp/obsidian-plugin
npm run dev

# 菜单栏 App
cd laterread-mvp/menubar-app
swift run
```

详见 [开发指南](docs/DEVELOPMENT.md)

---

## 📝 TODO

- [ ] 浏览器扩展（更精准抓取）
- [ ] iOS Shortcut 支持
- [ ] Raycast 集成
- [ ] 统计面板

---

## 📜 License

MIT License

---

**Built with ❤️ using Swift, SwiftUI, TypeScript, and AI**
