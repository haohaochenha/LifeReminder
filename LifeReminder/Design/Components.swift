import SwiftUI

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
    let content: Content

    init(radius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .glassCard(radius: radius)
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
                    .frame(width: 76, alignment: .leading)
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
                .background(Circle().fill(Theme.glass))
                .background(Circle().fill(Material.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 0.5))
                .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
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
        .background(Capsule().fill(Theme.glass))
        .background(Capsule().fill(Material.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 0.5))
        .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
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
