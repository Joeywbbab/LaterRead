import Foundation

// ============== AI API 服务 (OpenRouter) ==============
class AIService {
    static let shared = AIService()

    struct ClassificationResult {
        let summary: String
        let category: String
    }

    enum APIError: LocalizedError {
        case unauthorized
        case rateLimited
        case serverError(Int)
        case invalidResponse
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "API Key 无效或已过期"
            case .rateLimited:
                return "API 请求过于频繁，请稍后再试"
            case .serverError(let code):
                return "服务器错误 (\(code))"
            case .invalidResponse:
                return "API 返回格式错误"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            }
        }
    }

    func classify(title: String, url: String, domain: String, apiKey: String, existingItems: [String] = []) async -> Result<ClassificationResult, APIError> {
        print("[AI] ===== 开始分类 =====")
        print("[AI] Title: \(title)")
        print("[AI] URL: \(url)")
        print("[AI] Domain: \(domain)")
        print("[AI] API Key length: \(apiKey.count)")
        print("[AI] Context: \(existingItems.count) existing items")

        guard !apiKey.isEmpty else {
            print("[AI] Error: API Key is empty")
            return .failure(.unauthorized)
        }

        let categoryPrompt = CategoryManager.generateCategoryPrompt()
        print("[AI] Category prompt generated")

        // 构建上下文信息
        var contextSection = ""
        if !existingItems.isEmpty {
            contextSection = """

            当前 Inbox 中已有的文章（供参考，帮助你做更一致的分类）：
            \(existingItems.prefix(10).joined(separator: "\n"))
            """
        }

        let prompt = """
        分析这篇文章并提供：
        1. 中文摘要（1-2句话，最多80字）
        2. 分类（从下面选择最匹配的分类 key）

        待分类文章：
        标题: \(title)
        URL: \(url)
        来源: \(domain)
        \(contextSection)

        \(categoryPrompt)

        重要分类原则：
        - 如果新文章与已有文章主题相关（如都谈论同一个工具、概念、领域），应该归到相同分类
        - 例如：多篇关于 Figma、设计工具的文章应该都归到同一类
        - 例如：多篇关于 ReAct、AI Agent 的文章应该都归到 ai-tech
        - 必须选择一个具体分类，只有在完全无法归类时才用 "general"
        - 返回分类 key（如 "ai-tech", "product"），不是名称
        - 摘要必须是中文，简洁精准

        只返回 JSON: {"summary": "中文摘要", "category": "分类key"}
        """

        let requestBody: [String: Any] = [
            "model": Config.aiModel,
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        guard let apiURL = URL(string: Config.apiEndpoint),
              let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("[AI] Error: Failed to create request")
            return .failure(.invalidResponse)
        }

        print("[AI] Request URL: \(Config.apiEndpoint)")
        print("[AI] Request model: \(Config.aiModel)")

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = 30

        print("[AI] Sending request...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[AI] Invalid response type")
                return .failure(.invalidResponse)
            }

            print("[AI] HTTP Status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                // 即使是 200，也打印响应体前 500 字符以便调试
                if let preview = String(data: data, encoding: .utf8) {
                    print("[AI] Response preview: \(preview.prefix(500))")
                }
            case 401, 403:
                print("[AI] Unauthorized: \(httpResponse.statusCode)")
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("[AI] Error body: \(errorBody)")
                }
                return .failure(.unauthorized)
            case 429:
                print("[AI] Rate limited")
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("[AI] Error body: \(errorBody)")
                }
                return .failure(.rateLimited)
            default:
                print("[AI] HTTP error: \(httpResponse.statusCode)")
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("[AI] Error body: \(errorBody)")
                }
                return .failure(.serverError(httpResponse.statusCode))
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                print("[AI] Failed to parse response JSON")
                return .failure(.invalidResponse)
            }

            print("[AI] Raw response: \(text)")

            // 尝试多种方式提取 JSON
            var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

            // 方法1: 直接解析整个响应
            if let data = jsonString.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let summary = result["summary"],
               let category = result["category"] {
                print("[AI] Parsed (direct): category=\(category), summary=\(summary)")
                return .success(ClassificationResult(summary: summary, category: category))
            }

            // 方法2: 移除可能的 markdown 代码块标记
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

            // 方法3: 提取第一个完整的 JSON 对象 {...}
            if let startIndex = jsonString.firstIndex(of: "{"),
               let endIndex = jsonString.lastIndex(of: "}") {
                let range = startIndex...endIndex
                jsonString = String(jsonString[range])
            }

            // 最后尝试解析
            if let data = jsonString.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                let summary = result["summary"] ?? ""
                let category = result["category"] ?? "general"
                print("[AI] Parsed (extracted): category=\(category), summary=\(summary)")
                return .success(ClassificationResult(summary: summary, category: category))
            } else {
                print("[AI] Failed to extract JSON from response")
                print("[AI] Attempted to parse: \(jsonString.prefix(200))")
                return .failure(.invalidResponse)
            }
        } catch {
            print("[AI] Network error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
}
