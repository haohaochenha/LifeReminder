import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var recorder = AudioRecorder()

    @State private var text = ""
    @State private var drafts: [AIDraft] = []
    @State private var isTranscribing = false
    @State private var isParsing = false
    @State private var lastSource: IdeaSource = .text
    @State private var sessionIdeaId: UUID?
    @State private var alertMessage = ""
    @State private var showAlert = false

    let openSettings: () -> Void
    let toast: (String, Bool) -> Void

    init(openSettings: @escaping () -> Void,
         toast: @escaping (String, Bool) -> Void) {
        self.openSettings = openSettings
        self.toast = toast
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                composer
                actionRow

                if !settings.hasDeepSeek {
                    keyHint
                }

                if !drafts.isEmpty {
                    draftSection
                }

                recentIdeas
            }
            .background(ScrollTracker())
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 120)
        }
        .coordinateSpace(name: ScrollChrome.spaceName)
        .onAppear {
            recorder.requestPermission { _ in }
        }
        .onDisappear {
            recorder.cancel()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("出了点小问题"),
                  message: Text(alertMessage),
                  dismissButton: .default(Text("好")))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("记录想法")
                .font(Theme.font(34, .bold))
                .foregroundColor(Theme.label)
                .tracking(-0.5)
            Text("说一句或写一句，AI 帮你变成带时间的提醒")
                .font(Theme.font(15))
                .foregroundColor(Theme.label2)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.orange)
                    Text("现在想到的是")
                        .font(Theme.font(13, .semibold))
                        .foregroundColor(Theme.label2)
                }
                Spacer()
                Text("\(trimmedText.count) 字")
                    .font(Theme.font(12))
                    .foregroundColor(Theme.label3)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("比如：明天下午三点提醒我去交体检报告，顺便买点水果")
                        .font(Theme.font(16))
                        .foregroundColor(Theme.label3)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Theme.font(16))
                    .foregroundColor(Theme.label)
                    .accentColor(Theme.blue)
                    .frame(minHeight: 112, maxHeight: 160)
                    .padding(.horizontal, -4)
            }

            WaveformView(isRecording: recorder.isRecording)
                .frame(height: 44)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recordTitle)
                        .font(Theme.font(13, .semibold))
                        .foregroundColor(recorder.isRecording ? Theme.red : Theme.label2)
                    Text(recordSubtitle)
                        .font(Theme.font(12))
                        .foregroundColor(Theme.label3)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                recordButton
            }
        }
        .padding(18)
        .glassCard(radius: 26)
    }

    private var recordTitle: String {
        if recorder.isRecording { return "正在录音 · \(Fmt.clock(recorder.duration))" }
        if isTranscribing { return "正在上传并转写…" }
        return "按住说话"
    }

    private var recordSubtitle: String {
        if recorder.isRecording { return "松开结束，自动转成文字" }
        if isTranscribing { return "音频会被上传到阿里云百炼完成转写" }
        if !settings.hasDashScope { return "先在设置里填写百炼 API Key" }
        return "松开结束，自动转成文字"
    }

    private var recordButton: some View {
        ZStack {
            if recorder.isRecording {
                Circle()
                    .stroke(Theme.red.opacity(0.22), lineWidth: 6)
                    .frame(width: 96, height: 96)
            }
            Circle()
                .fill(Theme.fill)
                .frame(width: 76, height: 76)
            Circle()
                .strokeBorder(Theme.fill2, lineWidth: 2)
                .frame(width: 76, height: 76)

            if isTranscribing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.red))
            } else {
                RoundedRectangle(cornerRadius: recorder.isRecording ? 7 : 12, style: .continuous)
                    .fill(Theme.red)
                    .frame(width: recorder.isRecording ? 24 : 26,
                           height: recorder.isRecording ? 24 : 26)
            }
        }
        .frame(width: 96, height: 96)
        .scaleEffect(recorder.isRecording ? 1.04 : 1)
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
        .contentShape(Circle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginRecording() }
                .onEnded { _ in endRecording() }
        )
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            SecondaryButton(title: "存为想法", icon: "bookmark") {
                saveAsIdea()
            }
            PrimaryButton(title: "AI 生成任务",
                          icon: "sparkles",
                          isLoading: isParsing,
                          enabled: !trimmedText.isEmpty) {
                parseText()
            }
        }
    }

    private var keyHint: some View {
        Button(action: {
            Haptics.tap()
            openSettings()
        }) {
            HStack(spacing: 10) {
                IconTile(color: Theme.orange, icon: "key.fill")
                Text("还没填 DeepSeek Key，AI 解析暂时不可用")
                    .font(Theme.font(13))
                    .foregroundColor(Theme.label2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Text("去填写")
                    .font(Theme.font(13, .semibold))
                    .foregroundColor(Theme.blue)
            }
            .padding(14)
            .glassCard(radius: 18)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Drafts

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionTitle(title: "AI 解析结果", trailing: "\(drafts.count) 个")

            GroupCard {
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            IconTile(color: draft.priority.color, icon: "sparkles")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.title)
                                    .font(Theme.font(16, .medium))
                                    .foregroundColor(Theme.label)
                                    .lineLimit(2)
                                Text(draftMeta(draft))
                                    .font(Theme.font(13))
                                    .foregroundColor(Theme.label2)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            MiniPillButton(title: "加入") {
                                addDraft(draft)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < drafts.count - 1 {
                            CellDivider(inset: 58)
                        }
                    }
                }
            }
        }
    }

    private func draftMeta(_ draft: AIDraft) -> String {
        let time = draft.dueDate.map { Fmt.due($0) } ?? "不定时"
        return "\(time) · \(draft.priority.label)"
    }

    // MARK: - Recent ideas

    private var recentIdeas: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionTitle(title: "最近的想法",
                         trailing: store.ideas.isEmpty ? nil : "\(store.ideas.count) 条")

            if store.ideas.isEmpty {
                GroupCard {
                    EmptyStateView(icon: "text.alignleft", message: "记录过的话会出现在这里")
                }
            } else {
                GroupCard {
                    ForEach(Array(store.latestIdeas.prefix(6).enumerated()), id: \.element.id) { index, idea in
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 12) {
                                IconTile(color: idea.source == .voice ? Theme.indigo : Theme.blue,
                                         icon: idea.source == .voice ? "waveform" : "text.alignleft",
                                         size: 30, circle: true)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(idea.text)
                                        .font(Theme.font(15))
                                        .foregroundColor(Theme.label)
                                        .lineLimit(2)
                                    HStack(spacing: 8) {
                                        Text(Fmt.full(idea.createdAt))
                                            .font(Theme.font(12))
                                            .foregroundColor(Theme.label3)
                                        if idea.converted > 0 {
                                            Text("已生成 \(idea.converted) 个提醒")
                                                .font(Theme.font(12, .medium))
                                                .foregroundColor(Theme.blue)
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.soft()
                                text = idea.text
                                lastSource = idea.source
                                toast("已填入输入框", true)
                            }

                            if index < min(5, store.ideas.count - 1) {
                                CellDivider(inset: 58)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recording

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginRecording() {
        guard !recorder.isRecording, !isTranscribing else { return }
        guard settings.hasDashScope else {
            presentError(ASRError.missingKey)
            return
        }
        if recorder.start() {
            Haptics.soft()
        } else if let message = recorder.errorMessage {
            showMessage(message)
        }
    }

    private func endRecording() {
        guard recorder.isRecording else { return }
        let duration = recorder.duration
        let url = recorder.stop()
        guard let file = url else { return }
        guard duration >= 0.6 else {
            recorder.consumeFile(file)
            showMessage("说话时间太短了，按住多说一会儿")
            return
        }
        transcribe(file)
    }

    private func transcribe(_ url: URL) {
        isTranscribing = true
        let apiKey = settings.trimmedDashScopeKey
        let model = settings.resolvedASRModel
        let workspace = settings.resolvedWorkspace

        Task {
            do {
                let result = try await DashScopeASRService.transcribe(fileURL: url,
                                                                      apiKey: apiKey,
                                                                      model: model,
                                                                      workspaceId: workspace)
                await MainActor.run {
                    if self.text.isEmpty {
                        self.text = result
                    } else {
                        self.text += " " + result
                    }
                    self.lastSource = .voice
                    self.isTranscribing = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.isTranscribing = false
                    self.presentError(error)
                }
            }
            recorder.consumeFile(url)
        }
    }

    // MARK: - AI

    private func parseText() {
        let content = trimmedText
        guard !content.isEmpty else { return }
        guard settings.hasDeepSeek else {
            presentError(AIServiceError.missingKey)
            return
        }
        isParsing = true
        let key = settings.trimmedDeepSeekKey
        let model = settings.resolvedModel

        Task {
            do {
                let result = try await DeepSeekService.parse(text: content, apiKey: key, model: model)
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        self.drafts = result
                    }
                    self.sessionIdeaId = nil
                    self.isParsing = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.isParsing = false
                    self.presentError(error)
                }
            }
        }
    }

    private func addDraft(_ draft: AIDraft) {
        let task = draft.makeTask(defaultLead: settings.defaultLeadMinutes)
        store.add(task)

        if sessionIdeaId == nil {
            let idea = IdeaNote(text: trimmedText.isEmpty ? "AI 生成的提醒" : trimmedText,
                                source: lastSource,
                                converted: 1)
            store.addIdea(idea)
            sessionIdeaId = idea.id
        } else if let id = sessionIdeaId {
            store.markIdeaConverted(id, count: 1)
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            drafts.removeAll { $0.id == draft.id }
        }
        Haptics.success()
        toast("已加入提醒", true)
    }

    private func saveAsIdea() {
        guard !trimmedText.isEmpty else { return }
        store.addIdea(IdeaNote(text: trimmedText, source: lastSource, converted: 0))
        withAnimation {
            text = ""
            lastSource = .text
            sessionIdeaId = nil
        }
        Haptics.success()
        toast("已存为想法", true)
    }

    // MARK: - Feedback

    private func presentError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showMessage(message)
        Haptics.warning()
    }

    private func showMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
