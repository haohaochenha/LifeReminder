import Foundation
import Combine

final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var deepseekKey: String = "" {
        didSet { defaults.set(deepseekKey, forKey: Keys.deepseekKey) }
    }

    @Published var deepseekModel: String = "deepseek-chat" {
        didSet { defaults.set(deepseekModel, forKey: Keys.deepseekModel) }
    }

    @Published var aliyunAppKey: String = "" {
        didSet { defaults.set(aliyunAppKey, forKey: Keys.aliyunAppKey) }
    }

    @Published var aliyunToken: String = "" {
        didSet { defaults.set(aliyunToken, forKey: Keys.aliyunToken) }
    }

    @Published var aliyunAccessKeyId: String = "" {
        didSet { defaults.set(aliyunAccessKeyId, forKey: Keys.aliyunAccessKeyId) }
    }

    @Published var aliyunAccessKeySecret: String = "" {
        didSet { defaults.set(aliyunAccessKeySecret, forKey: Keys.aliyunAccessKeySecret) }
    }

    @Published var aliyunTokenExpire: Double = 0 {
        didSet { defaults.set(aliyunTokenExpire, forKey: Keys.aliyunTokenExpire) }
    }

    @Published var notifyEnabled: Bool = true {
        didSet { defaults.set(notifyEnabled, forKey: Keys.notifyEnabled) }
    }

    @Published var defaultLeadMinutes: Int = 10 {
        didSet { defaults.set(defaultLeadMinutes, forKey: Keys.defaultLead) }
    }

    private enum Keys {
        static let deepseekKey = "life.deepseek.key"
        static let deepseekModel = "life.deepseek.model"
        static let aliyunAppKey = "life.aliyun.appkey"
        static let aliyunToken = "life.aliyun.token"
        static let aliyunAccessKeyId = "life.aliyun.akid"
        static let aliyunAccessKeySecret = "life.aliyun.aksecret"
        static let aliyunTokenExpire = "life.aliyun.expire"
        static let notifyEnabled = "life.notify.enabled"
        static let defaultLead = "life.notify.lead"
    }

    init() {
        deepseekKey = defaults.string(forKey: Keys.deepseekKey) ?? ""
        deepseekModel = defaults.string(forKey: Keys.deepseekModel) ?? "deepseek-chat"
        aliyunAppKey = defaults.string(forKey: Keys.aliyunAppKey) ?? ""
        aliyunToken = defaults.string(forKey: Keys.aliyunToken) ?? ""
        aliyunAccessKeyId = defaults.string(forKey: Keys.aliyunAccessKeyId) ?? ""
        aliyunAccessKeySecret = defaults.string(forKey: Keys.aliyunAccessKeySecret) ?? ""
        aliyunTokenExpire = defaults.double(forKey: Keys.aliyunTokenExpire)
        if defaults.object(forKey: Keys.notifyEnabled) == nil {
            notifyEnabled = true
        } else {
            notifyEnabled = defaults.bool(forKey: Keys.notifyEnabled)
        }
        let lead = defaults.integer(forKey: Keys.defaultLead)
        defaultLeadMinutes = lead > 0 ? lead : 10
    }

    var trimmedDeepSeekKey: String {
        deepseekKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasDeepSeek: Bool { !trimmedDeepSeekKey.isEmpty }

    var trimmedAppKey: String {
        aliyunAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedToken: String {
        aliyunToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAliyunToken: Bool {
        !trimmedAppKey.isEmpty && !trimmedToken.isEmpty
    }

    var hasAliyunAuto: Bool {
        !trimmedAppKey.isEmpty &&
        !aliyunAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !aliyunAccessKeySecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAliyun: Bool { hasAliyunToken || hasAliyunAuto }

    var tokenExpireText: String {
        guard aliyunTokenExpire > 0 else { return "尚未获取" }
        let date = Date(timeIntervalSince1970: aliyunTokenExpire)
        if date < Date() { return "已过期，请重新获取" }
        return "有效期至 \(Fmt.full(date))"
    }

    var resolvedModel: String {
        let value = deepseekModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "deepseek-chat" : value
    }
}
