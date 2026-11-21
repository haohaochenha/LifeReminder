import Foundation

enum AIServiceError: LocalizedError {
    case missingKey
    case badResponse(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "请先在「设置」中填写 DeepSeek API Key"
        case .badResponse(let message):
            return message
        case .empty:
            return "没有识别到可执行的任务，换个说法试试"
        }
    }
}

struct DeepSeekService {
    struct Message: Codable {
        let role: String
        let content: String
    }

    private struct ChatBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
        let response_format: ResponseFormat

        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            let message: Message
        }
        let choices: [Choice]
    }

    private struct Payload: Decodable {
        let tasks: [Item]
    }

    private struct Item: Decodable {
        let title: String
        let note: String?
        let dueDate: String?
        let priority: String?
        let leadMinutes: Int?
        let tag: String?
    }

    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    // MARK: - Public API

    static func parse(text: String, apiKey: String, model: String, now: Date = Date()) async throws -> [AIDraft] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIServiceError.missingKey }

        let system = systemPrompt(now: now)
        let messages = [
            Message(role: "system", content: system),
            Message(role: "user", content: text)
        ]
        let content = try await chat(messages: messages,
                                     apiKey: key,
                                     model: model,
                                     jsonMode: true,
                                     maxTokens: 900,
                                     temperature: 0.3)

        let json = stripCodeFence(content)
        guard let data = json.data(using: .utf8) else {
            throw AIServiceError.badResponse("AI 返回内容编码异常")
        }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw AIServiceError.badResponse("AI 返回格式无法解析，请重试一次\n\(String(json.prefix(120)))")
        }

        let drafts = payload.tasks.compactMap(makeDraft)
        guard !drafts.isEmpty else { throw AIServiceError.empty }
        return drafts
    }

    static func test(apiKey: String, model: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIServiceError.missingKey }
        let reply = try await chat(messages: [Message(role: "user", content: "只回复两个字：正常")],
                                   apiKey: key,
                                   model: model,
                                   jsonMode: false,
                                   maxTokens: 20,
                                   temperature: 0)
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Networking

    private static func chat(messages: [Message],
                             apiKey: String,
                             model: String,
                             jsonMode: Bool,
                             maxTokens: Int,
                             temperature: Double) async throws -> String {
        let body = ChatBody(model: model,
                            messages: messages,
                            temperature: temperature,
                            max_tokens: maxTokens,
                            response_format: ChatBody.ResponseFormat(type: jsonMode ? "json_object" : "text"))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.badResponse("网络连接失败：\(error.localizedDescription)")
        }
        let data = result.0
        let response = result.1

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.badResponse("无效的服务器响应")
        }

        guard (200..<300).contains(http.statusCode) else {
            let detail = errorMessage(from: data)
            throw AIServiceError.badResponse("DeepSeek 请求失败（\(http.statusCode)）\(detail)")
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw AIServiceError.badResponse("AI 没有返回内容")
            }
            return content
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.badResponse("AI 返回内容无法解析")
        }
    }

    private static func errorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return "：\(message)"
        }
        return ""
    }

    // MARK: - Parsing helpers

    private static func makeDraft(_ item: Item) -> AIDraft? {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return AIDraft(title: title,
                       note: (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                       tag: normalizedTag(item.tag),
                       dueDate: parseDate(item.dueDate),
                       priority: parsePriority(item.priority),
                       leadMinutes: min(180, max(0, item.leadMinutes ?? 10)))
    }

    private static func normalizedTag(_ raw: String?) -> String {
        let allowed = ["生活", "工作", "健康", "计划", "学习", "家务"]
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if allowed.contains(value) { return value }
        return value.isEmpty ? "生活" : String(value.prefix(6))
    }

    private static func parsePriority(_ raw: String?) -> TaskPriority {
        switch (raw ?? "").lowercased() {
        case "high", "重要", "紧急", "高": return .high
        case "low", "不急", "低": return .low
        default: return .normal
        }
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        text = text.replacingOccurrences(of: "T", with: " ")
        let calendar = Calendar.current
        let hasClock = text.contains(":")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = hasClock ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"

        guard var date = formatter.date(from: String(text.prefix(hasClock ? 16 : 10))) else {
            return nil
        }

        // AI 偶尔会给出已经过去的时间：顺延到下一个合理时段。
        if date < Date() {
            if hasClock {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            } else {
                let start = calendar.startOfDay(for: Date())
                let todayEvening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: start) ?? start
                date = todayEvening > Date() ? todayEvening : (calendar.date(byAdding: .day, value: 1, to: todayEvening) ?? date)
            }
        }
        return date
    }

    private static func stripCodeFence(_ content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let firstBreak = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstBreak)...])
            }
            if let range = text.range(of: "```") {
                text = String(text[..<range.lowerBound])
            }
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func systemPrompt(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let current = formatter.string(from: now)
        let weekday = Fmt.weekday(now)

        return """
        你是「生活提醒」App 的任务整理助手。用户会随手记录一句生活琐事或想法，你要把它拆成 1-3 条可执行任务。
        当前时间：\(current)（\(weekday)，时区 Asia/Shanghai）。
        只输出 JSON，不要解释，不要 Markdown，格式：
        {"tasks":[{"title":"不超过18个字","note":"补充说明，可为空","dueDate":"yyyy-MM-dd HH:mm","priority":"low|normal|high","leadMinutes":10,"tag":"生活"}]}
        规则：
        1. 相对时间（如“三点后”“明早”“今晚”“半小时后”）必须换算成绝对时间，并且必须晚于当前时间。
        2. 完全没提时间时，dueDate 用空字符串。
        3. 即使只是一句想法，也要提炼成一个温和的提醒任务，不要返回空数组。
        4. tag 只能从 生活/工作/健康/计划/学习/家务 中选择一个。
        5. note 可以补充细节或提醒语气，不要超过 30 字。
        """
    }
}
