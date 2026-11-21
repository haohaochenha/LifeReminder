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
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var toast: String?

    let openSettings: () -> Void

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
                    draftsSection
                }
                historySection
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .overlay(alignment: .top) {
            if let toast = toast {
                Text(toast)
                    .font(Theme.rounded(13, .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.deep.opacity(0.92)))
                    .shadow(color: Theme.deep.opacity(0.25), radius: 12, y: 6)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("记录想法")
                .font(Theme.rounded(30, .bold))
                .foregroundColor(Theme.ink)
            Text("说一句或写一句，AI 帮你变成带时间的提醒")
                .font(Theme.rounded(13, .medium))
                .foregroundColor(Theme.subInk)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.teal)
                    Text("现在想到的是")
                        .font(Theme.rounded(12, .semibold))
                        .foregroundColor(Theme.subInk)
                }
                Spacer()
                Text("\(trimmedText.count) 字")
                    .font(Theme.rounded(11, .medium))
                    .foregroundColor(Theme.faint)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("比如：明天下午三点提醒我去交体检报告，顺便买点水果")
                        .font(Theme.rounded(15, .regular))
                        .foregroundColor(Theme.faint)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Theme.rounded(16, .regular))
                    .foregroundColor(Theme.ink)
                    .accentColor(Theme.teal)
                    .frame(minHeight: 120, maxHeight: 170)
                    .padding(.horizontal, -4)
            }

            Rectangle()
                .fill(Theme.deep.opacity(0.07))
                .frame(height: 1)

            HStack(spacing: 12) {
                if recorder.isRecording {
                    WaveformBars(level: recorder.level, color: Theme.teal)
                        .frame(width: 76)
                    Text(Fmt.clock(recorder.duration))
                        .font(Theme.mono(14))
                        .foregroundColor(Theme.deep)
                    Text("松手结束")
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.subInk)
                } else if isTranscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.teal))
                        .scaleEffect(0.8)
                    Text("正在转成文字…")
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.subInk)
                } else {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.faint)
                    Text(settings.hasAliyun ? "按住麦克风说话" : "语音识别未配置，可先用文字")
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.subInk)
                }

                Spacer(minLength: 4)
                micButton
            }
        }
        .padding(18)
        .glass(radius: 28, tint: 0.46)
    }

    private var micButton: some View {
        ZStack {
            if recorder.isRecording {
                Circle()
                    .stroke(Theme.teal.opacity(0.28), lineWidth: 7)
                    .frame(width: 82, height: 82)
            }
            Circle()
                .fill(recorder.isRecording ? AnyShapeStyle(Theme.warm) : AnyShapeStyle(Theme.brand))
                .frame(width: 64, height: 64)
                .shadow(color: Theme.teal.opacity(0.32), radius: 14, x: 0, y: 8)

            if isTranscribing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 82, height: 82)
        .scaleEffect(recorder.isRecording ? 1.05 : 1)
        .animation(.easeInOut(duration: 0.18), value: recorder.isRecording)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginRecording() }
                .onEnded { _ in endRecording() }
        )
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            GhostButton(title: "存为想法", icon: "bookmark") {
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
            HStack(spacing: 9) {
                Image(systemName: "key.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.amber)
                Text("还没填 DeepSeek Key，AI 解析暂时不可用")
                    .font(Theme.rounded(12, .medium))
                    .foregroundColor(Theme.subInk)
                Spacer(minLength: 4)
                Text("去填写")
                    .font(Theme.rounded(12, .bold))
                    .foregroundColor(Theme.teal)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.5)))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Drafts

    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 拆成了 \(drafts.count) 个提醒")
                    .font(Theme.rounded(15, .bold))
                    .foregroundColor(Theme.ink)
                Spacer()
                Button(action: {
                    Haptics.tap()
                    parseText()
                }) {
                    Text("重新生成")
                        .font(Theme.rounded(12, .semibold))
                        .foregroundColor(Theme.teal)
                }
            }

            ForEach($drafts) { $draft in
                DraftCard(draft: $draft) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        drafts.removeAll { $0.id == draft.id }
                    }
                }
            }

            PrimaryButton(title: "全部加入提醒", icon: "checkmark.circle.fill") {
                addAllDrafts()
            }
            .padding(.top, 4)
        }
        .padding(.top, 4)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近的想法",
                          subtitle: "空的就记录一句，久了会看见自己的节奏",
                          trailing: store.ideas.isEmpty ? nil : "\(store.ideas.count) 条")

            if store.ideas.isEmpty {
                Text("还没有记录")
                    .font(Theme.rounded(12, .medium))
                    .foregroundColor(Theme.faint)
                    .padding(.leading, 4)
            } else {
                ForEach(Array(store.latestIdeas.prefix(5))) { idea in
                    IdeaRow(idea: idea)
                        .onTapGesture {
                            Haptics.soft()
                            text = idea.text
                        }
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Recording flow

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginRecording() {
        guard !recorder.isRecording, !isTranscribing else { return }
        guard settings.hasAliyun else {
            presentError(ASRError.missingConfig)
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
        let appKey = settings.trimmedAppKey
        var token = settings.trimmedToken
        let expire = settings.aliyunTokenExpire
        let akId = settings.aliyunAccessKeyId
        let akSecret = settings.aliyunAccessKeySecret

        Task {
            do {
                let data = try Data(contentsOf: url)
                let pcm = AliyunASRService.rawPCM(fromWav: data)

                if token.isEmpty || expire < Date().timeIntervalSince1970 {
                    let result = try await AliyunASRService.createToken(accessKeyId: akId,
                                                                       accessKeySecret: akSecret)
                    token = result.token
                    await MainActor.run {
                        settings.aliyunToken = result.token
                        settings.aliyunTokenExpire = result.expire.timeIntervalSince1970
                    }
                }

                let recognized = try await AliyunASRService.recognize(pcm: pcm, appKey: appKey, token: token)
                await MainActor.run {
                    if self.text.isEmpty {
                        self.text = recognized
                    } else {
                        self.text += " " + recognized
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

    // MARK: - AI flow

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

    private func addAllDrafts() {
        let valid = drafts.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !valid.isEmpty else { return }
        let tasks = valid.map { $0.makeTask(defaultLead: settings.defaultLeadMinutes) }
        store.add(tasks)
        store.addIdea(IdeaNote(text: trimmedText.isEmpty ? "AI 生成的提醒" : trimmedText,
                               source: lastSource,
                               converted: tasks.count))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            drafts = []
            text = ""
            lastSource = .text
        }
        Haptics.success()
        showToast("已加入 \(tasks.count) 个提醒")
    }

    private func saveAsIdea() {
        guard !trimmedText.isEmpty else { return }
        store.addIdea(IdeaNote(text: trimmedText, source: lastSource, converted: 0))
        withAnimation {
            text = ""
            lastSource = .text
        }
        Haptics.success()
        showToast("已存为想法")
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

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeOut(duration: 0.25)) {
                toast = nil
            }
        }
    }
}

// MARK: - Draft Card

private struct DraftCard: View {
    @Binding var draft: AIDraft
    var onRemove: () -> Void

    @State private var hasTime: Bool

    init(draft: Binding<AIDraft>, onRemove: @escaping () -> Void) {
        self._draft = draft
        self.onRemove = onRemove
        self._hasTime = State(initialValue: draft.wrappedValue.dueDate != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                TextField("任务名称", text: $draft.title)
                    .font(Theme.rounded(16, .semibold))
                    .foregroundColor(Theme.ink)
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.faint.opacity(0.7))
                }
                .buttonStyle(PressableStyle())
            }

            if !draft.note.isEmpty {
                TextField("备注", text: $draft.note)
                    .font(Theme.rounded(13, .regular))
                    .foregroundColor(Theme.subInk)
            }

            HStack(spacing: 8) {
                Button(action: {
                    Haptics.soft()
                    hasTime.toggle()
                    if hasTime {
                        if draft.dueDate == nil {
                            draft.dueDate = Date().addingTimeInterval(3600)
                        }
                    } else {
                        draft.dueDate = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hasTime ? "clock.fill" : "clock")
                            .font(.system(size: 10, weight: .bold))
                        Text(hasTime ? "定时" : "不定时")
                            .font(Theme.rounded(11, .semibold))
                    }
                    .foregroundColor(hasTime ? .white : Theme.subInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(hasTime ? AnyShapeStyle(Theme.brandBar) : AnyShapeStyle(Color.white.opacity(0.7)))
                    )
                }
                .buttonStyle(PressableStyle())

                if hasTime {
                    DatePicker("",
                               selection: Binding(get: { draft.dueDate ?? Date() },
                                                  set: { draft.dueDate = $0 }),
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Spacer(minLength: 4)
            }

            HStack(spacing: 6) {
                ForEach(TaskPriority.allCases) { priority in
                    Button(action: {
                        Haptics.soft()
                        draft.priority = priority
                    }) {
                        Text(priority.label)
                            .font(Theme.rounded(11, .semibold))
                            .foregroundColor(draft.priority == priority ? .white : priority.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(draft.priority == priority
                                    ? AnyShapeStyle(priority.color)
                                    : AnyShapeStyle(priority.color.opacity(0.12)))
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
                Spacer()
            }
        }
        .padding(14)
        .glass(radius: 20, tint: 0.44)
    }
}

// MARK: - Idea Row

private struct IdeaRow: View {
    let idea: IdeaNote

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill((idea.source == .voice ? Theme.sky : Theme.teal).opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: idea.source.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(idea.source == .voice ? Theme.sky : Theme.teal)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(idea.text)
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(Fmt.full(idea.createdAt))
                        .font(Theme.rounded(11, .medium))
                        .foregroundColor(Theme.faint)
                    if idea.converted > 0 {
                        Text("已生成 \(idea.converted) 个提醒")
                            .font(Theme.rounded(11, .semibold))
                            .foregroundColor(Theme.teal)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .glass(radius: 16, tint: 0.3)
    }
}
