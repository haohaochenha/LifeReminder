import SwiftUI
import UIKit

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

enum AnniversaryRepeat: String, Codable, CaseIterable, Identifiable {
    case none
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "仅记录"
        case .weekly: return "每周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        }
    }
}

struct Anniversary: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var createdAt: Date
    /// 封面图文件名（存在 Application Support/LifeReminder/images）
    var imageFile: String?
    /// 每年 / 每月 / 每周 重复，用于计算下一次和提醒
    var repeatMode: AnniversaryRepeat
    var remind: Bool

    init(id: UUID = UUID(),
         title: String,
         date: Date,
         createdAt: Date = Date(),
         imageFile: String? = nil,
         repeatMode: AnniversaryRepeat = .none,
         remind: Bool = true) {
        self.id = id
        self.title = title
        self.date = date
        self.createdAt = createdAt
        self.imageFile = imageFile
        self.repeatMode = repeatMode
        self.remind = remind
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, createdAt, imageFile, repeatMode, remind
    }

    /// 兼容旧版本数据：新字段缺失时给默认值。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        imageFile = try container.decodeIfPresent(String.self, forKey: .imageFile)
        repeatMode = try container.decodeIfPresent(AnniversaryRepeat.self, forKey: .repeatMode) ?? .none
        remind = try container.decodeIfPresent(Bool.self, forKey: .remind) ?? true
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

    // MARK: - 重复纪念日

    var isRepeating: Bool { repeatMode != .none }

    /// 下一次发生的日期（含今天）。
    var nextDate: Date? {
        guard repeatMode != .none else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: date)

        switch repeatMode {
        case .none:
            return nil

        case .yearly:
            let parts = calendar.dateComponents([.month, .day], from: start)
            func make(_ year: Int) -> Date? {
                var comps = DateComponents()
                comps.year = year
                comps.month = parts.month
                comps.day = parts.day
                if let value = calendar.date(from: comps) { return value }
                comps.day = 28
                return calendar.date(from: comps)
            }
            let year = calendar.component(.year, from: today)
            var candidate = make(year) ?? today
            if candidate < today, let next = make(year + 1) {
                candidate = next
            }
            return candidate

        case .monthly:
            let day = calendar.component(.day, from: start)
            func make(_ base: Date) -> Date {
                let range = calendar.range(of: .day, in: .month, for: base) ?? 1..<29
                var comps = calendar.dateComponents([.year, .month], from: base)
                comps.day = min(day, range.upperBound - 1)
                return calendar.date(from: comps) ?? base
            }
            var month = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            var candidate = make(month)
            if candidate < today {
                month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                candidate = make(month)
            }
            return candidate

        case .weekly:
            let diff = calendar.dateComponents([.day], from: start, to: today).day ?? 0
            let remainder = ((diff % 7) + 7) % 7
            let add = remainder == 0 ? 0 : 7 - remainder
            return calendar.date(byAdding: .day, value: add, to: today) ?? today
        }
    }

    var daysToNext: Int? {
        guard let next = nextDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: Date()),
                                       to: calendar.startOfDay(for: next)).day
    }

    /// 下一次是第几个周年 / 第几个月 / 第几周。
    var occurrenceNumber: Int {
        guard let next = nextDate else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        switch repeatMode {
        case .yearly:
            return calendar.dateComponents([.year], from: start, to: next).year ?? 0
        case .monthly:
            return calendar.dateComponents([.month], from: start, to: next).month ?? 0
        case .weekly:
            return (calendar.dateComponents([.day], from: start, to: next).day ?? 0) / 7
        case .none:
            return 0
        }
    }

    // MARK: - 卡片展示用

    var displayCount: Int {
        if isRepeating, let value = daysToNext { return max(0, value) }
        return dayCount
    }

    var displayLabel: String {
        guard isRepeating else { return label }
        return displayCount == 0 ? "就是今天" : "还有"
    }

    var displayCaption: String {
        guard isRepeating, let next = nextDate else { return caption }
        let extra: String
        switch repeatMode {
        case .yearly:
            extra = occurrenceNumber > 0 ? "\(occurrenceNumber) 周年" : "每年"
        case .monthly:
            extra = occurrenceNumber > 0 ? "第 \(occurrenceNumber) 个月" : "每月"
        case .weekly:
            extra = occurrenceNumber > 0 ? "第 \(occurrenceNumber) 周" : "每周"
        case .none:
            extra = ""
        }
        return "下次 \(Fmt.monthDay(next)) · \(extra)"
    }

    var displayProgress: Double {
        guard isRepeating, let next = nextDate else { return progress }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previous: Date
        switch repeatMode {
        case .yearly:
            previous = calendar.date(byAdding: .year, value: -1, to: next) ?? next
        case .monthly:
            previous = calendar.date(byAdding: .month, value: -1, to: next) ?? next
        case .weekly:
            previous = calendar.date(byAdding: .day, value: -7, to: next) ?? next
        case .none:
            previous = next
        }
        let total = next.timeIntervalSince(previous)
        guard total > 0 else { return 1 }
        return min(1, max(0, today.timeIntervalSince(previous) / total))
    }

    /// 卡片背面显示的下次日期
    var nextText: String {
        guard let next = nextDate else { return "—" }
        return Fmt.yearDate(next)
    }

    var notificationBody: String {
        switch repeatMode {
        case .yearly:
            return "「\(title)」已经 \(occurrenceNumber) 周年啦"
        case .monthly:
            return "「\(title)」第 \(occurrenceNumber) 个月"
        case .weekly:
            return "「\(title)」第 \(occurrenceNumber) 周"
        case .none:
            return "今天是「\(title)」"
        }
    }

    /// 从名字里猜重复方式，例如「结婚纪念日」→ 每年。
    static func detectRepeat(for title: String) -> AnniversaryRepeat {
        let text = title
        let monthly = ["每月", "月度", "房租", "工资", "还款", "账单", "订阅", "会员", "信用卡"]
        let weekly = ["每周", "周会", "例会", "周记", "健身", "复盘"]
        let yearly = ["周年", "生日", "结婚", "纪念", "在一起", "毕业", "出生", "春节", "新年",
                      "元旦", "中秋", "端午", "情人节", "圣诞", "七夕"]
        if monthly.contains(where: { text.contains($0) }) { return .monthly }
        if weekly.contains(where: { text.contains($0) }) { return .weekly }
        if yearly.contains(where: { text.contains($0) }) { return .yearly }
        return .none
    }
}

/// 纪念日封面图的本地存取（压缩后存文件，避免把 base64 塞进 data.json）。
enum AnniversaryImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("LifeReminder/images", isDirectory: true)
    }

    static func save(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 900
        let side = max(image.size.width, image.size.height)
        let scale = side > maxSide ? maxSide / side : 1
        let target = CGSize(width: max(1, image.size.width * scale),
                            height: max(1, image.size.height * scale))
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            let name = UUID().uuidString + ".jpg"
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name = name, !name.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    static func delete(_ name: String?) {
        guard let name = name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
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
