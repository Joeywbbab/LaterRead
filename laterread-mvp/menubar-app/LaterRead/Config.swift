import Foundation

// ============== 配置 ==============
struct Config {
    // Obsidian vault 配置
    static let vaultName = "Joeyyyyuwww"
    static let inboxRelativePath = "【00】LaterRead/inbox.md"
    static let laterWriteRelativePath = "【00】LaterRead/LaterWrite.md"

    // Obsidian vault 路径
    static let obsidianVault = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/iCloud~md~obsidian/Documents/\(vaultName)")
    static let inboxPath = obsidianVault.appendingPathComponent(inboxRelativePath)
    static let laterWritePath = obsidianVault.appendingPathComponent(laterWriteRelativePath)

    // OpenRouter API
    static let keychainService = "com.laterread.api"
    static let keychainAccount = "openrouter-api-key"
    static let aiModel = "google/gemini-3-flash-preview"  // Gemini 3 Flash Preview（官方文档确认）
    static let apiEndpoint = "https://openrouter.ai/api/v1/chat/completions"

    // 生成 Obsidian URL
    static func obsidianURL(for file: String) -> URL? {
        let encodedVault = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? vaultName
        let encodedFile = file.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? file
        return URL(string: "obsidian://open?vault=\(encodedVault)&file=\(encodedFile)")
    }
}
