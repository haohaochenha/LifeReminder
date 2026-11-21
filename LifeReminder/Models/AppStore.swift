import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var ideas: [IdeaNote] = []

    private var saveWorkItem: DispatchWorkItem?

    private struct Snapshot: Codable {
        var tasks: [TaskItem]
        var ideas: [IdeaNote]
    }

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("LifeReminder", isDirectory: true)
    }

    private var storeURL: URL {
        directoryURL.appendingPathComponent("data.json")
    }

    init() {
        load()
    }

    // MARK: - Derived collections

    var activeTasks: [TaskItem] {
        tasks.filter { !$0.isDone }.sorted { $0.dueDate < $1.dueDate }
    }

    var completedTasks: [TaskItem] {
        tasks.filter { $0.isDone }
            .sorted { ($0.completedAt ?? $0.dueDate) > ($1.completedAt ?? $1.dueDate) }
    }

    /// 今天到期的未完成任务 + 已逾期任务。
    var todayTasks: [TaskItem] {
        activeTasks.filter { $0.isToday || $0.isOverdue }
    }

    var nextTask: TaskItem? {
        let upcoming = activeTasks.first { $0.dueDate >= Date() }
        return upcoming ?? activeTasks.first
    }

    var todayTotal: Int {
        tasks.filter { $0.isToday }.count
    }

    var todayDone: Int {
        tasks.filter { $0.isDone && $0.isToday }.count
    }

    var overdueCount: Int {
        activeTasks.filter { $0.isOverdue }.count
    }

    var latestIdeas: [IdeaNote] {
        ideas.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Mutations

    func add(_ task: TaskItem) {
        tasks.append(task)
        persist()
    }

    func add(_ newTasks: [TaskItem]) {
        guard !newTasks.isEmpty else { return }
        tasks.append(contentsOf: newTasks)
        persist()
    }

    func update(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        persist()
    }

    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    func toggle(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
        tasks[index].completedAt = tasks[index].isDone ? Date() : nil
        persist()
    }

    func addIdea(_ idea: IdeaNote) {
        ideas.insert(idea, at: 0)
        if ideas.count > 120 {
            ideas = Array(ideas.prefix(120))
        }
        persist()
    }

    func markIdeaConverted(_ id: UUID, count: Int) {
        guard let index = ideas.firstIndex(where: { $0.id == id }) else { return }
        ideas[index].converted += count
        persist()
    }

    func clearCompleted() {
        tasks.removeAll { $0.isDone }
        persist()
    }

    func resetEverything() {
        tasks = []
        ideas = []
        persist()
    }

    // MARK: - Notifications

    func syncNotifications(enabled: Bool) {
        NotificationManager.shared.sync(tasks: tasks, enabled: enabled)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            seed()
            return
        }
        tasks = snapshot.tasks
        ideas = snapshot.ideas
    }

    private func seed() {
        let now = Date()
        let calendar = Calendar.current
        var evening = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: now) ?? now
        if evening <= now {
            evening = now.addingTimeInterval(5 * 3600)
        }
        let examples = [
            TaskItem(title: "喝一杯水，伸个懒腰",
                     note: "长按任务可以编辑或删除",
                     tag: "健康",
                     dueDate: now.addingTimeInterval(45 * 60),
                     priority: .normal,
                     leadMinutes: 5,
                     createdAt: now.addingTimeInterval(-10 * 60)),
            TaskItem(title: "整理明天最重要的三件事",
                     note: "想清楚再睡觉，明天会更轻松",
                     tag: "计划",
                     dueDate: now.addingTimeInterval(3 * 3600),
                     priority: .high,
                     leadMinutes: 10,
                     createdAt: now.addingTimeInterval(-20 * 60)),
            TaskItem(title: "早点休息",
                     note: "",
                     tag: "健康",
                     dueDate: evening,
                     priority: .low,
                     leadMinutes: 15,
                     createdAt: now)
        ]
        tasks = examples
        persist()
    }

    private func persist() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.writeToDisk()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private func writeToDisk() {
        let snapshot = Snapshot(tasks: tasks, ideas: ideas)
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snapshot)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("LifeReminder persistence error:", error)
        }
    }
}
