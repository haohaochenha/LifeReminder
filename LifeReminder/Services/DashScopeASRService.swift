import Foundation

enum ASRError: LocalizedError {
    case missingKey
    case uploadFailed(String)
    case submitFailed(String)
    case failed(String)
    case timeout
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "请先在设置里填写阿里云百炼 API Key"
        case .uploadFailed(let message):
            return "音频上传失败：\(message)"
        case .submitFailed(let message):
            return "提交转写任务失败：\(message)"
        case .failed(let message):
            return "语音识别失败：\(message)"
        case .timeout:
            return "识别超时，网络较慢或音频较长，请重试"
        case .empty:
            return "没有听清，靠近麦克风再试一次"
        }
    }
}

/// 阿里云百炼 Qwen-Audio-ASR-Filetrans 异步文件转写。
/// 流程：上传音频到临时存储 → 提交异步任务 → 轮询 → 下载转写结果。
struct DashScopeASRService {
    static let defaultModel = "qwen-audio-3.1-asr-flash-filetrans"

    static func transcribe(fileURL: URL,
                           apiKey: String,
                           model: String,
                           workspaceId: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ASRError.missingKey }
        let useModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : model

        let ossURL = try await upload(fileURL: fileURL, apiKey: key, model: useModel)
        let taskId = try await submit(ossURL: ossURL,
                                      apiKey: key,
                                      model: useModel,
                                      workspaceId: workspaceId)
        let transcriptionURL = try await poll(taskId: taskId,
                                              apiKey: key,
                                              workspaceId: workspaceId)
        return try await downloadTranscript(urlString: transcriptionURL)
    }

    /// 只验证 Key 与模型是否可用（请求一次上传凭证，不真正上传）。
    static func test(apiKey: String, model: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ASRError.missingKey }
        let useModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : model
        _ = try await fetchPolicy(apiKey: key, model: useModel)
        return "连接正常"
    }

    // MARK: - Step 1: upload

    private struct PolicyResponse: Decodable {
        let data: Policy?
        let code: String?
        let message: String?
    }

    private struct Policy: Decodable {
        let upload_dir: String
        let upload_host: String
        let oss_access_key_id: String
        let signature: String
        let policy: String
        let x_oss_object_acl: String
        let x_oss_forbid_overwrite: String
    }

    private static func fetchPolicy(apiKey: String, model: String) async throws -> Policy {
        var components = URLComponents(string: "https://dashscope.aliyuncs.com/api/v1/uploads")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "getPolicy"),
            URLQueryItem(name: "model", value: model)
        ]
        guard let url = components?.url else {
            throw ASRError.uploadFailed("上传地址无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ASRError.uploadFailed("获取上传凭证失败（\(code)）\(apiMessage(data))")
        }
        guard let decoded = try? JSONDecoder().decode(PolicyResponse.self, from: data),
              let policy = decoded.data else {
            throw ASRError.uploadFailed(decodedMessage(data) ?? "上传凭证解析失败")
        }
        return policy
    }

    private static func upload(fileURL: URL, apiKey: String, model: String) async throws -> String {
        let policy = try await fetchPolicy(apiKey: apiKey, model: model)
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw ASRError.uploadFailed("读取录音失败")
        }
        guard !fileData.isEmpty else { throw ASRError.empty }

        let filename = fileURL.lastPathComponent
        let keyName = policy.upload_dir.hasSuffix("/")
            ? "\(policy.upload_dir)\(filename)"
            : "\(policy.upload_dir)/\(filename)"
        guard let host = URL(string: policy.upload_host) else {
            throw ASRError.uploadFailed("上传主机地址无效")
        }

        let boundary = "----LifeReminder\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()
        func append(_ text: String) {
            body.append(Data(text.utf8))
        }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        field("OSSAccessKeyId", policy.oss_access_key_id)
        field("Signature", policy.signature)
        field("policy", policy.policy)
        field("x-oss-object-acl", policy.x_oss_object_acl)
        field("x-oss-forbid-overwrite", policy.x_oss_forbid_overwrite)
        field("key", keyName)
        field("success_action_status", "200")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: host)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await send(request, body: body)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ASRError.uploadFailed("上传返回 \(code)\(apiMessage(data))")
        }
        return "oss://\(keyName)"
    }

    // MARK: - Step 2: submit

    private struct SubmitResponse: Decodable {
        struct Output: Decodable {
            let task_id: String?
            let task_status: String?
        }
        let output: Output?
        let code: String?
        let message: String?
    }

    private static func submit(ossURL: String,
                               apiKey: String,
                               model: String,
                               workspaceId: String) async throws -> String {
        let url = endpoint(workspaceId: workspaceId, path: "/api/v1/services/audio/asr/transcription")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-OssResourceResolve")

        let payload: [String: Any] = [
            "model": model,
            "input": ["file_urls": [ossURL]],
            "parameters": ["channel_id": [0]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ASRError.submitFailed("返回 \(code)\(apiMessage(data))")
        }
        guard let decoded = try? JSONDecoder().decode(SubmitResponse.self, from: data) else {
            throw ASRError.submitFailed(decodedMessage(data) ?? "任务返回无法解析")
        }
        if let taskId = decoded.output?.task_id, !taskId.isEmpty {
            return taskId
        }
        let message = decoded.message ?? decodedMessage(data) ?? "未返回 task_id"
        throw ASRError.submitFailed(message)
    }

    // MARK: - Step 3: poll

    private struct TaskResponse: Decodable {
        struct Result: Decodable {
            let subtask_status: String?
            let transcription_url: String?
            let code: String?
            let message: String?
        }
        struct Output: Decodable {
            let task_id: String?
            let task_status: String?
            let results: [Result]?
        }
        let output: Output?
        let code: String?
        let message: String?
    }

    private static func poll(taskId: String, apiKey: String, workspaceId: String) async throws -> String {
        let url = endpoint(workspaceId: workspaceId, path: "/api/v1/tasks/\(taskId)")

        for attempt in 0..<80 {
            try await Task.sleep(nanoseconds: 1_500_000_000)

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 30
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await send(request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw ASRError.failed("查询任务失败（\(code)）\(apiMessage(data))")
            }
            guard let decoded = try? JSONDecoder().decode(TaskResponse.self, from: data),
                  let output = decoded.output else {
                throw ASRError.failed(decodedMessage(data) ?? "任务状态无法解析")
            }

            let status = output.task_status ?? ""
            switch status {
            case "SUCCEEDED":
                if let urlString = output.results?.compactMap({ $0.transcription_url }).first {
                    return urlString
                }
                let detail = output.results?.compactMap({ $0.message }).first
                throw ASRError.failed(detail ?? "任务成功但没有转写结果")
            case "FAILED", "CANCELED", "UNKNOWN":
                let detail = output.results?.compactMap({ $0.message }).first
                throw ASRError.failed(detail ?? "任务状态 \(status)")
            default:
                if attempt == 79 {
                    throw ASRError.timeout
                }
                continue
            }
        }
        throw ASRError.timeout
    }

    // MARK: - Step 4: download transcript

    private struct TranscriptFile: Decodable {
        struct Transcript: Decodable {
            let text: String?
        }
        let transcripts: [Transcript]?
    }

    private static func downloadTranscript(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ASRError.failed("转写结果地址无效")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ASRError.failed("下载转写结果失败")
        }
        guard let file = try? JSONDecoder().decode(TranscriptFile.self, from: data),
              let transcripts = file.transcripts else {
            throw ASRError.failed("转写结果格式异常")
        }
        let text = transcripts.compactMap { $0.text }.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ASRError.empty }
        return text
    }

    // MARK: - Helpers

    private static func endpoint(workspaceId: String, path: String) -> URL {
        let workspace = workspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = workspace.isEmpty
            ? "dashscope.aliyuncs.com"
            : "\(workspace).cn-beijing.maas.aliyuncs.com"
        return URL(string: "https://\(host)\(path)")!
    }

    private static func send(_ request: URLRequest, body: Data? = nil) async throws -> (Data, URLResponse) {
        var finalRequest = request
        if let body = body {
            finalRequest.httpBody = body
        }
        do {
            return try await URLSession.shared.data(for: finalRequest)
        } catch {
            throw ASRError.failed("网络请求失败：\(error.localizedDescription)")
        }
    }

    private static func decodedMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = object["message"] as? String, !message.isEmpty {
            return message
        }
        if let output = object["output"] as? [String: Any],
           let message = output["message"] as? String, !message.isEmpty {
            return message
        }
        if let code = object["code"] as? String, !code.isEmpty {
            return code
        }
        return nil
    }

    private static func apiMessage(_ data: Data) -> String {
        guard let message = decodedMessage(data) else { return "" }
        return "，\(message)"
    }
}
