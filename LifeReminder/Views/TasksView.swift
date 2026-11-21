import SwiftUI

private enum TaskFilter: String, CaseIterable, Identifiable {
    case active = "进行中"
    case today = "今天"
    case done = "已完成"
    case all = "全部"

    var id: String { rawValue }
}

private struct TaskSection: Identifiable {
    let id: String
    let title: String
    let tasks: [TaskItem]
}

struct TasksView: View {
    @EnvironmentObject private var store: AppStore

    @State private var filter: TaskFilter = .active
    @State private var route: EditorRoute?

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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chips
            list
        }
        .padding(.top, 10)
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

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("全部任务")
                    .font(Theme.rounded(30, .bold))
                    .foregroundColor(Theme.ink)
                Text(summary)
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.subInk)
            }
            Spacer(minLength: 0)
            GlassIconButton(icon: "plus", size: 46) {
                route = .create
            }
        }
    }

    private var summary: String {
        let active = store.activeTasks.count
        if active == 0 { return "暂时没有待办，轻松一下" }
        if store.overdueCount > 0 {
            return "\(active) 件待办 · \(store.overdueCount) 件已逾期"
        }
        return "\(active) 件待办 · 都在掌控中"
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { item in
                    FilterChip(title: item.rawValue, selected: filter == item) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            filter = item
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                if sections.isEmpty {
                    EmptyStateView(icon: emptyIcon,
                                   title: emptyTitle,
                                   message: emptyMessage)
                        .padding(.top, 20)
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 7) {
                                Text(section.title)
                                    .font(Theme.rounded(14, .bold))
                                    .foregroundColor(section.id == "overdue" ? Theme.coral : Theme.subInk)
                                Text("\(section.tasks.count)")
                                    .font(Theme.rounded(11, .bold))
                                    .foregroundColor(Theme.subInk.opacity(0.8))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.6)))
                                Spacer()
                            }
                            .padding(.leading, 4)

                            ForEach(section.tasks) { task in
                                TaskRow(task: task,
                                        onToggle: { store.toggle(task) },
                                        onEdit: { route = .edit(task) },
                                        onDelete: { store.delete(task) })
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
    }

    private var sections: [TaskSection] {
        switch filter {
        case .done:
            guard !store.completedTasks.isEmpty else { return [] }
            return [TaskSection(id: "done", title: "已完成", tasks: store.completedTasks)]
        case .today:
            guard !store.todayTasks.isEmpty else { return [] }
            return [TaskSection(id: "today", title: "今天", tasks: store.todayTasks)]
        case .active:
            return grouped(store.activeTasks)
        case .all:
            var result = grouped(store.tasks)
            if !store.completedTasks.isEmpty {
                result.append(TaskSection(id: "done", title: "已完成", tasks: store.completedTasks))
            }
            return result
        }
    }

    private func grouped(_ items: [TaskItem]) -> [TaskSection] {
        var overdue: [TaskItem] = []
        var today: [TaskItem] = []
        var tomorrow: [TaskItem] = []
        var later: [TaskItem] = []

        for task in items where !task.isDone {
            if task.isOverdue {
                overdue.append(task)
            } else if task.isToday {
                today.append(task)
            } else if task.isTomorrow {
                tomorrow.append(task)
            } else {
                later.append(task)
            }
        }

        var result: [TaskSection] = []
        if !overdue.isEmpty {
            result.append(TaskSection(id: "overdue", title: "已逾期", tasks: overdue))
        }
        if !today.isEmpty {
            result.append(TaskSection(id: "today", title: "今天", tasks: today))
        }
        if !tomorrow.isEmpty {
            result.append(TaskSection(id: "tomorrow", title: "明天", tasks: tomorrow))
        }
        if !later.isEmpty {
            result.append(TaskSection(id: "later", title: "以后", tasks: later))
        }
        return result
    }

    private var emptyIcon: String {
        switch filter {
        case .done: return "checkmark.seal"
        case .today: return "sun.max"
        default: return "sparkles"
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .done: return "还没有完成的任务"
        case .today: return "今天很清闲"
        default: return "没有待办"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .done: return "完成一个任务，它会出现在这里。"
        case .today: return "今天没有到期的事，去记录一个想法吧。"
        default: return "点右上角的 + 新建一个提醒。"
        }
    }
}
