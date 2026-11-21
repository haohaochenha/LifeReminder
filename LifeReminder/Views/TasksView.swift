import SwiftUI

private struct TaskSection: Identifiable {
    let id: String
    let title: String
    let tasks: [TaskItem]
}

struct TasksView: View {
    @EnvironmentObject private var store: AppStore

    @Binding var filterIndex: Int

    let addTask: () -> Void
    let editTask: (TaskItem) -> Void
    let toast: (String, Bool) -> Void

    private let filters = ["进行中", "今天", "已完成", "全部"]

    init(filterIndex: Binding<Int>,
         addTask: @escaping () -> Void,
         editTask: @escaping (TaskItem) -> Void,
         toast: @escaping (String, Bool) -> Void) {
        self._filterIndex = filterIndex
        self.addTask = addTask
        self.editTask = editTask
        self.toast = toast
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                SegmentedControl(items: filters, selection: $filterIndex)
                Text("左滑删除 · 点一下编辑")
                    .font(Theme.font(13))
                    .foregroundColor(Theme.label3)
                    .padding(.horizontal, 4)

                if sections.isEmpty {
                    GroupCard {
                        EmptyStateView(icon: emptyIcon, message: emptyMessage)
                    }
                    .padding(.top, 4)
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(Theme.font(13, .semibold))
                                .foregroundColor(section.id == "overdue" ? Theme.red : Theme.label2)
                                .padding(.leading, 6)

                            GroupCard {
                                ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                                    TaskRow(task: task,
                                            showDivider: index > 0,
                                            onToggle: {
                                                store.toggle(task)
                                                if !task.isDone { toast("完成了一件，真不错", true) }
                                            },
                                            onEdit: { editTask(task) },
                                            onDelete: {
                                                store.delete(task)
                                                toast("已删除", true)
                                            })
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("全部任务")
                .font(Theme.font(34, .bold))
                .foregroundColor(Theme.label)
                .tracking(-0.5)
            Text(summary)
                .font(Theme.font(15))
                .foregroundColor(Theme.label2)
        }
        .padding(.bottom, 4)
    }

    private var summary: String {
        let active = store.activeTasks.count
        if active == 0 { return "暂时没有待办，轻松一下" }
        if store.overdueCount > 0 {
            return "\(active) 件待办 · \(store.overdueCount) 件已逾期"
        }
        return "\(active) 件待办 · 都在掌控中"
    }

    private var sections: [TaskSection] {
        switch filterIndex {
        case 1:
            guard !store.todayTasks.isEmpty else { return [] }
            return [TaskSection(id: "today", title: "今天", tasks: store.todayTasks)]
        case 2:
            guard !store.completedTasks.isEmpty else { return [] }
            return [TaskSection(id: "done", title: "已完成", tasks: store.completedTasks)]
        case 3:
            var result = grouped(store.tasks)
            if !store.completedTasks.isEmpty {
                result.append(TaskSection(id: "done", title: "已完成", tasks: store.completedTasks))
            }
            return result
        default:
            return grouped(store.activeTasks)
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
        switch filterIndex {
        case 2: return "checkmark.seal"
        case 1: return "sun.max"
        default: return "tray"
        }
    }

    private var emptyMessage: String {
        switch filterIndex {
        case 2: return "还没有完成的任务"
        case 1: return "今天没有到期的事，去记录一个想法吧"
        default: return "点右上角的 + 新建一个提醒"
        }
    }
}
