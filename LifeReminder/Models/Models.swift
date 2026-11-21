import SwiftUI

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case normal
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "不急"
        case .normal: return "普通"
        case .high: return "重要"
        }
    }

    var color: Color {
        switch self {
        case .low: return Theme.gray
        case .normal: return Theme.blue
        case .high: return Theme.red
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .normal: return "equal"
        case .high: return "exclamationmark"
        }
    }
}

enum IdeaSource: String, Codable {
    case text
    case voice

    var label: String {
        switch self {
        case .text: return "文字"
        case .voice: return "语音"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .voice: return "waveform"
        }
    }
}

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var note: String
    var tag: String
    var dueDate: Date
    var priority: TaskPriority
    var leadMinutes: Int
    var isDone: Bool
    var createdAt: Date
    var completedAt: Date?
    var notificationID: String

    init(id: UUID = UUID(),
         title: String,
         note: String = "",
         tag: String = "生活",
         dueDate: Date = Date().addingTimeInterval(3600),
         priority: TaskPriority = .normal,
         leadMinutes: Int = 10,
         isDone: Bool = false,
         createdAt: Date = Date(),
         completedAt: Date? = nil,
         notificationID: String = UUID().uuidString) {
        self.id = id
        self.title = title
        self.note = note
        self.tag = tag
        self.dueDate = dueDate
        self.priority = priority
        self.leadMinutes = leadMinutes
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.notificationID = notificationID
    }

    var isOverdue: Bool {
        !isDone && dueDate < Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(dueDate)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(dueDate)
    }

    var secondsLeft: TimeInterval {
        dueDate.timeIntervalSinceNow
    }

    /// 0...1 progress from creation to deadline.
    var progress: Double {
        guard !isDone else { return 1 }
        let total = dueDate.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        let done = Date().timeIntervalSince(createdAt)
        return max(0, min(1, done / total))
    }

    var remindText: String {
        leadMinutes <= 0 ? "准时提醒" : "提前 \(leadMinutes) 分钟"
    }
}

struct IdeaNote: Identifiable, Codable {
    var id: UUID
    var text: String
    var createdAt: Date
    var source: IdeaSource
    var converted: Int

    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), source: IdeaSource = .text, converted: Int = 0) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.source = source
        self.converted = converted
    }
}

struct Anniversary: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var createdAt: Date

    init(id: UUID = UUID(), title: String, date: Date, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.date = date
        self.createdAt = createdAt
    }

    /// 距离今天的天数：正数表示已经过去，负数表示还有多少天。
    var daysFromToday: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: start, to: today).day ?? 0
    }

    var isFuture: Bool { daysFromToday < 0 }

    var dayCount: Int { abs(daysFromToday) }

    var label: String {
        if daysFromToday > 0 { return "已经" }
        if daysFromToday == 0 { return "就是今天" }
        return "还有"
    }

    var progress: Double {
        if isFuture {
            let calendar = Calendar.current
            let from = calendar.startOfDay(for: createdAt)
            let target = calendar.startOfDay(for: date)
            let total = calendar.dateComponents([.day], from: from, to: target).day ?? 1
            guard total > 0 else { return 1 }
            return min(1, max(0, 1 - Double(dayCount) / Double(total)))
        }
        let marks = [7, 30, 50, 100, 200, 365, 500, 730, 1000, 1500, 2000, 3650, 5000]
        let count = dayCount
        let next = marks.first { $0 > count } ?? count + 1
        let previous = marks.last { $0 <= count } ?? 0
        return min(1, max(0, Double(count - previous) / Double(max(1, next - previous))))
    }

    var caption: String {
        if isFuture { return "目标 \(Fmt.yearDate(date))" }
        let marks = [7, 30, 50, 100, 200, 365, 500, 730, 1000, 1500, 2000, 3650, 5000]
        let count = dayCount
        guard let next = marks.first(where: { $0 > count }) else { return "一起很久了" }
        return "距 \(next) 天还有 \(next - count) 天"
    }

    var weekText: String {
        "\(dayCount / 7) 周 \(dayCount % 7) 天"
    }
}

struct AIDraft: Identifiable {
    var id = UUID()
    var title: String
    var note: String = ""
    var tag: String = "生活"
    var dueDate: Date?
    var priority: TaskPriority = .normal
    var leadMinutes: Int = 10

    func makeTask(defaultLead: Int) -> TaskItem {
        TaskItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                 note: note,
                 tag: tag.isEmpty ? "生活" : tag,
                 dueDate: dueDate ?? Date().addingTimeInterval(3600),
                 priority: priority,
                 leadMinutes: dueDate == nil ? 0 : defaultLead)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case tasks
    case capture
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .tasks: return "任务"
        case .capture: return "记录"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .today: return "calendar"
        case .tasks: return "checklist"
        case .capture: return "mic"
        case .settings: return "slider.horizontal.3"
        }
    }
}
