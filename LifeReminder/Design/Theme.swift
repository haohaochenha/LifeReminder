import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// 跟随系统（或 App 内强制）深浅色自动切换的颜色。
    static func dynamic(light: UInt32,
                        dark: UInt32,
                        lightAlpha: CGFloat = 1,
                        darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

enum Theme {
    // 背景与文字
    static let bg = Color.dynamic(light: 0xF2F2F7, dark: 0x000000)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let label = Color.dynamic(light: 0x000000, dark: 0xFFFFFF)
    static let label2 = Color.dynamic(light: 0x3C3C43, dark: 0xEBEBF5, lightAlpha: 0.6, darkAlpha: 0.6)
    static let label3 = Color.dynamic(light: 0x3C3C43, dark: 0xEBEBF5, lightAlpha: 0.3, darkAlpha: 0.3)
    static let separator = Color.dynamic(light: 0x3C3C43, dark: 0x545458, lightAlpha: 0.13, darkAlpha: 0.55)
    static let fill = Color.dynamic(light: 0x787880, dark: 0x787880, lightAlpha: 0.12, darkAlpha: 0.24)
    static let fill2 = Color.dynamic(light: 0x787880, dark: 0x787880, lightAlpha: 0.18, darkAlpha: 0.32)
    static let segment = Color.dynamic(light: 0xFFFFFF, dark: 0x636366)

    // 玻璃
    /// 毛玻璃卡片填充，对应 HTML 的 --gcard
    static let glass = Color(UIColor { trait in
        UIColor.white.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.075 : 0.52)
    })
    /// 底部 tab bar / 浮动按钮的玻璃，对应 HTML 的 --glass
    static let tabGlass = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: 0x2C2C2E, alpha: 0.6)
            : UIColor.white.withAlphaComponent(0.62)
    })
    static let glassBorder = Color(UIColor { trait in
        UIColor.white.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.14 : 0.75)
    })
    /// 顶部内高光，对应 --gshadow 的 inset 0 1px 0
    static let glassHighlight = Color(UIColor { trait in
        UIColor.white.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.16 : 0.95)
    })
    static let navBg = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: 0x000000, alpha: 0.7)
            : UIColor(hex: 0xF2F2F7, alpha: 0.72)
    })
    static let shadow = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.7)
            : UIColor(hex: 0x28468C, alpha: 0.25)
    })

    // 强调色
    static let blue = Color(hex: 0x0088FF)
    static let red = Color(hex: 0xFF383C)
    static let orange = Color(hex: 0xFF8D28)
    static let green = Color(hex: 0x34C759)
    static let indigo = Color(hex: 0x6155F5)
    static let gray = Color(hex: 0x8E8E93)
    static let pink = Color(hex: 0xFF375F)

    // 背景光斑
    static let k1 = Color(hex: 0x0088FF, alpha: 0.34)
    static let k2 = Color(hex: 0x6155F5, alpha: 0.28)
    static let k3 = Color(hex: 0xFF8D28, alpha: 0.26)
    static let k4 = Color(hex: 0x00C8E6, alpha: 0.28)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func num(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

enum Fmt {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    private static let fullFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static func monthDay(_ date: Date) -> String { monthDayFormatter.string(from: date) }

    static func full(_ date: Date) -> String { fullFormatter.string(from: date) }

    static func yearDate(_ date: Date) -> String { yearFormatter.string(from: date) }

    static func weekday(_ date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date) - 1
        return weekdays[max(0, min(6, index))]
    }

    static func dateLine(_ date: Date) -> String {
        "\(monthDay(date)) · 周\(weekday(date))"
    }

    static func greeting(_ date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<6: return "夜深了"
        case 6..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
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
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        return "\(max(1, minutes)) 分钟"
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func countdown(_ interval: TimeInterval) -> (hours: Int, minutes: Int, seconds: Int) {
        let total = max(0, Int(interval))
        return (total / 3600, (total % 3600) / 60, total % 60)
    }
}

enum Haptics {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct AuroraBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.bg

            // 光斑先离屏合成成一层，再整体做很慢的位移/缩放，
            // 避免每帧重算 4 个大 blur 造成滚动卡顿。
            GeometryReader { geo in
                ZStack {
                    blob(Theme.k1, size: 300)
                        .position(x: 50, y: 80)
                    blob(Theme.k2, size: 280)
                        .position(x: geo.size.width - 20, y: 390)
                    blob(Theme.k3, size: 300)
                        .position(x: 60, y: 670)
                    blob(Theme.k4, size: 260)
                        .position(x: geo.size.width - 50, y: geo.size.height - 70)
                }
                .drawingGroup()
                .scaleEffect(drift ? 1.04 : 1)
                .offset(x: drift ? 8 : -8, y: drift ? 10 : -10)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 19).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 64)
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 24
    var shadow: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            // 先模糊背板、再盖一层半透明白膜，和 HTML 的 backdrop-filter + --gcard 一致
            .background(
                ZStack {
                    shape.fill(Material.ultraThinMaterial)
                    shape.fill(Theme.glass)
                }
            )
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.glassBorder, lineWidth: 0.5))
            .overlay(
                shape.strokeBorder(
                    LinearGradient(stops: [
                        Gradient.Stop(color: Theme.glassHighlight, location: 0),
                        Gradient.Stop(color: Theme.glassHighlight.opacity(0.35), location: 0.3),
                        Gradient.Stop(color: Color.clear, location: 0.62)
                    ], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
            )
            .shadow(color: shadow ? Theme.shadow : .clear, radius: 18, x: 0, y: 10)
    }
}

extension View {
    func glassCard(radius: CGFloat = 24, shadow: Bool = true) -> some View {
        modifier(GlassCard(radius: radius, shadow: shadow))
    }

    /// 弹层里的分组卡：实色、无模糊、无边框、无阴影（对应 HTML 的 .sheet .group）
    func solidCard(radius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(Theme.card))
            .clipShape(shape)
    }
}

struct TopRoundedShape: Shape {
    var radius: CGFloat = 38

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
