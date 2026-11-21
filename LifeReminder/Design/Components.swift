import SwiftUI
import Combine
import UIKit

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct IconTile: View {
    let color: Color
    let icon: String
    var size: CGFloat = 30
    var circle: Bool = false

    var body: some View {
        ZStack {
            Group {
                if circle {
                    Circle().fill(color)
                } else {
                    RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(color)
                }
            }
            Image(systemName: icon)
                .font(.system(size: size * (circle ? 0.5 : 0.55), weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

struct GroupCard<Content: View>: View {
    var radius: CGFloat = 24
    var solid: Bool = false
    let content: Content

    init(radius: CGFloat = 24, solid: Bool = false, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.solid = solid
        self.content = content()
    }

    var body: some View {
        if solid {
            VStack(spacing: 0) { content }
                .solidCard(radius: radius)
        } else {
            VStack(spacing: 0) { content }
                .glassCard(radius: radius)
        }
    }
}

struct CellDivider: View {
    var inset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

struct FormCell<Content: View>: View {
    var icon: String? = nil
    var iconColor: Color = Theme.blue
    var title: String? = nil
    var minHeight: CGFloat = 54
    let content: Content

    init(icon: String? = nil,
         iconColor: Color = Theme.blue,
         title: String? = nil,
         minHeight: CGFloat = 54,
         @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                IconTile(color: iconColor, icon: icon)
            }
            if let title = title {
                Text(title)
                    .font(Theme.font(17))
                    .foregroundColor(Theme.label)
                    .frame(width: 96, alignment: .leading)
            }
            content
        }
        .padding(.horizontal, 16)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    var title: String
    var trailing: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.font(22, .bold))
                .foregroundColor(Theme.label)
            Spacer(minLength: 8)
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    Haptics.tap()
                    action()
                }) {
                    Text(actionTitle)
                        .font(Theme.font(15, .medium))
                        .foregroundColor(Theme.blue)
                }
                .buttonStyle(.plain)
            } else if let trailing = trailing {
                Text(trailing)
                    .font(Theme.font(15))
                    .foregroundColor(Theme.label2)
            }
        }
    }
}

struct SegmentedControl: View {
    let items: [String]
    @Binding var selection: Int
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button(action: {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selection = index
                    }
                }) {
                    Text(items[index])
                        .font(Theme.font(14, selection == index ? .semibold : .regular))
                        .foregroundColor(selection == index ? Theme.label : Theme.label2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if selection == index {
                                Capsule()
                                    .fill(Theme.segment)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.fill))
    }
}

struct RingProgress: View {
    var progress: Double

    var body: some View {
        let value = min(1, max(0, progress))
        ZStack {
            GeometryReader { _ in
                ZStack {
                    Circle()
                        .stroke(Theme.fill, lineWidth: 10)
                        .padding(10)
                    Circle()
                        .stroke(Theme.label3, style: StrokeStyle(lineWidth: 1.4, dash: [1, 8.1]))
                        .padding(1)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0.001, value)))
                        .stroke(
                            LinearGradient(colors: [Color(hex: 0x5AC8FA), Theme.indigo],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .padding(10)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.1), value: value)
                }
            }

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int((value * 100).rounded()))")
                        .font(Theme.num(36))
                        .foregroundColor(Theme.label)
                    Text("%")
                        .font(Theme.font(15, .semibold))
                        .foregroundColor(Theme.label2)
                }
                Text("已临近")
                    .font(Theme.font(11, .medium))
                    .foregroundColor(Theme.label2)
            }
        }
        .frame(width: 120, height: 120)
    }
}

struct TaskCheck: View {
    let done: Bool
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .strokeBorder(done ? Color.clear : color, lineWidth: 1.5)
                if done {
                    Circle().fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 26, height: 26)
            .scaleEffect(done ? 1.06 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                IconTile(color: tint, icon: icon, size: 34, circle: true)
                Text(value)
                    .font(Theme.num(30))
                    .foregroundColor(Theme.label)
                Text(label)
                    .font(Theme.font(15, .semibold))
                    .foregroundColor(Theme.label2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassCard(radius: 22)
        }
        .buttonStyle(PressableStyle())
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: {
            guard enabled && !isLoading else { return }
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(Theme.font(17, .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(Theme.blue))
            .shadow(color: Theme.blue.opacity(enabled ? 0.35 : 0), radius: 12, x: 0, y: 8)
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(Theme.font(17, .semibold))
            }
            .foregroundColor(Theme.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(Theme.fill))
        }
        .buttonStyle(PressableStyle())
    }
}

struct MiniPillButton: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: {
            guard enabled else { return }
            Haptics.tap()
            action()
        }) {
            Text(title)
                .font(Theme.font(14, .semibold))
                .foregroundColor(Theme.blue)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(Theme.fill))
                .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct GlassCircleButton: View {
    let icon: String
    var size: CGFloat = 44
    var tint: Color = Theme.blue
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Circle().fill(Material.ultraThinMaterial)
                        Circle().fill(Theme.tabGlass)
                    }
                )
                .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 0.5))
                .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle())
    }
}

struct WaveformView: View {
    var isRecording: Bool

    var body: some View {
        Group {
            if isRecording {
                TimelineView(.animation) { context in
                    bars(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                bars(time: 0)
            }
        }
        .frame(height: 44)
        .animation(.easeOut(duration: 0.2), value: isRecording)
    }

    private func bars(time: TimeInterval) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<40, id: \.self) { index in
                Capsule()
                    .fill(isRecording ? Theme.red : Theme.label3)
                    .frame(width: 3, height: height(index: index, time: time))
            }
        }
    }

    private func height(index: Int, time: TimeInterval) -> CGFloat {
        guard isRecording else { return 4 }
        let center = 1 - abs(Double(index) - 19.5) / 20
        let wave = abs(sin(time * 6 + Double(index) * 0.6))
        return 4 + CGFloat(wave * 38 * center) + 2
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundColor(Theme.label3)
            Text(message)
                .font(Theme.font(15))
                .foregroundColor(Theme.label2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

struct ToastBanner: View {
    let text: String
    var ok: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? Theme.blue : Theme.red)
                .frame(width: 8, height: 8)
            Text(text)
                .font(Theme.font(15, .semibold))
                .foregroundColor(Theme.label)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            ZStack {
                Capsule().fill(Material.ultraThinMaterial)
                Capsule().fill(Theme.tabGlass)
            }
        )
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 0.5))
        .shadow(color: Theme.shadow, radius: 16, x: 0, y: 8)
    }
}

struct GFCaption: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Theme.font(13))
            .foregroundColor(Theme.label2)
            .lineSpacing(3)
    }
}

// MARK: - 滚动联动（顶栏毛玻璃渐显 + tab bar 自动收起）

/// 对应 HTML 里的 lastY / --p 逻辑，独立成 ObservableObject，
/// 让滚动时不触发 RootView 整体重绘。
final class ScrollChrome: ObservableObject {
    static let spaceName = "life-scroll"

    /// 当前滚动距离（内容顶部离开视口顶部的距离）
    @Published private(set) var y: CGFloat = 0
    /// tab bar 是否收起（矮、缩、隐藏文字）
    @Published private(set) var mini: Bool = false

    private var lastY: CGFloat = 0

    /// 顶栏不透明度：clamp((y - 24) / 28)
    var topBarOpacity: Double {
        Double(min(1, max(0, (y - 24) / 28)))
    }

    func update(_ value: CGFloat) {
        guard abs(value - y) > 0.4 else { return }
        y = value

        let delta = value - lastY
        if abs(delta) > 8 {
            let next = delta > 0 && value > 70
            if next != mini {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    mini = next
                }
            }
            lastY = value
        }
    }

    func reset() {
        y = 0
        lastY = 0
        if mini {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                mini = false
            }
        }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 放进每个页面 ScrollView 内容的最内层 VStack 背景里。
/// 用全局坐标 + 首次出现时的基准值，避免命名坐标空间在部分系统版本上取不到值。
struct ScrollTracker: View {
    @State private var base: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let y = geo.frame(in: .global).minY
            Color.clear
                .onAppear {
                    if base == nil { base = y }
                }
                .preference(
                    key: ScrollOffsetKey.self,
                    value: max(0, (base ?? y) - y)
                )
        }
    }
}

/// 监听键盘高度：用于显示「收起键盘」按钮，并避免 tab bar 被键盘顶飞。
final class KeyboardObserver: ObservableObject {
    @Published private(set) var height: CGFloat = 0

    private var tokens: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                         object: nil,
                                         queue: .main) { [weak self] note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self?.height = frame.height
            }
        })
        tokens.append(center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                         object: nil,
                                         queue: .main) { [weak self] _ in
            withAnimation(.easeOut(duration: 0.25)) {
                self?.height = 0
            }
        })
    }

    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
