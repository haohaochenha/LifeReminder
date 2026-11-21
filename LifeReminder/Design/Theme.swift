import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Theme {
    static let teal = Color(hex: 0x0EA5A0)
    static let deep = Color(hex: 0x0F766E)
    static let mint = Color(hex: 0x5EEAD4)
    static let sky = Color(hex: 0x38BDF8)
    static let blue = Color(hex: 0x3B82F6)
    static let amber = Color(hex: 0xF59E0B)
    static let coral = Color(hex: 0xF87171)
    static let ink = Color(hex: 0x0E2A2C)
    static let subInk = Color(hex: 0x5C7376)
    static let faint = Color(hex: 0x8FA3A5)

    static var brand: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x0F766E), Color(hex: 0x0EA5A0), Color(hex: 0x38BDF8)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var brandBar: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x14B8A6), Color(hex: 0x38BDF8)],
                       startPoint: .leading,
                       endPoint: .trailing)
    }

    static var warm: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var cardStroke: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.35)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

enum Fmt {
    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let fullFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    static let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    static func monthDay(_ date: Date) -> String { monthDayFormatter.string(from: date) }

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static func full(_ date: Date) -> String { fullFormatter.string(from: date) }

    static func weekday(_ date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date) - 1
        return weekdays[max(0, min(6, index))]
    }

    static func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInTomorrow(date) { return "明天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        return monthDay(date)
    }

    static func due(_ date: Date) -> String {
        "\(relativeDay(date)) \(time(date))"
    }

    static func remaining(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        if total <= 0 { return "已到时间" }
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        if minutes > 0 { return "\(minutes) 分 \(seconds) 秒" }
        return "\(seconds) 秒"
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF2FBF9),
                                    Color(hex: 0xF0F7FF),
                                    Color(hex: 0xFFF9F2)],
                           startPoint: .top,
                           endPoint: .bottom)

            Circle()
                .fill(Theme.mint.opacity(0.40))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -160, y: -320)

            Circle()
                .fill(Theme.sky.opacity(0.26))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: 180, y: -170)

            Circle()
                .fill(Theme.amber.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: -140, y: 330)
        }
        .ignoresSafeArea()
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 26
    var tint: Double = 0.42

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(shape.fill(Color.white.opacity(tint)))
            .background(shape.fill(Material.ultraThinMaterial))
            .overlay(shape.strokeBorder(Theme.cardStroke, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: Theme.deep.opacity(0.13), radius: 22, x: 0, y: 12)
    }
}

extension View {
    func glass(radius: CGFloat = 26, tint: Double = 0.42) -> some View {
        modifier(GlassSurface(radius: radius, tint: tint))
    }
}
