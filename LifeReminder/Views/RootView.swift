import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: AppTab = .today

    var body: some View {
        ZStack {
            AuroraBackground()

            Group {
                switch tab {
                case .today:
                    TodayView(openCapture: { select(.capture) })
                case .tasks:
                    TasksView()
                case .capture:
                    CaptureView(openSettings: { select(.settings) })
                case .settings:
                    SettingsView()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .safeAreaInset(edge: .bottom) {
            tabBar
        }
        .onAppear(perform: bootstrap)
        .onChange(of: store.tasks) { _ in
            store.syncNotifications(enabled: settings.notifyEnabled)
        }
        .onChange(of: settings.notifyEnabled) { enabled in
            store.syncNotifications(enabled: enabled)
            if enabled {
                NotificationManager.shared.requestAuthorization { granted in
                    if granted { store.syncNotifications(enabled: true) }
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                store.syncNotifications(enabled: settings.notifyEnabled)
            }
        }
    }

    private func select(_ newTab: AppTab) {
        guard tab != newTab else { return }
        Haptics.soft()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            tab = newTab
        }
    }

    private func bootstrap() {
        if settings.notifyEnabled {
            NotificationManager.shared.requestAuthorization { _ in
                store.syncNotifications(enabled: settings.notifyEnabled)
            }
        } else {
            store.syncNotifications(enabled: false)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { item in
                Button(action: { select(item) }) {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                        if tab == item {
                            Text(item.title)
                                .font(Theme.rounded(14, .bold))
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .foregroundColor(tab == item ? .white : Theme.subInk)
                    .padding(.horizontal, tab == item ? 14 : 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        Capsule().fill(tab == item ? AnyShapeStyle(Theme.brandBar) : AnyShapeStyle(Color.clear))
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(6)
        .background(Capsule().fill(Color.white.opacity(0.5)))
        .background(Capsule().fill(Material.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: Theme.deep.opacity(0.16), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: tab)
    }
}
