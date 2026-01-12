import Foundation
import AppKit

// ============== 浏览器抓取 ==============
class BrowserHelper {
    struct PageInfo {
        let url: String
        let title: String
    }

    static func getCurrentPage() -> PageInfo? {
        // 尝试多个浏览器
        for script in [safariScript, chromeScript, arcScript] {
            if let result = runAppleScript(script) {
                return result
            }
        }
        return nil
    }

    private static let safariScript = """
    tell application "System Events"
        if not (exists process "Safari") then return ""
    end tell
    tell application "Safari"
        if (count of windows) = 0 then return ""
        set currentTab to current tab of front window
        return (URL of currentTab) & "|||" & (name of currentTab)
    end tell
    """

    private static let chromeScript = """
    tell application "System Events"
        if not (exists process "Google Chrome") then return ""
    end tell
    tell application "Google Chrome"
        if (count of windows) = 0 then return ""
        set currentTab to active tab of front window
        return (URL of currentTab) & "|||" & (title of currentTab)
    end tell
    """

    private static let arcScript = """
    tell application "System Events"
        if not (exists process "Arc") then return ""
    end tell
    tell application "Arc"
        if (count of windows) = 0 then return ""
        set currentTab to active tab of front window
        return (URL of currentTab) & "|||" & (title of currentTab)
    end tell
    """

    private static func runAppleScript(_ script: String) -> PageInfo? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let result = appleScript.executeAndReturnError(&error).stringValue,
              !result.isEmpty else { return nil }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 2, !parts[0].isEmpty else { return nil }

        return PageInfo(url: parts[0], title: parts[1])
    }
}
