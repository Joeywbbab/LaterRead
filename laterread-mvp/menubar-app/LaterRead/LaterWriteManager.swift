import Foundation

// ============== LaterWrite 管理器 ==============
class LaterWriteManager {
    static let shared = LaterWriteManager()

    private init() {}

    // 加载 LaterWrite 文章
    func loadItems() -> [ReadingItem] {
        guard let content = try? String(contentsOf: Config.laterWritePath, encoding: .utf8) else {
            print("[LaterWrite] File not found, creating new one")
            createEmptyFile()
            return []
        }
        return parseMarkdown(content)
    }

    // 添加文章到 LaterWrite（设为未读状态）
    func addItem(_ item: ReadingItem, relatedArticles: [String] = []) throws {
        var items = loadItems()

        // 创建新的未读文章
        var newItem = item
        newItem.isRead = false  // 强制设为未读
        newItem.category = "laterwrite"
        newItem.relatedArticles = relatedArticles

        // 检查是否已存在
        if !items.contains(where: { $0.url == newItem.url }) {
            items.append(newItem)
        }

        let content = generateMarkdown(items)
        try content.write(to: Config.laterWritePath, atomically: true, encoding: .utf8)
        print("[LaterWrite] Added item: \(newItem.title)")
    }

    // 切换已读状态
    func toggleRead(_ item: ReadingItem) throws {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.url == item.url }) {
            items[index].isRead.toggle()
            let content = generateMarkdown(items)
            try content.write(to: Config.laterWritePath, atomically: true, encoding: .utf8)
        }
    }

    // 删除文章
    func deleteItem(_ item: ReadingItem) throws {
        var items = loadItems()
        items.removeAll { $0.url == item.url }
        let content = generateMarkdown(items)
        try content.write(to: Config.laterWritePath, atomically: true, encoding: .utf8)
    }

    // 创建空文件
    private func createEmptyFile() {
        let content = """
        # ✍️ LaterWrite

        待输出的内容创意和关联文章

        """
        try? content.write(to: Config.laterWritePath, atomically: true, encoding: .utf8)
    }

    // 解析 Markdown
    private func parseMarkdown(_ content: String) -> [ReadingItem] {
        var items: [ReadingItem] = []
        let lines = content.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            // 匹配格式：- [x] 📌 [title](url) | domain | date
            let pattern = #"^- \[([ x])\] (.+?) \[(.+?)\]\((.+?)\) \| (.+?) \| (.+?)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            let group = { (i: Int) -> String in
                guard let range = Range(match.range(at: i), in: line) else { return "" }
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

            // 检查摘要
            if index + currentLineOffset < lines.count && lines[index + currentLineOffset].hasPrefix(">  ") {
                item.summary = String(lines[index + currentLineOffset].dropFirst(3))
                currentLineOffset += 1
            }

            // 检查备注
            let notePrefix = "> 📝 "
            if index + currentLineOffset < lines.count && lines[index + currentLineOffset].hasPrefix(notePrefix) {
                item.note = String(lines[index + currentLineOffset].dropFirst(notePrefix.count))
                currentLineOffset += 1
            }

            // 检查关联文章
            let relatedPrefix = "> 🔗 "
            if index + currentLineOffset < lines.count && lines[index + currentLineOffset].hasPrefix(relatedPrefix) {
                let relatedStr = String(lines[index + currentLineOffset].dropFirst(relatedPrefix.count))
                item.relatedArticles = relatedStr.components(separatedBy: ", ").filter { !$0.isEmpty }
            }

            items.append(item)
        }

        return items
    }

    // 生成 Markdown
    private func generateMarkdown(_ items: [ReadingItem]) -> String {
        var md = "# ✍️ LaterWrite\n\n"
        md += "待输出的内容创意和关联文章\n\n"
        md += "---\n\n"

        // 按日期分组
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }

        for item in sortedItems {
            let checkbox = item.isRead ? "x" : " "
            md += "- [\(checkbox)] \(item.emoji) [\(item.title)](\(item.url)) | \(item.domain) | \(item.createdAt)\n"

            if !item.summary.isEmpty {
                md += ">  \(item.summary)\n"
            }
            if !item.note.isEmpty {
                md += "> 📝 \(item.note)\n"
            }
            if !item.relatedArticles.isEmpty {
                md += "> 🔗 Related: \(item.relatedArticles.joined(separator: ", "))\n"
            }
            md += "\n"
        }

        return md
    }
}
