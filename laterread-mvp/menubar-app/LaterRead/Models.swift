import Foundation

// ============== 数据模型 ==============
struct ReadingItem: Identifiable {
    let id = UUID()
    let url: String
    let title: String
    let domain: String
    var summary: String
    var category: String
    var note: String
    var relatedArticles: [String]  // 关联文章的 URLs
    let createdAt: String
    var isRead: Bool

    init(url: String, title: String, domain: String, summary: String = "", category: String = "general", note: String = "", relatedArticles: [String] = [], createdAt: String, isRead: Bool = false) {
        self.url = url
        self.title = title
        self.domain = domain
        self.summary = summary
        self.category = category
        self.note = note
        self.relatedArticles = relatedArticles
        self.createdAt = createdAt
        self.isRead = isRead
    }

    var emoji: String {
        CategoryManager.emoji(for: category)
    }
}
