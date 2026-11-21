import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore

    @State private var now = Date()

    let openCapture: () -> Void
    let openTasks: (Int) -> Void
    let addTask: () -> Void
    let editTask: (TaskItem) -> Void
    let addAnniversary: () -> Void
    let toast: (String, Bool) -> Void

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let accents: [Color] = [Theme.blue, Theme.indigo, Theme.orange, Theme.green, Theme.pink]

    init(openCapture: @escaping () -> Void,
         openTasks: @escaping (Int) -> Void,
         addTask: @escaping () -> Void,
         editTask: @escaping (TaskItem) -> Void,
         addAnniversary: @escaping () -> Void,
         toast: @escaping (String, Bool) -> Void) {
        self.openCapture = openCapture
        self.openTasks = openTasks
        self.addTask = addTask
        self.editTask = editTask
        self.addAnniversary = addAnniversary
        self.toast = toast
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                heroCard
                tiles

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "纪念日", actionTitle: "添加", action: addAnniversary)
                    anniversaryRail
                }

                quickCapture
                todaySection
            }
            .background(ScrollTracker())
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 120)
        }
        .coordinateSpace(name: ScrollChrome.spaceName)
        .onReceive(ticker) { now = $0 }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Fmt.dateLine(now))
                .font(Theme.font(13, .semibold))
                .foregroundColor(Theme.label2)
                .tracking(0.6)
            Text(Fmt.greeting(now))
                .font(Theme.font(34, .bold))
                .foregroundColor(Theme.label)
                .tracking(-0.5)
            Text(subtitle)
                .font(Theme.font(15))
                .foregroundColor(Theme.label2)
        }
    }

    private var subtitle: String {
        let count = store.todayTasks.count
        if count == 0 { return "今天都清空了，好好休息" }
        return "今天还有 \(count) 件事，慢慢来"
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let next = store.nextTask {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 18) {
                    RingProgress(progress: next.progress)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(next.priority.color)
                                .frame(width: 6, height: 6)
                            Text("下一件事")
                                .font(Theme.font(13, .semibold))
                                .foregroundColor(Theme.label2)
                        }

                        Text(next.title)
                            .font(Theme.font(19, .bold))
                            .foregroundColor(Theme.label)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        countdownRow(next)

                        HStack(spacing: 5) {
                            Text(Fmt.due(next.dueDate))
                                .font(Theme.font(13))
                                .foregroundColor(Theme.label2)
                            Text("·")
                                .font(Theme.font(13))
                                .foregroundColor(Theme.label3)
                            Text(next.priority.label)
                                .font(Theme.font(13, .medium))
                                .foregroundColor(next.priority.color)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)

                CellDivider(inset: 18)

                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.blue)
                    Text(next.remindText)
                        .font(Theme.font(13))
                        .foregroundColor(Theme.label2)
                    Spacer()
                    Text("临近进度")
                        .font(Theme.font(12))
                        .foregroundColor(Theme.label3)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
            }
            .glassCard(radius: 28)
        } else {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.blue.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(Theme.blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("今天没有待办了")
                        .font(Theme.font(19, .bold))
                        .foregroundColor(Theme.label)
                    Text("有新想法就记一句，AI 帮你安排")
                        .font(Theme.font(14))
                        .foregroundColor(Theme.label2)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .glassCard(radius: 28)
        }
    }

    private func countdownRow(_ task: TaskItem) -> some View {
        let parts = Fmt.countdown(task.secondsLeft)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            if task.secondsLeft <= 0 {
                Text("已到时间")
                    .font(Theme.font(22, .bold))
                    .foregroundColor(Theme.red)
            } else {
                Text(String(format: "%02d", parts.hours))
                    .font(Theme.num(30))
                    .foregroundColor(Theme.blue)
                Text("时")
                    .font(Theme.font(12, .medium))
                    .foregroundColor(Theme.label2)
                Text(String(format: "%02d", parts.minutes))
                    .font(Theme.num(30))
                    .foregroundColor(Theme.blue)
                Text("分")
                    .font(Theme.font(12, .medium))
                    .foregroundColor(Theme.label2)
                Text(String(format: "%02d", parts.seconds))
                    .font(Theme.num(30))
                    .foregroundColor(Theme.blue)
                Text("秒后")
                    .font(Theme.font(12, .medium))
                    .foregroundColor(Theme.label2)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // MARK: - Tiles

    private var tiles: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(icon: "list.bullet", tint: Theme.blue,
                         value: "\(store.activeTasks.count)", label: "待办") {
                    openTasks(0)
                }
                StatTile(icon: "clock", tint: Theme.red,
                         value: "\(store.overdueCount)", label: "逾期") {
                    openTasks(0)
                }
            }
            HStack(spacing: 10) {
                StatTile(icon: "checkmark.seal", tint: Theme.green,
                         value: "\(store.todayDone)/\(store.todayTotal)", label: "今日完成") {
                    openTasks(2)
                }
                StatTile(icon: "sparkles", tint: Theme.orange,
                         value: "\(store.ideas.count)", label: "想法") {
                    openCapture()
                }
            }
        }
    }

    // MARK: - Anniversaries

    private var anniversaryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(store.anniversaries.enumerated()), id: \.element.id) { index, item in
                    AnniversaryCard(item: item,
                                    accent: accents[index % accents.count],
                                    onDelete: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            store.deleteAnniversary(item)
                                        }
                                        toast("已删除纪念日", true)
                                    })
                }

                Button(action: {
                    Haptics.tap()
                    addAnniversary()
                }) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.fill)
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.blue)
                        }
                        Text("添加纪念日")
                            .font(Theme.font(14, .medium))
                            .foregroundColor(Theme.label2)
                    }
                    .frame(width: 176, height: 184)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Theme.label3, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, -20)
    }

    // MARK: - Quick capture

    private var quickCapture: some View {
        Button(action: {
            Haptics.tap()
            openCapture()
        }) {
            HStack(spacing: 12) {
                IconTile(color: Theme.blue, icon: "mic.fill", size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("随手记一句")
                        .font(Theme.font(17, .medium))
                        .foregroundColor(Theme.label)
                    Text("按住说话，AI 帮你变成任务")
                        .font(Theme.font(13))
                        .foregroundColor(Theme.label2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.label3)
            }
            .padding(16)
            .glassCard(radius: 22)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Today list

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "今天的安排",
                         trailing: store.todayTasks.isEmpty ? nil : "\(store.todayTasks.count) 件")

            GroupCard {
                if store.todayTasks.isEmpty {
                    EmptyStateView(icon: "checkmark.circle", message: "今天没有待办，去记录一个想法吧")
                } else {
                    ForEach(Array(store.todayTasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(task: task,
                                showDivider: index > 0,
                                onToggle: { store.toggle(task) },
                                onEdit: { editTask(task) },
                                onDelete: { store.delete(task) })
                    }
                }
            }
        }
    }
}

// MARK: - Anniversary card

private struct AnniversaryCard: View {
    let item: Anniversary
    let accent: Color
    let onDelete: () -> Void

    @State private var flipped = false

    var body: some View {
        ZStack {
            front
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? 90 : 0), axis: (x: 0, y: 1, z: 0))

            back
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipped ? 0 : -90), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: 176, height: 184)
        .background(
            LinearGradient(colors: [accent.opacity(0.20), accent.opacity(0.03)],
                           startPoint: .topTrailing,
                           endPoint: .bottomLeading)
        )
        .glassCard(radius: 26)
        .onTapGesture {
            Haptics.soft()
            withAnimation(.easeInOut(duration: 0.32)) {
                flipped.toggle()
            }
        }
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: 6) {
            IconTile(color: accent, icon: "flag.fill", size: 30, circle: true)

            Text(item.title)
                .font(Theme.font(15, .semibold))
                .foregroundColor(Theme.label)
                .lineLimit(1)
                .padding(.top, 2)

            Text(item.label)
                .font(Theme.font(12))
                .foregroundColor(Theme.label2)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(item.dayCount)")
                    .font(Theme.num(42))
                    .foregroundColor(Theme.label)
                Text("天")
                    .font(Theme.font(14, .medium))
                    .foregroundColor(Theme.label2)
            }

            Text(item.caption)
                .font(Theme.font(12))
                .foregroundColor(Theme.label2)
                .lineLimit(1)

            Spacer(minLength: 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule().fill(accent)
                        .frame(width: max(4, geo.size.width * CGFloat(item.progress)))
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(Theme.font(16, .bold))
                .foregroundColor(Theme.label)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 6) {
                detailRow("开始", Fmt.yearDate(item.date))
                detailRow("折合", item.weekText)
                detailRow("今天", Fmt.yearDate(Date()))
            }

            Spacer(minLength: 0)

            Button(action: {
                Haptics.warning()
                onDelete()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                    Text("删除纪念日")
                        .font(Theme.font(13, .medium))
                }
                .foregroundColor(Theme.red)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(Theme.red.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.font(11, .medium))
                .foregroundColor(Theme.label2)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(Theme.font(12, .medium))
                .foregroundColor(Theme.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Task row

struct TaskRow: View {
    let task: TaskItem
    var showDivider: Bool = true
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var open = false

    init(task: TaskItem,
         showDivider: Bool = true,
         onToggle: @escaping () -> Void,
         onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.task = task
        self.showDivider = showDivider
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                Haptics.warning()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    onDelete()
                }
            }) {
                Text("删除")
                    .font(Theme.font(16, .semibold))
                    .foregroundColor(.white)
                    .frame(width: 88)
                    .frame(maxHeight: .infinity)
                    .background(Theme.red)
            }
            .buttonStyle(.plain)
            .opacity(offset < -1 ? 1 : 0)
            .allowsHitTesting(offset < -1)

            rowContent
                .background(offset < -1 ? Theme.card : Color.clear)
                .offset(x: offset)
                .gesture(dragGesture)
        }
        .clipped()
    }

    private var rowContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                TaskCheck(done: task.isDone, color: task.priority.color, action: onToggle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.font(17, .medium))
                        .foregroundColor(task.isDone ? Theme.label3 : Theme.label)
                        .strikethrough(task.isDone, color: Theme.label3)
                        .lineLimit(1)

                    Text(metaText)
                        .font(Theme.font(14))
                        .foregroundColor(task.isOverdue ? Theme.red : Theme.label2)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if task.priority != .normal && !task.isDone {
                    Text(task.priority.label)
                        .font(Theme.font(13, .semibold))
                        .foregroundColor(task.priority.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                if open {
                    closeRow()
                } else {
                    Haptics.tap()
                    onEdit()
                }
            }

            if showDivider {
                CellDivider(inset: 56)
            }
        }
    }

    private var metaText: String {
        let base = task.isOverdue ? "已逾期 · \(Fmt.due(task.dueDate))" : Fmt.due(task.dueDate)
        if task.note.isEmpty { return base }
        return "\(base) · \(task.note)"
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let base = open ? -88.0 : 0.0
                offset = min(0, max(-280, base + value.translation.width))
            }
            .onEnded { value in
                let base = open ? -88.0 : 0.0
                let x = base + value.translation.width

                // 和 HTML 一致：滑过 -210 直接删除
                if x < -210 {
                    withAnimation(.easeIn(duration: 0.2)) {
                        offset = -420
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDelete()
                    }
                    return
                }

                let shouldOpen = x < -44
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    open = shouldOpen
                    offset = shouldOpen ? -88 : 0
                }
                if shouldOpen { Haptics.soft() }
            }
    }

    private func closeRow() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            open = false
            offset = 0
        }
    }
}
