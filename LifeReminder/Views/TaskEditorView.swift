import SwiftUI

struct TaskEditorView: View {
    @Environment(\.presentationMode) private var presentationMode

    @State private var draft: TaskItem
    @State private var showDeleteConfirm = false

    private let isNew: Bool
    private let onSave: (TaskItem) -> Void
    private let onDelete: ((TaskItem) -> Void)?

    init(task: TaskItem?,
         onSave: @escaping (TaskItem) -> Void,
         onDelete: ((TaskItem) -> Void)? = nil) {
        _draft = State(initialValue: task ?? TaskItem(title: "",
                                                      dueDate: Date().addingTimeInterval(3600),
                                                      leadMinutes: 10))
        isNew = (task == nil)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        LabeledField(title: "要做什么",
                                     placeholder: "例如：给妈妈打个电话",
                                     text: $draft.title,
                                     icon: "pencil")

                        noteField
                        timeField
                        priorityField

                        LabeledField(title: "标签",
                                     placeholder: "生活 / 工作 / 健康",
                                     text: $draft.tag,
                                     icon: "tag.fill")

                        PrimaryButton(title: isNew ? "添加提醒" : "保存修改",
                                      icon: "checkmark.circle.fill",
                                      enabled: canSave) {
                            save()
                        }
                        .padding(.top, 4)

                        if !isNew && onDelete != nil {
                            Button(action: {
                                Haptics.warning()
                                showDeleteConfirm = true
                            }) {
                                Text("删除这个提醒")
                                    .font(Theme.rounded(14, .semibold))
                                    .foregroundColor(Theme.coral)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(Capsule().fill(Theme.coral.opacity(0.10)))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 34)
                }
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(title: Text("删除这个提醒？"),
                  message: Text("删除后无法恢复。"),
                  primaryButton: .destructive(Text("删除")) {
                      onDelete?(draft)
                      presentationMode.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel(Text("取消")))
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("取消")
                    .font(Theme.rounded(15, .semibold))
                    .foregroundColor(Theme.subInk)
            }
            .frame(width: 56, alignment: .leading)

            Spacer()

            Text(isNew ? "新建提醒" : "编辑提醒")
                .font(Theme.rounded(17, .bold))
                .foregroundColor(Theme.ink)

            Spacer()

            Button(action: save) {
                Text("保存")
                    .font(Theme.rounded(15, .bold))
                    .foregroundColor(canSave ? Theme.teal : Theme.faint)
            }
            .frame(width: 56, alignment: .trailing)
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("备注")
                .font(Theme.rounded(12, .semibold))
                .foregroundColor(Theme.subInk)

            ZStack(alignment: .topLeading) {
                if draft.note.isEmpty {
                    Text("补充一点细节，提醒时会一起显示")
                        .font(Theme.rounded(14, .regular))
                        .foregroundColor(Theme.faint)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft.note)
                    .font(Theme.rounded(14, .regular))
                    .foregroundColor(Theme.ink)
                    .accentColor(Theme.teal)
                    .frame(height: 76)
                    .padding(.horizontal, -4)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.62)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
            )
        }
    }

    private var timeField: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.teal)
                Text("提醒时间")
                    .font(Theme.rounded(12, .semibold))
                    .foregroundColor(Theme.subInk)
                Spacer()
                Text(draft.secondsLeft > 0 ? "还有 \(Fmt.remaining(draft.secondsLeft))" : "时间已过")
                    .font(Theme.rounded(11, .medium))
                    .foregroundColor(draft.secondsLeft > 0 ? Theme.faint : Theme.coral)
            }

            DatePicker("",
                       selection: $draft.dueDate,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .accentColor(Theme.teal)

            HStack {
                Text("提前提醒")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.subInk)
                Spacer()
                Menu {
                    ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        Button(leadLabel(minutes)) {
                            draft.leadMinutes = minutes
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(leadLabel(draft.leadMinutes))
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
        .padding(16)
        .glass(radius: 22, tint: 0.4)
    }

    private var priorityField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("重要程度")
                .font(Theme.rounded(12, .semibold))
                .foregroundColor(Theme.subInk)

            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases) { priority in
                    Button(action: {
                        Haptics.soft()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            draft.priority = priority
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: priority.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(priority.label)
                                .font(Theme.rounded(13, .semibold))
                        }
                        .foregroundColor(draft.priority == priority ? .white : priority.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Capsule().fill(draft.priority == priority
                                ? AnyShapeStyle(priority.color)
                                : AnyShapeStyle(priority.color.opacity(0.10)))
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(16)
        .glass(radius: 22, tint: 0.4)
    }

    private func leadLabel(_ minutes: Int) -> String {
        minutes <= 0 ? "准时提醒" : "提前 \(minutes) 分钟"
    }

    private func save() {
        guard canSave else { return }
        var task = draft
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.tag = task.tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "生活" : task.tag
        task.leadMinutes = max(0, min(180, task.leadMinutes))
        Haptics.success()
        onSave(task)
        presentationMode.wrappedValue.dismiss()
    }
}
