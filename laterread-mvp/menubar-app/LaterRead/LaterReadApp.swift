import SwiftUI
import HotKey
import AppKit
import UserNotifications

// ============== App 入口 ==============
// IMPORTANT: 全局强引用 appDelegate 防止被 ARC 释放
// macOS menubar app 需要手动管理 delegate 生命周期，否则 app 会立即退出
// 不要删除这个全局变量！
private var appDelegate: AppDelegate!

@main
struct LaterReadApp {
    static func main() {
        let app = NSApplication.shared
        appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

// ============== App Delegate ==============
class AppDelegate: NSObject, NSApplicationDelegate {
    // 强引用 statusItem，确保不会被释放
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotKey: HotKey?
    private var quickAddWindow: QuickAddWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotKey()
        requestNotificationPermission()
    }

    // 防止 app 在关闭最后一个窗口时退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        // 创建 statusItem 并立即配置
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // 使用文字作为备选，SF Symbol 在某些情况下可能不显示
            if let image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "LaterRead") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "📖"
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func setupHotKey() {
        hotKey = HotKey(key: .l, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.captureCurrentPage()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.contentViewController = NSHostingController(rootView: MenuBarView())
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func captureCurrentPage() {
        guard let pageInfo = BrowserHelper.getCurrentPage() else {
            showNotification(title: "Cannot get page", body: "Make sure browser window is active")
            return
        }

        quickAddWindow = QuickAddWindow(pageInfo: pageInfo) { [weak self] item in
            if let item = item {
                self?.saveItem(item)
            }
            self?.quickAddWindow = nil
        }
        quickAddWindow?.show()
    }

    private func saveItem(_ item: ReadingItem) {
        do {
            try InboxManager.shared.appendItem(item)
            showNotification(title: "Saved ✓", body: "📌 \(item.title)")
            refreshPopoverIfShown()
            classifyInBackground(item)

            // 检查未读数量并发送提醒
            checkUnreadCountAndNotify()
        } catch {
            showNotification(title: "Save failed", body: error.localizedDescription)
        }
    }

    // 检查未读数量阈值并发送提醒
    private func checkUnreadCountAndNotify() {
        let items = InboxManager.shared.loadItems()
        let unreadCount = items.filter { !$0.isRead }.count

        // 定义提醒阈值
        let thresholds = [7, 15, 20, 30]

        // 检查是否达到某个阈值
        if thresholds.contains(unreadCount) {
            let message = getUnreadReminderMessage(count: unreadCount)
            showNotification(title: "📚 阅读提醒", body: message)
            print("[LaterRead] Unread reminder: \(unreadCount) items")
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

    private func classifyInBackground(_ item: ReadingItem) {
        print("[LaterRead] classifyInBackground called for: \(item.title)")

        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            print("[LaterRead] No API Key found in Keychain")
            showNotification(title: "AI 分类跳过", body: "未设置 API Key")
            return
        }

        print("[LaterRead] API Key found, length: \(apiKey.count)")

        // 获取已有条目作为上下文
        let existingItems = InboxManager.shared.loadItems()
            .filter { !$0.title.isEmpty }
            .prefix(10)
            .map { "- [\($0.category)] \($0.title)" }

        let itemTitle = String(item.title)
        let itemUrl = String(item.url)
        let itemDomain = String(item.domain)
        let apiKeyCopy = String(apiKey)

        print("[LaterRead] Starting AI classification task with \(existingItems.count) context items...")

        Task {
            let result = await AIService.shared.classify(
                title: itemTitle,
                url: itemUrl,
                domain: itemDomain,
                apiKey: apiKeyCopy,
                existingItems: Array(existingItems)
            )

            await MainActor.run {
                switch result {
                case .success(let classification):
                    do {
                        try InboxManager.shared.updateItem(url: itemUrl, category: classification.category, summary: classification.summary)
                        self.showNotification(title: "已分类 ✓", body: "\(CategoryManager.emoji(for: classification.category)) \(classification.summary.prefix(30))")
                        self.refreshPopoverIfShown()
                    } catch {
                        // Silent fail - item already saved
                    }
                case .failure(let error):
                    self.showNotification(title: "AI 分类失败", body: error.localizedDescription)
                }
            }
        }
    }

    private func refreshPopoverIfShown() {
        if popover.isShown {
            popover.contentViewController = NSHostingController(rootView: MenuBarView())
        }
    }

    // 检查是否在有效的 app bundle 中运行（UNUserNotificationCenter 需要 bundle）
    private var isRunningInBundle: Bool {
        return Bundle.main.bundleIdentifier != nil
    }

    private func showNotification(title: String, body: String) {
        // 如果不在 bundle 中运行（开发模式），只打印日志
        guard isRunningInBundle else {
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

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    func requestNotificationPermission() {
        // 如果不在 bundle 中运行（开发模式），跳过通知权限请求
        guard isRunningInBundle else {
            print("[LaterRead] Running without bundle - notifications disabled")
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
