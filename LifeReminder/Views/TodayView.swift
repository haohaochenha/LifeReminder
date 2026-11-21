import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore

    @State private var now = Date()
    @State private var route: EditorRoute?

    let openCapture: () -> Void

    private enum EditorRoute: Identifiable {
        case create
        case edit(TaskItem)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let task): return task.id.uuidString
            }
        }
    }

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                countdownCard
                statsRow
                listenCard

                HStack {
                    SectionHeader(title: "今天的安排",
                                  subtitle: store.todayTasks.isEmpty ? "清空了，去歇一会儿" : "按时间顺序排好了",
                                  trailing: store.todayTasks.isEmpty ? nil : "\(store.todayTasks.count) 件")
                }

                if store.todayTasks.isEmpty {
                    EmptyStateView(icon: "sparkles",
                                   title: "今天没有待办",
                                   message: "把脑子里的事说一句，\nAI 会帮你拆成带时间的提醒。")
                        .onTapGesture { openCapture() }
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.todayTasks) { task in
                            TaskRow(task: task,
                                    onToggle: { store.toggle(task) },
                                    onEdit: { route = .edit(task) },
                                    onDelete: { store.delete(task) })
                        }
                    }
                }

                if let next = store.nextTask {
                    reminderHint(next)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .onReceive(ticker) { now = $0 }
        .sheet(item: $route) { route in
            switch route {
            case .create:
                TaskEditorView(task: nil) { task in
                    store.add(task)
                }
            case .edit(let task):
                TaskEditorView(task: task,
                               onSave: { updated in store.update(updated) },
                               onDelete: { target in store.delete(target) })
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Fmt.monthDay(now)) · \(Fmt.weekday(now))")
                    .font(Theme.rounded(13, .semibold))
                    .foregroundColor(Theme.subInk)
                Text(greeting)
                    .font(Theme.rounded(30, .bold))
                    .foregroundColor(Theme.ink)
                Text(subGreeting)
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.subInk)
            }
            Spacer(minLength: 0)
            GlassIconButton(icon: "plus", size: 46) {
                route = .create
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 0..<6: return "夜深了"
        case 6..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var subGreeting: String {
        let count = store.todayTasks.count
        if count == 0 {
            return "今天暂时没有安排"
        }
        return "今天还有 \(count) 件事，慢慢来"
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownCard: some View {
        if let next = store.nextTask {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("下一件事")
                            .font(Theme.rounded(12, .bold))
                    }
                    .foregroundColor(Theme.deep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.8)))

                    Spacer()

                    Text(next.priority.label)
                        .font(Theme.rounded(11, .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                }

                Text(next.title)
                    .font(Theme.rounded(24, .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(next.secondsLeft > 0 ? Fmt.remaining(next.secondsLeft) : "已超过时间")
                        .font(Theme.mono(27))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(next.secondsLeft > 0 ? "后" : "")
                        .font(Theme.rounded(13, .semibold))
                        .foregroundColor(.white.opacity(0.72))
                    Spacer(minLength: 6)
                    Text(Fmt.time(next.dueDate))
                        .font(Theme.rounded(15, .bold))
                        .foregroundColor(.white.opacity(0.95))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: max(6, geo.size.width * CGFloat(next.progress)))
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(Fmt.relativeDay(next.dueDate)) \(Fmt.time(next.dueDate))")
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(next.remindText)
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.brand)
            )
            .overlay(
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 190, height: 190)
                        .offset(x: 130, y: -90)
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 110, height: 110)
                        .offset(x: 70, y: 110)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Theme.deep.opacity(0.28), radius: 24, x: 0, y: 14)
        } else {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.teal.opacity(0.14)).frame(width: 54, height: 54)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Theme.teal)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("今天没有待办了")
                        .font(Theme.rounded(17, .bold))
                        .foregroundColor(Theme.ink)
                    Text("有新想法就记一句，AI 帮你安排")
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.subInk)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .glass(radius: 26, tint: 0.36)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPill(title: "待办", value: "\(store.activeTasks.count)")
            StatPill(title: "今日完成", value: "\(store.todayDone)/\(store.todayTotal)", tint: Theme.teal)
            StatPill(title: "逾期", value: "\(store.overdueCount)", tint: store.overdueCount > 0 ? Theme.coral : Theme.deep)
        }
    }

    // MARK: - Quick capture

    private var listenCard: some View {
        Button(action: {
            Haptics.tap()
            openCapture()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.brand).frame(width: 46, height: 46)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("随手记一句")
                        .font(Theme.rounded(16, .bold))
                        .foregroundColor(Theme.ink)
                    Text("按住说话，AI 帮你变成任务")
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.subInk)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .glass(radius: 22, tint: 0.38)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Hint

    private func reminderHint(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.amber)
            Text("会在 \(task.remindText) 提醒你 · \(Fmt.due(task.dueDate))")
                .font(Theme.rounded(12, .medium))
                .foregroundColor(Theme.subInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: TaskItem
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(task.isDone ? Theme.faint.opacity(0.45) : task.priority.color)
                .frame(width: 3.5)
                .frame(maxHeight: 36)
                .padding(.vertical, 2)

            TaskCheck(done: task.isDone, action: onToggle)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(Theme.rounded(16, .semibold))
                    .foregroundColor(task.isDone ? Theme.faint : Theme.ink)
                    .strikethrough(task.isDone, color: Theme.faint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "clock")
                        .font(.system(size: 10, weight: .semibold))
                    Text(task.isOverdue ? "已逾期 · \(Fmt.due(task.dueDate))" : Fmt.due(task.dueDate))
                        .font(Theme.rounded(12, .medium))
                    if !task.note.isEmpty {
                        Text("·")
                        Text(task.note)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(task.isOverdue ? Theme.coral : Theme.subInk)
            }

            Spacer(minLength: 4)

            if !task.isDone {
                PriorityTag(priority: task.priority)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .glass(radius: 20, tint: task.isDone ? 0.28 : 0.42)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { onEdit() }
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Button(action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
