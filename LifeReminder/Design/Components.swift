import SwiftUI
import UIKit

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String = "sparkles"
    var isLoading: Bool = false
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: {
            guard enabled && !isLoading else { return }
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(Theme.rounded(17, .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(Theme.brand))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
            .shadow(color: Theme.teal.opacity(enabled ? 0.32 : 0), radius: 18, x: 0, y: 10)
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || isLoading)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 7) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(Theme.rounded(15, .semibold))
            }
            .foregroundColor(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(Color.white.opacity(0.55)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
            .shadow(color: Theme.deep.opacity(0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressableStyle())
    }
}

struct GlassIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var tint: Color = Theme.ink
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.6)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                .shadow(color: Theme.deep.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressableStyle())
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.rounded(18, .bold))
                    .foregroundColor(Theme.ink)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.subInk)
                }
            }
            Spacer(minLength: 8)
            if let trailing = trailing {
                Text(trailing)
                    .font(Theme.rounded(13, .semibold))
                    .foregroundColor(Theme.teal)
            }
        }
    }
}

struct StatPill: View {
    let title: String
    let value: String
    var tint: Color = Theme.deep

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.rounded(20, .bold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(Theme.rounded(11, .medium))
                .foregroundColor(Theme.subInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glass(radius: 18, tint: 0.34)
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.soft()
            action()
        }) {
            Text(title)
                .font(Theme.rounded(14, .semibold))
                .foregroundColor(selected ? .white : Theme.subInk)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(Theme.brandBar) : AnyShapeStyle(Color.white.opacity(0.55)))
                )
                .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0.45 : 0.85), lineWidth: 1))
                .shadow(color: selected ? Theme.teal.opacity(0.25) : Color.clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PressableStyle())
    }
}

struct TaskCheck: View {
    let done: Bool
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.success()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(done ? AnyShapeStyle(Theme.brandBar) : AnyShapeStyle(Color.white.opacity(0.75)))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle().strokeBorder(done ? Color.white.opacity(0.5) : Theme.deep.opacity(0.18), lineWidth: 1.4)
                    )
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct PriorityTag: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priority.color)
                .frame(width: 6, height: 6)
            Text(priority.label)
                .font(Theme.rounded(11, .semibold))
                .foregroundColor(priority.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(priority.color.opacity(0.12)))
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.rounded(11, .semibold))
            .foregroundColor(Theme.deep)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.teal.opacity(0.10)))
    }
}

struct WaveformBars: View {
    var level: CGFloat
    var color: Color = .white

    private let factors: [CGFloat] = [0.35, 0.6, 0.95, 0.5, 1.0, 0.55, 0.85, 0.45, 0.3]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<factors.count, id: \.self) { i in
                Capsule()
                    .fill(color.opacity(0.92))
                    .frame(width: 4, height: height(i))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func height(_ index: Int) -> CGFloat {
        let factor = factors[index % factors.count]
        return 6 + max(0.06, min(1, level)) * 32 * factor
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.teal.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.teal)
            }
            Text(title)
                .font(Theme.rounded(17, .bold))
                .foregroundColor(Theme.ink)
            Text(message)
                .font(Theme.rounded(13, .regular))
                .foregroundColor(Theme.subInk)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .glass(radius: 24, tint: 0.3)
    }
}

struct LabeledField: View {
    let title: String
    var placeholder: String
    @Binding var text: String
    var icon: String = "key.fill"
    var secure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Theme.rounded(12, .semibold))
                .foregroundColor(Theme.subInk)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.teal)
                    .frame(width: 18)

                if secure {
                    SecureField(placeholder, text: $text)
                        .font(Theme.rounded(15, .medium))
                        .foregroundColor(Theme.ink)
                        .accentColor(Theme.teal)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } else {
                    TextField(placeholder, text: $text)
                        .font(Theme.rounded(15, .medium))
                        .foregroundColor(Theme.ink)
                        .accentColor(Theme.teal)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.62)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
            )
        }
    }
}
