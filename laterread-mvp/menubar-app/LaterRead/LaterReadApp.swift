import SwiftUI
import HotKey
import AppKit

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
        NotificationHelper.shared.requestPermission()
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
            NotificationHelper.shared.send(title: "Cannot get page", body: "Make sure browser window is active")
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
            NotificationHelper.shared.send(title: "Saved ✓", body: "📌 \(item.title)")
            refreshPopoverIfShown()
            classifyInBackground(item)
        } catch {
            NotificationHelper.shared.send(title: "Save failed", body: error.localizedDescription)
        }
    }

    private func classifyInBackground(_ item: ReadingItem) {
        print("[LaterRead] classifyInBackground called for: \(item.title)")

        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            print("[LaterRead] No API Key found in Keychain")
            NotificationHelper.shared.send(title: "AI 分类跳过", body: "未设置 API Key")
            return
        }

        print("[LaterRead] API Key found, length: \(apiKey.count)")
        let itemTitle = String(item.title)
        let itemUrl = String(item.url)
        let itemDomain = String(item.domain)
        let apiKeyCopy = String(apiKey)

        print("[LaterRead] Starting AI classification task...")

        Task {
            let result = await AIService.shared.classify(title: itemTitle, url: itemUrl, domain: itemDomain, apiKey: apiKeyCopy)

            await MainActor.run {
                switch result {
                case .success(let classification):
                    do {
                        try InboxManager.shared.updateItem(url: itemUrl, category: classification.category, summary: classification.summary)
                        NotificationHelper.shared.send(title: "已分类 ✓", body: "\(CategoryManager.emoji(for: classification.category)) \(classification.summary.prefix(30))")
                        self.refreshPopoverIfShown()
                    } catch {
                        // Silent fail - item already saved
                    }
                case .failure(let error):
                    NotificationHelper.shared.send(title: "AI 分类失败", body: error.localizedDescription)
                }
            }
        }
    }

    private func refreshPopoverIfShown() {
        if popover.isShown {
            popover.contentViewController = NSHostingController(rootView: MenuBarView())
        }
    }
}
