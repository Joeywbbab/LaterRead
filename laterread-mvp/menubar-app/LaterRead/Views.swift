import SwiftUI
import AppKit
import UserNotifications

// ============== Menu Bar View ==============
struct MenuBarView: View {
    @State private var items: [ReadingItem] = []
    @State private var hoveredId: UUID?
    @State private var showSettings: Bool = false
    @State private var isClassifying: Bool = false
    @State private var showingNoteDialog: Bool = false
    @State private var noteDialogItem: ReadingItem?
    @State private var noteText: String = ""
    @State private var showingRelatedDialog: Bool = false
    @State private var relatedDialogItem: ReadingItem?

    // 使用 UserDefaults 持久化已提醒的阈值
    private func getLastNotifiedThreshold() -> Int {
        UserDefaults.standard.integer(forKey: "lastNotifiedUnreadThreshold")
    }

    private func setLastNotifiedThreshold(_ value: Int) {
        UserDefaults.standard.set(value, forKey: "lastNotifiedUnreadThreshold")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("📖 LaterRead")
                    .font(.headline)
                Spacer()
                let unreadCount = items.filter { !$0.isRead }.count
                Text("\(unreadCount) unread")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // List
            // 过滤：隐藏「已读 且 超过一周」的条目
            let visibleItems = items.filter { item in
                if !item.isRead {
                    return true  // 未读条目总是显示
                }
                // 已读条目：检查是否超过一周
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                guard let createdDate = dateFormatter.date(from: item.createdAt) else {
                    return true  // 如果无法解析日期，保守地显示
                }
                let daysSinceCreated = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
                return daysSinceCreated < 7  // 不到7天的已读条目仍然显示
            }

            if visibleItems.isEmpty {
                VStack(spacing: 8) {
                    Text("All caught up! 🎉")
                        .foregroundColor(.secondary)
                    Text("Press ⌘⇧L to save current page")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleItems) { item in
                            ItemRow(item: item, isHovered: hoveredId == item.id, allItems: items) {
                                try? InboxManager.shared.toggleRead(item)
                                loadItems()
                            }
                            .onHover { hovering in
                                hoveredId = hovering ? item.id : nil
                            }
                            .onTapGesture {
                                if let url = URL(string: item.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .contextMenu {
                                Button("Add Note...") {
                                    showAddNoteDialog(for: item)
                                }
                                Button("Move to LaterWrite...") {
                                    showMoveToLaterWriteDialog(for: item)
                                }
                                Button("Classify with AI") {
                                    classifyItem(item)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    try? InboxManager.shared.deleteItem(item)
                                    loadItems()
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 350)
            }

            Divider()

            // Footer
            HStack {
                Button("Classify All") {
                    classifyAllItems()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.orange)
                .disabled(isClassifying)

                Spacer()

                Button("Settings") {
                    showSettings = true
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .onAppear { loadItems() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingNoteDialog) {
            if let item = noteDialogItem {
                AddNoteView(
                    item: item,
                    initialNote: item.note,
                    onSave: { note in
                        updateItemNote(item: item, note: note)
                        showingNoteDialog = false
                    },
                    onCancel: {
                        showingNoteDialog = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingRelatedDialog) {
            if let item = relatedDialogItem {
                RelatedArticlesView(
                    item: item,
                    allItems: getAllArticlesForRelation(excluding: item.url),
                    onSave: { relatedUrls in
                        moveItemToLaterWrite(item: item, relatedArticles: relatedUrls)
                        showingRelatedDialog = false
                    },
                    onCancel: {
                        showingRelatedDialog = false
                    }
                )
            }
        }
    }

    private func loadItems() {
        items = InboxManager.shared.loadItems()
        let unreadCount = items.filter { !$0.isRead }.count
        print("[MenuBar] Loaded \(items.count) total items, \(unreadCount) unread")

        // 每次加载数据后检查未读数量提醒
        checkUnreadCountAndNotify(unreadCount: unreadCount)
    }

    // 获取所有可关联的文章（inbox + LaterWrite）
    private func getAllArticlesForRelation(excluding currentUrl: String) -> [ReadingItem] {
        var allArticles: [ReadingItem] = []

        // 添加 inbox 中已读的文章
        allArticles.append(contentsOf: items.filter { $0.url != currentUrl && $0.isRead })

        // 添加 LaterWrite 中的所有文章
        let laterWriteItems = LaterWriteManager.shared.loadItems()
        allArticles.append(contentsOf: laterWriteItems.filter { $0.url != currentUrl })

        return allArticles
    }

    // 检查未读数量阈值并发送提醒
    private func checkUnreadCountAndNotify(unreadCount: Int) {
        let thresholds = [7, 15, 20, 30]
        let currentThreshold = getLastNotifiedThreshold()

        print("[MenuBar] Checking unread reminder: count=\(unreadCount), lastNotified=\(currentThreshold)")

        // 只在恰好达到新阈值且未读数量增加时提醒
        if thresholds.contains(unreadCount) && unreadCount > currentThreshold {
            let message = getUnreadReminderMessage(count: unreadCount)
            showLocalNotification(title: "📚 阅读提醒", body: message)
            print("[MenuBar] ✅ Unread reminder triggered: \(unreadCount) items")
            setLastNotifiedThreshold(unreadCount)
        } else if unreadCount < currentThreshold {
            // 如果未读数量减少到上一个阈值以下，重置记录
            let previousThreshold = thresholds.reversed().first { $0 < unreadCount } ?? 0
            setLastNotifiedThreshold(previousThreshold)
            print("[MenuBar] ⬇️ Reset threshold to \(previousThreshold) (current: \(unreadCount))")
        }
    }

    private func getUnreadReminderMessage(count: Int) -> String {
        switch count {
        case 7:
            return "你有 7 篇未读文章了，抽空看看吧 📖"
        case 15:
            return "未读文章已达 15 篇，别让好内容积灰哦 ⏰"
        case 20:
            return "20 篇未读！周末计划一下阅读时间？ 🎯"
        case 30:
            return "30 篇未读文章堆积中...该清理 inbox 了 🧹"
        default:
            return "你有 \(count) 篇未读文章"
        }
    }

    private func showAddNoteDialog(for item: ReadingItem) {
        noteDialogItem = item
        noteText = item.note
        showingNoteDialog = true
    }

    private func showMoveToLaterWriteDialog(for item: ReadingItem) {
        relatedDialogItem = item
        showingRelatedDialog = true
    }

    private func updateItemNote(item: ReadingItem, note: String) {
        // InboxManager 需要一个更新备注的方法
        var updatedItem = item
        updatedItem.note = note

        // 先删除旧的，再添加新的（简单实现）
        try? InboxManager.shared.deleteItem(item)
        try? InboxManager.shared.appendItem(updatedItem)
        loadItems()
    }

    private func moveItemToLaterWrite(item: ReadingItem, relatedArticles: [String]) {
        do {
            try InboxManager.shared.moveToLaterWrite(item, relatedArticles: relatedArticles)
            loadItems()
            showLocalNotification(title: "Moved to LaterWrite ✓", body: "✍️ \(item.title)")
        } catch {
            showLocalNotification(title: "Move failed", body: error.localizedDescription)
        }
    }

    private func classifyItem(_ item: ReadingItem) {
        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            showLocalNotification(title: "分类失败", body: "未设置 API Key")
            return
        }

        // 获取已有条目作为上下文
        let existingItems = items
            .filter { !$0.title.isEmpty && $0.url != item.url }
            .prefix(10)
            .map { "- [\($0.category)] \($0.title)" }

        let itemUrl = item.url
        let itemTitle = item.title
        let itemDomain = item.domain

        Task {
            let result = await AIService.shared.classify(
                title: itemTitle,
                url: itemUrl,
                domain: itemDomain,
                apiKey: apiKey,
                existingItems: Array(existingItems)
            )

            await MainActor.run {
                switch result {
                case .success(let classification):
                    try? InboxManager.shared.updateItem(url: itemUrl, category: classification.category, summary: classification.summary)
                    loadItems()
                case .failure(let error):
                    showLocalNotification(title: "分类失败", body: error.localizedDescription)
                }
            }
        }
    }

    private func classifyAllItems() {
        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            showLocalNotification(title: "分类跳过", body: "未设置 API Key，请先在设置中配置")
            return
        }

        // 只对未读且需要分类的条目进行分类
        let needsClassification = items.filter {
            !$0.isRead && ($0.summary.isEmpty || $0.category.isEmpty || $0.category == "general")
        }
        guard !needsClassification.isEmpty else {
            showLocalNotification(title: "无需分类", body: "所有未读条目都已分类完成")
            return
        }

        isClassifying = true
        let total = needsClassification.count
        showLocalNotification(title: "开始分类", body: "正在处理 \(total) 个条目...")

        Task {
            var classified = 0
            var failed = 0
            var lastError: String?

            // 获取已分类的条目作为上下文（随着分类进行会动态更新）
            var contextItems = items
                .filter { !$0.summary.isEmpty && !$0.title.isEmpty }
                .map { "- [\($0.category)] \($0.title)" }

            for (index, item) in needsClassification.enumerated() {
                let result = await AIService.shared.classify(
                    title: item.title,
                    url: item.url,
                    domain: item.domain,
                    apiKey: apiKey,
                    existingItems: Array(contextItems.prefix(10))
                )

                await MainActor.run {
                    switch result {
                    case .success(let classification):
                        try? InboxManager.shared.updateItem(url: item.url, category: classification.category, summary: classification.summary)
                        loadItems()
                        classified += 1

                        // 更新上下文：将刚分类的条目加入上下文列表
                        contextItems.append("- [\(classification.category)] \(item.title)")

                        // 每处理 3 个条目显示进度
                        if (index + 1) % 3 == 0 || (index + 1) == total {
                            showLocalNotification(title: "分类进度", body: "已完成 \(index + 1)/\(total)")
                        }
                    case .failure(let error):
                        failed += 1
                        lastError = error.localizedDescription
                    }
                }

                // 避免 API 限流，每次请求间隔 0.5 秒
                if index < needsClassification.count - 1 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }

            await MainActor.run {
                isClassifying = false
                if classified > 0 {
                    let message = "成功 \(classified) 个" + (failed > 0 ? "，失败 \(failed) 个" : "")
                    showLocalNotification(title: "分类完成 ✓", body: message)
                } else {
                    showLocalNotification(title: "分类失败", body: lastError ?? "所有请求均失败")
                }
            }
        }
    }

    private func showLocalNotification(title: String, body: String) {
        // 如果不在 bundle 中运行（开发模式），只打印日志
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Notification] \(title): \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// ============== Item Row ==============
struct ItemRow: View {
    let item: ReadingItem
    let isHovered: Bool
    let allItems: [ReadingItem]  // 用于查找关联文章的标题
    let onToggleRead: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Checkbox
            Button(action: onToggleRead) {
                Image(systemName: item.isRead ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isRead ? .green : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .strikethrough(item.isRead, color: .secondary)
                    .foregroundColor(item.isRead ? .secondary : .primary)

                HStack {
                    Text(item.domain)
                    Text("·")
                    Text(item.createdAt)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if isHovered && !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if !item.note.isEmpty {
                    HStack(spacing: 4) {
                        Text("📝")
                            .font(.caption)
                        Text(item.note)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }

                if !item.relatedArticles.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("🔗")
                                .font(.caption)
                            Text("Related (\(item.relatedArticles.count)):")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }

                        // 创建 URL 到文章的映射
                        let urlToItem = Dictionary(uniqueKeysWithValues: allItems.map { ($0.url, $0) })

                        // 显示关联文章的标题
                        ForEach(item.relatedArticles.prefix(3), id: \.self) { url in
                            if let relatedItem = urlToItem[url] {
                                Text("  • \(relatedItem.title)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }

                        if item.relatedArticles.count > 3 {
                            Text("  • +\(item.relatedArticles.count - 3) more...")
                                .font(.system(size: 10))
                                .foregroundColor(.purple.opacity(0.6))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
}

// ============== Quick Add Window ==============
// 自定义窗口类，支持键盘输入
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class QuickAddWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let pageInfo: BrowserHelper.PageInfo
    private var completion: ((ReadingItem?) -> Void)?
    private var hasCompleted = false

    init(pageInfo: BrowserHelper.PageInfo, completion: @escaping (ReadingItem?) -> Void) {
        self.pageInfo = pageInfo
        self.completion = completion
        super.init()
    }

    func show() {
        // 捕获需要的值，避免在闭包中捕获 self
        let urlString = pageInfo.url
        let titleString = pageInfo.title

        let view = QuickAddView(
            url: urlString,
            title: titleString,
            onSave: { [weak self] item in
                self?.handleCompletion(item)
            },
            onCancel: { [weak self] in
                self?.handleCompletion(nil)
            }
        )

        let hostingView = NSHostingView(rootView: view)

        let newWindow = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.level = .floating
        newWindow.hasShadow = true
        newWindow.delegate = self

        // 居中显示
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 340) / 2
            let y = (screen.frame.height - 180) / 2 + 100
            newWindow.setFrame(NSRect(x: x, y: y, width: 340, height: 180), display: true)
        }

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleCompletion(_ item: ReadingItem?) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // 保存引用
        let savedCompletion = completion
        let windowToClose = window

        completion = nil
        window = nil

        // 先关闭窗口
        windowToClose?.orderOut(nil)

        // 再调用 completion
        savedCompletion?(item)
    }

    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时确保调用 completion
        if !hasCompleted {
            handleCompletion(nil)
        }
    }
}

struct QuickAddView: View {
    let url: String
    let title: String
    let onSave: (ReadingItem) -> Void
    let onCancel: () -> Void

    @State private var note: String = ""

    var domain: String {
        URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? "unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.accentColor)
                Text("Save to LaterRead")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                Text(domain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Note
            TextField("Note (optional)", text: $note)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // Actions
            HStack {
                Spacer()

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    saveItem()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }

            Text("Auto AI classification after save")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }

    private func saveItem() {
        // 使用本地时区的日期格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        let item = ReadingItem(
            url: url,
            title: title,
            domain: domain,
            summary: "",
            category: "general",  // 默认分类，后台会更新
            note: note,
            createdAt: dateFormatter.string(from: Date()),
            isRead: false
        )
        onSave(item)
    }
}

// ============== Add Note View ==============
struct AddNoteView: View {
    let item: ReadingItem
    let initialNote: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var note: String

    init(item: ReadingItem, initialNote: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.initialNote = initialNote
        self.onSave = onSave
        self.onCancel = onCancel
        self._note = State(initialValue: initialNote)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("📝 Add Note")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Article info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                Text(item.domain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Note input
            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $note)
                    .font(.system(size: 13))
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3), width: 1)
            }

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    onSave(note)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 340, height: 280)
    }
}

// ============== Related Articles View ==============
struct RelatedArticlesView: View {
    let item: ReadingItem
    let allItems: [ReadingItem]
    let onSave: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selectedUrls: Set<String>

    init(item: ReadingItem, allItems: [ReadingItem], onSave: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.allItems = allItems
        self.onSave = onSave
        self.onCancel = onCancel
        self._selectedUrls = State(initialValue: Set(item.relatedArticles))
    }

    // 智能排序：同分类的文章排在前面
    var sortedItems: [ReadingItem] {
        allItems.sorted { a, b in
            let aScore = (a.category == item.category) ? 1 : 0
            let bScore = (b.category == item.category) ? 1 : 0
            if aScore != bScore {
                return aScore > bScore
            }
            return a.createdAt > b.createdAt
        }
    }

    // 判断文章是否为推荐关联
    func isRecommended(_ relatedItem: ReadingItem) -> Bool {
        return relatedItem.category == item.category
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("✍️ Move to LaterWrite")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Article info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("\(item.emoji) \(item.domain)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Related articles selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select related articles (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if selectedUrls.count > 0 {
                        Text("\(selectedUrls.count) selected")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if allItems.isEmpty {
                    Text("No read articles available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(sortedItems) { relatedItem in
                                Toggle(isOn: Binding(
                                    get: { selectedUrls.contains(relatedItem.url) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedUrls.insert(relatedItem.url)
                                        } else {
                                            selectedUrls.remove(relatedItem.url)
                                        }
                                    }
                                )) {
                                    HStack(alignment: .top, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(relatedItem.title)
                                                    .font(.system(size: 12))
                                                    .lineLimit(3)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                if isRecommended(relatedItem) {
                                                    Text("推荐")
                                                        .font(.system(size: 9, weight: .medium))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue)
                                                        .cornerRadius(3)
                                                }
                                            }

                                            Text("\(relatedItem.emoji) \(relatedItem.domain)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)

                                            if !relatedItem.summary.isEmpty {
                                                Text(relatedItem.summary)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary.opacity(0.8))
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .padding(.vertical, 4)

                                if relatedItem.id != sortedItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 280)
                }
            }

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Move to LaterWrite") {
                    onSave(Array(selectedUrls))
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }

            Text("This will mark as read and move to ✍️ LaterWrite section")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 480, height: 540)
    }
}

// ============== Settings View ==============
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var saveStatus: String = ""
    @State private var hasExistingKey: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("⚙️ Settings")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // API Key Status
            if hasExistingKey {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API Key is configured")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No API Key configured - AI features disabled")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenRouter API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Used for auto classification and summary")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    if showKey {
                        TextField("sk-or-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    } else {
                        SecureField("sk-or-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Button("Save") {
                        print("[Settings] Saving API Key, length: \(apiKey.count)")
                        if KeychainManager.shared.saveAPIKey(apiKey) {
                            saveStatus = "✓ Saved to Keychain"
                            hasExistingKey = !apiKey.isEmpty
                            print("[Settings] API Key saved successfully")
                        } else {
                            saveStatus = "✗ Save failed"
                            print("[Settings] API Key save failed")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear") {
                        print("[Settings] Clearing API Key")
                        if KeychainManager.shared.deleteAPIKey() {
                            apiKey = ""
                            saveStatus = "✓ Cleared"
                            hasExistingKey = false
                            print("[Settings] API Key cleared")
                        }
                    }
                    .buttonStyle(.bordered)

                    if !saveStatus.isEmpty {
                        Text(saveStatus)
                            .font(.caption)
                            .foregroundColor(saveStatus.contains("✓") ? .green : .red)
                    }
                }
            }

            Divider()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Vault Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(Config.obsidianVault.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Footer
            HStack {
                Text("LaterRead v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Link("获取 API Key", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 340, height: 360)
        .onAppear {
            if let key = KeychainManager.shared.getAPIKey(), !key.isEmpty {
                apiKey = key
                hasExistingKey = true
                print("[Settings] Found existing API Key, length: \(key.count)")
            } else {
                hasExistingKey = false
                print("[Settings] No API Key found")
            }
        }
    }
}
