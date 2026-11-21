import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var ideas: [IdeaNote] = []
    @Published private(set) var anniversaries: [Anniversary] = []

    private var saveWorkItem: DispatchWorkItem?

    private struct Snapshot: Codable {
        var tasks: [TaskItem]
        var ideas: [IdeaNote]
        var anniversaries: [Anniversary]?
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

    // MARK: - Task mutations

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

    // MARK: - Ideas

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

    // MARK: - Anniversaries

    func addAnniversary(_ item: Anniversary) {
        anniversaries.append(item)
        persist()
    }

    func deleteAnniversary(_ item: Anniversary) {
        anniversaries.removeAll { $0.id == item.id }
        persist()
    }

    // MARK: - Maintenance

    func clearCompleted() {
        tasks.removeAll { $0.isDone }
        persist()
    }

    func resetEverything() {
        tasks = []
        ideas = []
        anniversaries = []
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
        anniversaries = snapshot.anniversaries ?? []
    }

    private func seed() {
        let now = Date()
        let calendar = Calendar.current
        var evening = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: now) ?? now
        if evening <= now {
            evening = now.addingTimeInterval(5 * 3600)
        }

        tasks = [
            TaskItem(title: "喝一杯水，伸个懒腰",
                     note: "左滑可以删除，点一下可以编辑",
                     tag: "健康",
                     dueDate: now.addingTimeInterval(45 * 60),
                     priority: .normal,
                     leadMinutes: 5,
                     createdAt: now.addingTimeInterval(-10 * 60)),
            TaskItem(title: "整理明天最重要的三件事",
                     note: "想清楚再睡，明天会轻松一点",
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

        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -30, to: now) ?? now)
        let spring = calendar.date(from: DateComponents(year: 2027, month: 2, day: 6)) ?? now
        anniversaries = [
            Anniversary(title: "开始记录生活", date: start),
            Anniversary(title: "下一个春节", date: spring)
        ]

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
        let snapshot = Snapshot(tasks: tasks, ideas: ideas, anniversaries: anniversaries)
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
