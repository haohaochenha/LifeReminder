import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var testing = false
    @State private var testMessage: String?
    @State private var testOK = false
    @State private var fetchingToken = false
    @State private var tokenMessage: String?
    @State private var tokenOK = false
    @State private var confirm: ConfirmAction?

    private enum ConfirmAction: String, Identifiable {
        case clearDone
        case resetAll

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                deepSeekCard
                aliyunCard
                notifyCard
                dataCard
                aboutCard
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .onAppear(perform: refreshStatus)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refreshStatus()
            }
        }
        .alert(item: $confirm) { action in
            switch action {
            case .clearDone:
                return Alert(title: Text("清空已完成？"),
                             message: Text("已完成的提醒会被删除。"),
                             primaryButton: .destructive(Text("清空")) {
                                 store.clearCompleted()
                                 Haptics.warning()
                             },
                             secondaryButton: .cancel(Text("取消")))
            case .resetAll:
                return Alert(title: Text("清空全部数据？"),
                             message: Text("所有提醒和想法都会被删除，无法恢复。"),
                             primaryButton: .destructive(Text("全部清空")) {
                                 store.resetEverything()
                                 Haptics.warning()
                             },
                             secondaryButton: .cancel(Text("取消")))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("设置")
                .font(Theme.rounded(30, .bold))
                .foregroundColor(Theme.ink)
            Text("Key 只保存在这台手机上，不会上传到别处")
                .font(Theme.rounded(13, .medium))
                .foregroundColor(Theme.subInk)
        }
    }

    // MARK: - DeepSeek

    private var deepSeekCard: some View {
        SettingsCard(title: "AI 分析", subtitle: "把一句话拆成结构化任务", icon: "sparkles") {
            LabeledField(title: "DeepSeek API Key",
                         placeholder: "sk-...",
                         text: $settings.deepseekKey,
                         icon: "key.fill",
                         secure: true)

            LabeledField(title: "模型",
                         placeholder: "deepseek-chat",
                         text: $settings.deepseekModel,
                         icon: "cpu")

            HStack(spacing: 10) {
                GhostButton(title: testing ? "正在连接…" : "测试连接", icon: "bolt.fill") {
                    testDeepSeek()
                }
                .disabled(testing)
            }

            if let message = testMessage {
                Text(message)
                    .font(Theme.rounded(12, .medium))
                    .foregroundColor(testOK ? Theme.teal : Theme.coral)
                    .lineLimit(3)
            }

            Text("在 platform.deepseek.com 创建 Key，填入后即可用 AI 解析想法。")
                .font(Theme.rounded(11, .regular))
                .foregroundColor(Theme.faint)
        }
    }

    // MARK: - Aliyun

    private var aliyunCard: some View {
        SettingsCard(title: "语音识别", subtitle: "阿里云智能语音交互 · 一句话识别", icon: "waveform") {
            LabeledField(title: "AppKey",
                         placeholder: "阿里云项目 AppKey",
                         text: $settings.aliyunAppKey,
                         icon: "app.badge.fill")

            LabeledField(title: "Token",
                         placeholder: "可直接粘贴临时 Token",
                         text: $settings.aliyunToken,
                         icon: "ticket.fill",
                         secure: true)

            Text("或填写 AccessKey，让 App 自动换取 Token（推荐）")
                .font(Theme.rounded(11, .semibold))
                .foregroundColor(Theme.subInk)

            LabeledField(title: "AccessKey ID",
                         placeholder: "LTAI...",
                         text: $settings.aliyunAccessKeyId,
                         icon: "person.badge.key.fill")

            LabeledField(title: "AccessKey Secret",
                         placeholder: "AccessKey Secret",
                         text: $settings.aliyunAccessKeySecret,
                         icon: "lock.fill",
                         secure: true)

            GhostButton(title: fetchingToken ? "正在获取…" : "获取 / 刷新 Token", icon: "arrow.triangle.2.circlepath") {
                fetchToken()
            }
            .disabled(fetchingToken)

            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tokenOK ? Theme.teal : Theme.faint)
                Text(tokenMessage ?? settings.tokenExpireText)
                    .font(Theme.rounded(11, .medium))
                    .foregroundColor(tokenOK ? Theme.teal : Theme.faint)
            }

            Text("录音为 16k 单声道 PCM，走 nls-gateway-cn-shanghai。")
                .font(Theme.rounded(11, .regular))
                .foregroundColor(Theme.faint)
        }
    }

    // MARK: - Notifications

    private var notifyCard: some View {
        SettingsCard(title: "提醒", subtitle: "到点用本地通知叫你", icon: "bell.badge.fill") {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.teal)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.teal.opacity(0.12)))

                Text("开启提醒")
                    .font(Theme.rounded(14, .medium))
                    .foregroundColor(Theme.ink)

                Spacer()

                Toggle("", isOn: $settings.notifyEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.teal))
                    .scaleEffect(0.85)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(notifyStatusText)
                    .font(Theme.rounded(12, .medium))
                    .foregroundColor(Theme.subInk)
                Spacer()
                if status == .denied {
                    Button(action: openSystemSettings) {
                        Text("去系统设置")
                            .font(Theme.rounded(12, .bold))
                            .foregroundColor(Theme.teal)
                    }
                }
            }

            HStack {
                Text("默认提前量")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.subInk)
                Spacer()
                Menu {
                    ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        Button(leadLabel(minutes)) {
                            settings.defaultLeadMinutes = minutes
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(leadLabel(settings.defaultLeadMinutes))
                            .font(Theme.rounded(13, .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Theme.deep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.7)))
                }
            }
        }
    }

    // MARK: - Data

    private var dataCard: some View {
        SettingsCard(title: "数据", subtitle: "全部保存在本机", icon: "internaldrive.fill") {
            HStack(spacing: 10) {
                miniStat(value: "\(store.tasks.count)", label: "提醒")
                miniStat(value: "\(store.ideas.count)", label: "想法")
                miniStat(value: "\(store.completedTasks.count)", label: "已完成")
            }

            GhostButton(title: "清空已完成", icon: "checkmark.circle") {
                confirm = .clearDone
            }

            Button(action: {
                Haptics.warning()
                confirm = .resetAll
            }) {
                Text("清空全部数据")
                    .font(Theme.rounded(14, .semibold))
                    .foregroundColor(Theme.coral)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(Theme.coral.opacity(0.10)))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var aboutCard: some View {
        SettingsCard(title: "关于", subtitle: "生活提醒 \(version)", icon: "info.circle.fill") {
            Text("一个只给自己用的小提醒 App：随口记下想法，AI 拆成带时间的任务，到点弹通知。没有账号，没有云同步。")
                .font(Theme.rounded(12, .regular))
                .foregroundColor(Theme.subInk)
                .lineSpacing(4)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.teal)
                Text("DeepSeek Key 与阿里云 Key 仅存于 UserDefaults")
                    .font(Theme.rounded(11, .medium))
                    .foregroundColor(Theme.faint)
            }
        }
    }

    // MARK: - Helpers

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.rounded(19, .bold))
                .foregroundColor(Theme.deep)
            Text(label)
                .font(Theme.rounded(11, .medium))
                .foregroundColor(Theme.subInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.55)))
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var statusColor: Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return Theme.teal
        case .denied: return Theme.coral
        default: return Theme.faint
        }
    }

    private var notifyStatusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "通知权限已开启"
        case .denied: return "通知权限被关闭，提醒不会弹出"
        case .notDetermined: return "尚未请求通知权限"
        @unknown default: return "通知状态未知"
        }
    }

    private func leadLabel(_ minutes: Int) -> String {
        minutes <= 0 ? "准时提醒" : "提前 \(minutes) 分钟"
    }

    private func refreshStatus() {
        NotificationManager.shared.status { value in
            status = value
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func testDeepSeek() {
        guard !testing else { return }
        guard settings.hasDeepSeek else {
            testMessage = "请先填写 DeepSeek API Key"
            testOK = false
            return
        }
        testing = true
        testMessage = nil
        let key = settings.trimmedDeepSeekKey
        let model = settings.resolvedModel

        Task {
            do {
                let reply = try await DeepSeekService.test(apiKey: key, model: model)
                await MainActor.run {
                    testing = false
                    testOK = true
                    testMessage = "连接正常，模型回复：\(reply)"
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    testing = false
                    testOK = false
                    testMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    Haptics.warning()
                }
            }
        }
    }

    private func fetchToken() {
        guard !fetchingToken else { return }
        guard settings.hasAliyunAuto else {
            tokenMessage = "请先填写 AppKey、AccessKey ID 和 Secret"
            tokenOK = false
            return
        }
        fetchingToken = true
        tokenMessage = nil
        let akId = settings.aliyunAccessKeyId
        let akSecret = settings.aliyunAccessKeySecret

        Task {
            do {
                let result = try await AliyunASRService.createToken(accessKeyId: akId, accessKeySecret: akSecret)
                await MainActor.run {
                    settings.aliyunToken = result.token
                    settings.aliyunTokenExpire = result.expire.timeIntervalSince1970
                    fetchingToken = false
                    tokenOK = true
                    tokenMessage = "Token 已更新，\(settings.tokenExpireText)"
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    fetchingToken = false
                    tokenOK = false
                    tokenMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    Haptics.warning()
                }
            }
        }
    }
}

// MARK: - Settings Card

private struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String = "circle"
    let content: Content

    init(title: String,
         subtitle: String? = nil,
         icon: String = "circle",
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.teal.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.teal)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.rounded(16, .bold))
                        .foregroundColor(Theme.ink)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Theme.rounded(11, .medium))
                            .foregroundColor(Theme.faint)
                    }
                }
                Spacer(minLength: 0)
            }

            content
        }
        .padding(18)
        .glass(radius: 24, tint: 0.4)
    }
}
