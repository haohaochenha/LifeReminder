import Foundation
import CryptoKit

enum ASRError: LocalizedError {
    case missingConfig
    case network(String)
    case failed(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "请先在「设置」中填写阿里云 AppKey 和 Token"
        case .network(let message):
            return "网络请求失败：\(message)"
        case .failed(let message):
            return "语音识别失败：\(message)"
        case .empty:
            return "没有听清，靠近麦克风再试一次"
        }
    }
}

struct AliyunASRService {
    private static let gateway = "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr"
    private static let tokenEndpoint = "https://nls-meta.cn-shanghai.aliyuncs.com/"

    // MARK: - One sentence recognition

    static func recognize(pcm: Data, appKey: String, token: String) async throws -> String {
        let key = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !accessToken.isEmpty else { throw ASRError.missingConfig }
        guard pcm.count > 3200 else { throw ASRError.empty }

        var components = URLComponents(string: gateway)
        components?.queryItems = [
            URLQueryItem(name: "appkey", value: key),
            URLQueryItem(name: "format", value: "pcm"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "enable_punctuation_prediction", value: "true"),
            URLQueryItem(name: "enable_inverse_text_normalization", value: "true")
        ]
        guard let url = components?.url else { throw ASRError.missingConfig }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(accessToken, forHTTPHeaderField: "X-NLS-Token")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = pcm

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            throw ASRError.network(error.localizedDescription)
        }

        guard let http = result.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (result.1 as? HTTPURLResponse)?.statusCode ?? -1
            throw ASRError.failed("服务返回 \(code)")
        }

        guard let decoded = try? JSONDecoder().decode(ASRResponse.self, from: result.0) else {
            throw ASRError.failed("返回内容无法解析")
        }

        if decoded.status == 20000000 {
            let text = decoded.result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { throw ASRError.empty }
            return text
        }

        let message = decoded.message ?? "未知错误"
        if message.lowercased().contains("token") {
            throw ASRError.failed("Token 无效或已过期，请在设置中更新")
        }
        throw ASRError.failed(message)
    }

    private struct ASRResponse: Decodable {
        let status: Int?
        let message: String?
        let result: String?
    }

    // MARK: - Create token with AccessKey

    struct TokenResult {
        let token: String
        let expire: Date
    }

    static func createToken(accessKeyId: String, accessKeySecret: String) async throws -> TokenResult {
        let akId = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let akSecret = accessKeySecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !akId.isEmpty, !akSecret.isEmpty else {
            throw ASRError.missingConfig
        }

        var params: [String: String] = [
            "AccessKeyId": akId,
            "Action": "CreateToken",
            "Format": "JSON",
            "RegionId": "cn-shanghai",
            "SignatureMethod": "HMAC-SHA1",
            "SignatureNonce": UUID().uuidString,
            "SignatureVersion": "1.0",
            "Timestamp": utcTimestamp(),
            "Version": "2019-02-28"
        ]

        let canonical = params.keys.sorted()
            .map { "\(percentEncode($0))=\(percentEncode(params[$0] ?? ""))" }
            .joined(separator: "&")

        let stringToSign = "GET&%2F&" + percentEncode(canonical)
        let signingKey = SymmetricKey(data: Data((akSecret + "&").utf8))
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: Data(stringToSign.utf8), using: signingKey)
        let signatureBase64 = Data(signature).base64EncodedString()

        params["Signature"] = signatureBase64
        let query = params.keys.sorted()
            .map { "\(percentEncode($0))=\(percentEncode(params[$0] ?? ""))" }
            .joined(separator: "&")

        guard let url = URL(string: tokenEndpoint + "?" + query) else {
            throw ASRError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            throw ASRError.network(error.localizedDescription)
        }

        guard let http = result.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (result.1 as? HTTPURLResponse)?.statusCode ?? -1
            throw ASRError.failed("获取 Token 失败（\(code)），请检查 AccessKey 权限")
        }

        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: result.0) else {
            throw ASRError.failed("Token 返回内容无法解析")
        }
        guard let token = decoded.Token?.Id, !token.isEmpty else {
            throw ASRError.failed("未获取到有效 Token，请检查 AccessKey")
        }

        let expire = Date(timeIntervalSince1970: TimeInterval(decoded.Token?.ExpireTime ?? 0))
        return TokenResult(token: token, expire: expire)
    }

    private struct TokenResponse: Decodable {
        struct TokenPayload: Decodable {
            let Id: String?
            let ExpireTime: Int64?
        }
        let Token: TokenPayload?
    }

    // MARK: - Audio helpers

    /// AVAudioRecorder 写出的是 WAV，阿里云一句话识别要纯 PCM，需要去掉 RIFF 头。
    static func rawPCM(fromWav data: Data) -> Data {
        guard data.count > 64 else { return data }
        guard let range = data.range(of: Data("data".utf8)) else {
            return data.count > 44 ? data.subdata(in: 44..<data.count) : data
        }
        let offset = data.distance(from: data.startIndex, to: range.upperBound) + 4
        guard offset < data.count else { return data }
        return data.subdata(in: offset..<data.count)
    }

    private static func utcTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter.string(from: Date())
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
