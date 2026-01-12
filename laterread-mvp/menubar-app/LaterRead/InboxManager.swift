import Foundation

// ============== Inbox 管理 ==============
class InboxManager {
    static let shared = InboxManager()

    func loadItems() -> [ReadingItem] {
        guard FileManager.default.fileExists(atPath: Config.inboxPath.path),
              let content = try? String(contentsOf: Config.inboxPath, encoding: .utf8) else {
            return []
        }
        return parseMarkdown(content)
    }

    func appendItem(_ item: ReadingItem) throws {
        // 确保目录存在
        let dir = Config.inboxPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 读取现有内容
        var items = loadItems()
        items.insert(item, at: 0)

        // 写回
        let content = generateMarkdown(items)
        try content.write(to: Config.inboxPath, atomically: true, encoding: .utf8)
    }

    func toggleRead(_ item: ReadingItem) throws {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.url == item.url }) {
            items[index].isRead.toggle()
            let content = generateMarkdown(items)
            try content.write(to: Config.inboxPath, atomically: true, encoding: .utf8)
        }
    }

    func updateItem(url: String, category: String, summary: String) throws {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.url == url }) {
            items[index].category = category
            items[index].summary = summary
            let content = generateMarkdown(items)
            try content.write(to: Config.inboxPath, atomically: true, encoding: .utf8)
        }
    }

    func deleteItem(_ item: ReadingItem) throws {
        var items = loadItems()
        items.removeAll { $0.url == item.url }
        let content = generateMarkdown(items)
        try content.write(to: Config.inboxPath, atomically: true, encoding: .utf8)
    }

    func moveToLaterWrite(_ item: ReadingItem, relatedArticles: [String] = []) throws {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.url == item.url }) {
            items[index].category = "laterwrite"
            items[index].isRead = true
            items[index].relatedArticles = relatedArticles
            let content = generateMarkdown(items)
            try content.write(to: Config.inboxPath, atomically: true, encoding: .utf8)
        }
    }

    func updateRelatedArticles(url: String, relatedArticles: [String]) throws {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.url == url }) {
            items[index].relatedArticles = relatedArticles
            let content = generateMarkdown(items)
            try content.write(to: Config.inboxPath, atomically: true, encoding: .utf8)
        }
    }

    private func parseMarkdown(_ content: String) -> [ReadingItem] {
        var items: [ReadingItem] = []
        let lines = content.components(separatedBy: "\n")

        // 支持所有 emoji 的正则（转义特殊字符）
        let allEmojis = CategoryManager.categories.values
            .map { NSRegularExpression.escapedPattern(for: $0.emoji) }
            .joined(separator: "|")

        for (index, line) in lines.enumerated() {
            // 格式: - [ ] 🤖 [Title](url) | domain | 2025-01-10
            let pattern = #"^- \[([ x])\] ("#+allEmojis+#") \[(.+?)\]\((.+?)\) \| (.+?) \| (.+?)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            func group(_ n: Int) -> String {
                guard let range = Range(match.range(at: n), in: line) else { return "" }
                return String(line[range])
            }

            let checked = group(1) == "x"
            let emoji = group(2)
            let title = group(3)
            let url = group(4)
            let domain = group(5)
            let date = group(6)

            let category = CategoryManager.categoryKey(from: emoji)

            var item = ReadingItem(url: url, title: title, domain: domain, createdAt: date, isRead: checked)
            item.category = category

            var currentLineOffset = 1

            // 检查下一行是否是摘要
            if index + currentLineOffset < lines.count && lines[index + currentLineOffset].hasPrefix(">  ") {
                item.summary = String(lines[index + currentLineOffset].dropFirst(3))
                currentLineOffset += 1
            }

            // 检查是否有备注 ("> 📝 " 前缀)
            let notePrefix = "> 📝 "
            if index + currentLineOffset < lines.count && lines[index + currentLineOffset].hasPrefix(notePrefix) {
                item.note = String(lines[index + currentLineOffset].dropFirst(notePrefix.count))
                currentLineOffset += 1
            }

            // 检查是否有关联文章 ("> 🔗 " 前缀)
            let relatedPrefix = "> 🔗 "
            if index + currentLineOffset < lines.count && lines[index + currentLineOffset].hasPrefix(relatedPrefix) {
                let relatedStr = String(lines[index + currentLineOffset].dropFirst(relatedPrefix.count))
                item.relatedArticles = relatedStr.components(separatedBy: ", ").filter { !$0.isEmpty }
            }

            items.append(item)
        }

        return items
    }

    private func generateMarkdown(_ items: [ReadingItem]) -> String {
        var md = "# 📖 LaterRead Inbox\n\n"

        // 按分类分组
        var grouped: [String: [ReadingItem]] = [:]
        for item in items {
            grouped[item.category, default: []].append(item)
        }

        // 使用 CategoryManager 的顺序
        for cat in CategoryManager.categoryOrder {
            guard let catItems = grouped[cat], !catItems.isEmpty else { continue }
            guard let info = CategoryManager.getCategory(cat) else { continue }

            md += "## \(info.emoji) \(info.name)\n\n"

            for item in catItems {
                let checkbox = item.isRead ? "x" : " "
                md += "- [\(checkbox)] \(item.emoji) [\(item.title)](\(item.url)) | \(item.domain) | \(item.createdAt)\n"

                if !item.summary.isEmpty {
                    md += ">  \(item.summary)\n"
                }
                if !item.note.isEmpty {
                    md += "> 📝 \(item.note)\n"
                }
                if !item.relatedArticles.isEmpty {
                    md += "> 🔗 \(item.relatedArticles.joined(separator: ", "))\n"
                }
                md += "\n"
            }
        }

        return md
    }
}
