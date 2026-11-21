import SwiftUI

struct TaskEditorView: View {
    @State private var draft: TaskItem
    @State private var showDeleteConfirm = false

    private let isNew: Bool
    private let onSave: (TaskItem) -> Void
    private let onDelete: ((TaskItem) -> Void)?
    private let onClose: () -> Void

    init(task: TaskItem?,
         onSave: @escaping (TaskItem) -> Void,
         onDelete: ((TaskItem) -> Void)?,
         onClose: @escaping () -> Void) {
        _draft = State(initialValue: task ?? TaskItem(title: "",
                                                      dueDate: Date().addingTimeInterval(3600),
                                                      leadMinutes: 10))
        isNew = (task == nil)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrip()

            HStack {
                Button(action: onClose) {
                    Text("取消")
                        .font(Theme.font(17))
                        .foregroundColor(Theme.label2)
                }
                .frame(width: 60, alignment: .leading)

                Spacer()

                Text(isNew ? "新建提醒" : "编辑提醒")
                    .font(Theme.font(17, .semibold))
                    .foregroundColor(Theme.label)

                Spacer()

                Button(action: save) {
                    Text(isNew ? "添加" : "保存")
                        .font(Theme.font(17, .semibold))
                        .foregroundColor(canSave ? Theme.blue : Theme.label3)
                }
                .frame(width: 60, alignment: .trailing)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    GroupCard(radius: 22) {
                        HStack {
                            TextField("想做什么？", text: $draft.title)
                                .font(Theme.font(19, .medium))
                                .foregroundColor(Theme.label)
                                .accentColor(Theme.blue)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)

                        CellDivider(inset: 16)

                        HStack(spacing: 10) {
                            Text("时间")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.label)
                            Spacer()
                            DatePicker("",
                                       selection: $draft.dueDate,
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .accentColor(Theme.blue)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)

                        CellDivider(inset: 16)

                        HStack(spacing: 10) {
                            Text("提前")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.label)
                            Spacer()
                            Menu {
                                ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                                    Button(leadLabel(minutes)) {
                                        draft.leadMinutes = minutes
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(leadLabel(draft.leadMinutes))
                                        .font(Theme.font(15))
                                        .foregroundColor(Theme.label2)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.label3)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                    }

                    Text("重要程度")
                        .font(Theme.font(13, .semibold))
                        .foregroundColor(Theme.label2)
                        .padding(.leading, 6)

                    SegmentedControl(items: ["不急", "普通", "重要"], selection: priorityIndex)

                    if !isNew && onDelete != nil {
                        Button(action: {
                            Haptics.warning()
                            showDeleteConfirm = true
                        }) {
                            Text("删除这个提醒")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Capsule().fill(Theme.fill))
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(title: Text("删除这个提醒？"),
                  message: Text("删除后无法恢复。"),
                  primaryButton: .destructive(Text("删除")) {
                      onDelete?(draft)
                  },
                  secondaryButton: .cancel(Text("取消")))
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var priorityIndex: Binding<Int> {
        Binding(get: {
            TaskPriority.allCases.firstIndex(of: draft.priority) ?? 1
        }, set: { index in
            let cases = TaskPriority.allCases
            if cases.indices.contains(index) {
                draft.priority = cases[index]
            }
        })
    }

    private func leadLabel(_ minutes: Int) -> String {
        minutes <= 0 ? "准时" : "提前 \(minutes) 分钟"
    }

    private func save() {
        guard canSave else { return }
        var task = draft
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.leadMinutes = max(0, min(180, task.leadMinutes))
        Haptics.success()
        onSave(task)
    }
}

struct AnniversarySheet: View {
    @State private var title = ""
    @State private var date = Date()

    let onSave: (Anniversary) -> Void
    let onClose: () -> Void

    init(onSave: @escaping (Anniversary) -> Void,
         onClose: @escaping () -> Void) {
        self.onSave = onSave
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrip()

            HStack {
                Button(action: onClose) {
                    Text("取消")
                        .font(Theme.font(17))
                        .foregroundColor(Theme.label2)
                }
                .frame(width: 60, alignment: .leading)

                Spacer()

                Text("新建纪念日")
                    .font(Theme.font(17, .semibold))
                    .foregroundColor(Theme.label)

                Spacer()

                Button(action: save) {
                    Text("添加")
                        .font(Theme.font(17, .semibold))
                        .foregroundColor(canSave ? Theme.blue : Theme.label3)
                }
                .frame(width: 60, alignment: .trailing)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 14) {
                GroupCard(radius: 22) {
                    TextField("纪念日名称，比如「在一起」", text: $title)
                        .font(Theme.font(19, .medium))
                        .foregroundColor(Theme.label)
                        .accentColor(Theme.blue)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)

                    CellDivider(inset: 16)

                    HStack {
                        Text("日期")
                            .font(Theme.font(17))
                            .foregroundColor(Theme.label)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .accentColor(Theme.blue)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                }

                GFCaption(text: "选过去的日期会显示已经坚持了多久，选未来的日期会显示倒计时。轻点卡片可以翻面查看和删除。")
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard canSave else { return }
        let item = Anniversary(title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: date)
        Haptics.success()
        onSave(item)
    }
}

private struct SheetGrip: View {
    var body: some View {
        Capsule()
            .fill(Theme.label3)
            .frame(width: 38, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }
}
