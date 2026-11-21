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
        case .low: return Theme.faint
        case .normal: return Theme.teal
        case .high: return Theme.coral
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
        case .today: return "今日"
        case .tasks: return "任务"
        case .capture: return "记录"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .tasks: return "checklist"
        case .capture: return "mic.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
