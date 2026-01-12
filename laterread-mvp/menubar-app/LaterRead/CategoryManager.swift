import Foundation

// ============== 分类管理 ==============
struct CategoryManager {
    // 可自定义的分类列表
    static var categories: [String: (emoji: String, name: String, keywords: String)] = [
        "ai-tech": ("🤖", "AI/Tech", "AI, machine learning, LLM, GPT, Claude, deep learning, neural network, automation, agents, prompts"),
        "dev-tools": ("🛠️", "Dev Tools", "programming, coding, developer tools, IDE, API, SDK, framework, library, open source"),
        "product": ("📦", "Product", "product launch, startup, SaaS, app, tool, software, service, platform"),
        "design": ("🎨", "Design", "UI, UX, design system, figma, interface, visual, typography, branding"),
        "business": ("💼", "Business", "startup, funding, investment, strategy, growth, marketing, sales, revenue"),
        "research": ("📚", "Research", "paper, study, academic, methodology, analysis, experiment, findings"),
        "career": ("🎯", "Career", "job, hiring, interview, resume, skills, career growth, salary, remote work"),
        "productivity": ("⚡", "Productivity", "workflow, efficiency, habits, time management, tools, automation, life hacks"),
        "reading": ("📖", "Reading", "book, article, blog post, newsletter, essay, long read, writing"),
        "laterwrite": ("✍️", "LaterWrite", "articles to write about, content ideas, writing inspiration, potential blog posts"),
        "general": ("📌", "General", "everything else, misc, uncategorized")
    ]

    // 分类顺序
    static let categoryOrder = ["ai-tech", "dev-tools", "product", "design", "business", "research", "career", "productivity", "reading", "laterwrite", "general"]

    // 生成给 AI 的分类提示
    static func generateCategoryPrompt() -> String {
        var prompt = "Categories (choose the BEST match):\n"
        for key in categoryOrder {
            if let cat = categories[key] {
                prompt += "- \(key): \(cat.name) - \(cat.keywords)\n"
            }
        }
        return prompt
    }

    // 获取分类信息
    static func getCategory(_ key: String) -> (emoji: String, name: String)? {
        if let cat = categories[key] {
            return (cat.emoji, cat.name)
        }
        return nil
    }

    // 获取 emoji
    static func emoji(for key: String) -> String {
        categories[key]?.emoji ?? "📌"
    }

    // 从 emoji 反查分类 key
    static func categoryKey(from emoji: String) -> String {
        categories.first { $0.value.emoji == emoji }?.key ?? "general"
    }
}
