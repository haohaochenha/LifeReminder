import Foundation
import Combine
import SwiftUI

final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var deepseekKey: String = "" {
        didSet { defaults.set(deepseekKey, forKey: Keys.deepseekKey) }
    }

    @Published var deepseekModel: String = "deepseek-flash" {
        didSet { defaults.set(deepseekModel, forKey: Keys.deepseekModel) }
    }

    @Published var dashscopeKey: String = "" {
        didSet { defaults.set(dashscopeKey, forKey: Keys.dashscopeKey) }
    }

    @Published var asrModel: String = "qwen-audio-3.1-asr-flash-filetrans" {
        didSet { defaults.set(asrModel, forKey: Keys.asrModel) }
    }

    @Published var workspaceId: String = "" {
        didSet { defaults.set(workspaceId, forKey: Keys.workspaceId) }
    }

    @Published var notifyEnabled: Bool = true {
        didSet { defaults.set(notifyEnabled, forKey: Keys.notifyEnabled) }
    }

    @Published var hapticEnabled: Bool = true {
        didSet { defaults.set(hapticEnabled, forKey: Keys.hapticEnabled) }
    }

    @Published var defaultLeadMinutes: Int = 10 {
        didSet { defaults.set(defaultLeadMinutes, forKey: Keys.defaultLead) }
    }

    @Published var appearance: String = "system" {
        didSet { defaults.set(appearance, forKey: Keys.appearance) }
    }

    private enum Keys {
        static let deepseekKey = "life.deepseek.key"
        static let deepseekModel = "life.deepseek.model"
        static let dashscopeKey = "life.dashscope.key"
        static let asrModel = "life.dashscope.asr"
        static let workspaceId = "life.dashscope.workspace"
        static let notifyEnabled = "life.notify.enabled"
        static let hapticEnabled = "life.haptic"
        static let defaultLead = "life.notify.lead"
        static let appearance = "life.appearance"
    }

    init() {
        deepseekKey = defaults.string(forKey: Keys.deepseekKey) ?? ""
        let model = defaults.string(forKey: Keys.deepseekModel) ?? ""
        deepseekModel = model.isEmpty ? "deepseek-flash" : model
        dashscopeKey = defaults.string(forKey: Keys.dashscopeKey) ?? ""
        let asr = defaults.string(forKey: Keys.asrModel) ?? ""
        asrModel = asr.isEmpty ? "qwen-audio-3.1-asr-flash-filetrans" : asr
        workspaceId = defaults.string(forKey: Keys.workspaceId) ?? ""

        if defaults.object(forKey: Keys.notifyEnabled) == nil {
            notifyEnabled = true
        } else {
            notifyEnabled = defaults.bool(forKey: Keys.notifyEnabled)
        }
        if defaults.object(forKey: Keys.hapticEnabled) == nil {
            hapticEnabled = true
        } else {
            hapticEnabled = defaults.bool(forKey: Keys.hapticEnabled)
        }

        let lead = defaults.integer(forKey: Keys.defaultLead)
        defaultLeadMinutes = lead > 0 ? lead : 10
        appearance = defaults.string(forKey: Keys.appearance) ?? "system"
    }

    var trimmedDeepSeekKey: String {
        deepseekKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDashScopeKey: String {
        dashscopeKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasDeepSeek: Bool { !trimmedDeepSeekKey.isEmpty }

    var hasDashScope: Bool { !trimmedDashScopeKey.isEmpty }

    var resolvedModel: String {
        let value = deepseekModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "deepseek-flash" : value
    }

    var resolvedASRModel: String {
        let value = asrModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "qwen-audio-3.1-asr-flash-filetrans" : value
    }

    var resolvedWorkspace: String {
        workspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isDark: Bool {
        get { appearance == "dark" }
        set { appearance = newValue ? "dark" : "light" }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}
