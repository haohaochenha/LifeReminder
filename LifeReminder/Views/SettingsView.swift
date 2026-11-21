import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var revealDeepSeek = false
    @State private var revealDashScope = false

    @State private var deepseekTesting = false
    @State private var deepseekResult: String?
    @State private var deepseekOK = false

    @State private var asrTesting = false
    @State private var asrResult: String?
    @State private var asrOK = false

    @State private var confirm: ConfirmAction?

    let toast: (String, Bool) -> Void

    init(toast: @escaping (String, Bool) -> Void) {
        self.toast = toast
    }

    private enum ConfirmAction: String, Identifiable {
        case clearDone
        case resetAll

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header

                groupLabel("AI 分析")
                aiGroup
                GFCaption(text: "DeepSeek V4.1 Flash（模型名 deepseek-flash），把一句想法拆成可执行的提醒。")

                groupLabel("语音识别 · 阿里云百炼")
                asrGroup
                GFCaption(text: "录音会先上传到百炼临时存储，再用 qwen-audio-3.1-asr-flash-filetrans 异步转写，最长支持长音频。")

                groupLabel("通用")
                generalGroup

                groupLabel("数据")
                dataGroup

                Text("生活提醒 \(version) · 数据与 Key 都只保存在本机")
                    .font(Theme.font(12))
                    .foregroundColor(Theme.label3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .background(ScrollTracker())
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 120)
        }
        .coordinateSpace(name: ScrollChrome.spaceName)
        .onAppear(perform: refreshStatus)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshStatus() }
        }
        .alert(item: $confirm) { action in
            switch action {
            case .clearDone:
                return Alert(title: Text("清空已完成？"),
                             message: Text("已完成的提醒会被删除。"),
                             primaryButton: .destructive(Text("清空")) {
                                 store.clearCompleted()
                                 toast("已清空已完成", true)
                             },
                             secondaryButton: .cancel(Text("取消")))
            case .resetAll:
                return Alert(title: Text("清空全部数据？"),
                             message: Text("所有提醒、想法和纪念日都会被删除，无法恢复。"),
                             primaryButton: .destructive(Text("全部清空")) {
                                 store.resetEverything()
                                 toast("已清空全部数据", true)
                             },
                             secondaryButton: .cancel(Text("取消")))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("设置")
                .font(Theme.font(34, .bold))
                .foregroundColor(Theme.label)
                .tracking(-0.5)
            Text("Key 只保存在这台手机上，不会上传到别处")
                .font(Theme.font(15))
                .foregroundColor(Theme.label2)
        }
        .padding(.bottom, 2)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(13, .semibold))
            .foregroundColor(Theme.label2)
            .padding(.leading, 6)
            .padding(.bottom, -6)
    }

    // MARK: - AI

    private var aiGroup: some View {
        GroupCard {
            FormCell(icon: "key.fill", iconColor: Theme.indigo) {
                secretField(placeholder: "DeepSeek API Key",
                            text: $settings.deepseekKey,
                            reveal: $revealDeepSeek)
            }

            CellDivider(inset: 58)

            FormCell(icon: "cpu", iconColor: Theme.blue, title: "模型") {
                TextField("deepseek-flash", text: $settings.deepseekModel)
                    .font(Theme.font(17))
                    .foregroundColor(Theme.label)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            CellDivider(inset: 58)

            Button(action: testDeepSeek) {
                FormCell(icon: deepseekOK ? "checkmark" : "bolt.fill",
                         iconColor: deepseekOK ? Theme.green : Theme.orange,
                         title: "连接测试") {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        if deepseekTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.label2))
                                .scaleEffect(0.8)
                        } else {
                            Text(deepseekResult ?? "点一下试试")
                                .font(Theme.font(13))
                                .foregroundColor(deepseekOK ? Theme.green : Theme.label2)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.label3)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - ASR

    private var asrGroup: some View {
        GroupCard {
            FormCell(icon: "waveform", iconColor: Theme.blue) {
                secretField(placeholder: "阿里云百炼 API Key",
                            text: $settings.dashscopeKey,
                            reveal: $revealDashScope)
            }

            CellDivider(inset: 58)

            FormCell(icon: "waveform.badge.mic", iconColor: Theme.indigo, title: "模型") {
                TextField("qwen-audio-3.1-asr-flash-filetrans", text: $settings.asrModel)
                    .font(Theme.font(14))
                    .foregroundColor(Theme.label)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .minimumScaleFactor(0.7)
            }

            CellDivider(inset: 58)

            FormCell(icon: "square.grid.2x2", iconColor: Theme.gray, title: "空间 ID") {
                TextField("可选", text: $settings.workspaceId)
                    .font(Theme.font(17))
                    .foregroundColor(Theme.label)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            CellDivider(inset: 58)

            Button(action: testASR) {
                FormCell(icon: asrOK ? "checkmark" : "bolt.fill",
                         iconColor: asrOK ? Theme.green : Theme.orange,
                         title: "连接测试") {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        if asrTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.label2))
                                .scaleEffect(0.8)
                        } else {
                            Text(asrResult ?? "检查 Key 与模型")
                                .font(Theme.font(13))
                                .foregroundColor(asrOK ? Theme.green : Theme.label2)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.label3)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - General

    private var generalGroup: some View {
        GroupCard {
            FormCell(icon: "moon.fill", iconColor: Theme.indigo, title: "深色模式") {
                Spacer()
                Toggle("", isOn: Binding(get: { settings.isDark },
                                         set: { settings.isDark = $0 }))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.blue))
            }

            CellDivider(inset: 58)

            FormCell(icon: "hand.tap.fill", iconColor: Theme.pink, title: "触感反馈") {
                Spacer()
                Toggle("", isOn: $settings.hapticEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.blue))
            }

            CellDivider(inset: 58)

            FormCell(icon: "bell.fill", iconColor: Theme.red, title: "到点提醒") {
                Spacer()
                Toggle("", isOn: $settings.notifyEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.blue))
            }

            CellDivider(inset: 58)

            FormCell(icon: "clock.fill", iconColor: Theme.blue, title: "提前量") {
                Spacer()
                Menu {
                    ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        Button(leadLabel(minutes)) {
                            settings.defaultLeadMinutes = minutes
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(leadLabel(settings.defaultLeadMinutes))
                            .font(Theme.font(15))
                            .foregroundColor(Theme.label2)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.label3)
                    }
                }
            }

            if status == .denied {
                CellDivider(inset: 58)
                Button(action: openSystemSettings) {
                    FormCell(icon: "exclamationmark.triangle.fill", iconColor: Theme.orange, title: "通知权限") {
                        Spacer()
                        Text("去系统设置")
                            .font(Theme.font(15, .medium))
                            .foregroundColor(Theme.blue)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.label3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data

    private var dataGroup: some View {
        GroupCard {
            FormCell(icon: "checkmark.circle", iconColor: Theme.green, title: "已完成") {
                Spacer()
                Text("\(store.completedTasks.count) 件")
                    .font(Theme.font(15))
                    .foregroundColor(Theme.label2)
            }

            CellDivider(inset: 58)

            Button(action: {
                Haptics.tap()
                confirm = .clearDone
            }) {
                FormCell(icon: "trash", iconColor: Theme.gray, title: "清空已完成") {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.label3)
                }
            }
            .buttonStyle(.plain)

            CellDivider(inset: 58)

            Button(action: {
                Haptics.warning()
                confirm = .resetAll
            }) {
                HStack(spacing: 12) {
                    Text("清空全部数据")
                        .font(Theme.font(17))
                        .foregroundColor(Theme.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Field

    private func secretField(placeholder: String,
                             text: Binding<String>,
                             reveal: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Group {
                if reveal.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(Theme.font(16))
            .foregroundColor(Theme.label)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

            Button(action: { reveal.wrappedValue.toggle() }) {
                Image(systemName: reveal.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.label3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func leadLabel(_ minutes: Int) -> String {
        minutes <= 0 ? "准时" : "\(minutes) 分钟"
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
        guard !deepseekTesting else { return }
        guard settings.hasDeepSeek else {
            deepseekOK = false
            deepseekResult = "请先填写 Key"
            return
        }
        deepseekTesting = true
        deepseekResult = nil
        let key = settings.trimmedDeepSeekKey
        let model = settings.resolvedModel

        Task {
            do {
                let reply = try await DeepSeekService.test(apiKey: key, model: model)
                await MainActor.run {
                    deepseekTesting = false
                    deepseekOK = true
                    deepseekResult = "正常：\(reply)"
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    deepseekTesting = false
                    deepseekOK = false
                    deepseekResult = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    Haptics.warning()
                }
            }
        }
    }

    private func testASR() {
        guard !asrTesting else { return }
        guard settings.hasDashScope else {
            asrOK = false
            asrResult = "请先填写 Key"
            return
        }
        asrTesting = true
        asrResult = nil
        let key = settings.trimmedDashScopeKey
        let model = settings.resolvedASRModel

        Task {
            do {
                let reply = try await DashScopeASRService.test(apiKey: key, model: model)
                await MainActor.run {
                    asrTesting = false
                    asrOK = true
                    asrResult = reply
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    asrTesting = false
                    asrOK = false
                    asrResult = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    Haptics.warning()
                }
            }
        }
    }
}
