import SwiftUI

private enum SheetRoute: Identifiable {
    case newTask
    case editTask(TaskItem)
    case newAnniversary

    var id: String {
        switch self {
        case .newTask: return "new-task"
        case .editTask(let task): return "edit-\(task.id.uuidString)"
        case .newAnniversary: return "new-anniversary"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: AppTab = .today
    @State private var taskFilter: Int = 0
    @State private var sheet: SheetRoute?
    @State private var toastText: String?
    @State private var toastOK: Bool = true
    @State private var chrome = ScrollChrome()

    var body: some View {
        ZStack {
            AuroraBackground()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            topBarLayer
            tabBarLayer
            sheetLayer
            toastLayer
        }
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            chrome.update(value)
        }
        .preferredColorScheme(settings.colorScheme)
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
        .onChange(of: settings.hapticEnabled) { enabled in
            Haptics.enabled = enabled
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                store.syncNotifications(enabled: settings.notifyEnabled)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .today:
            TodayView(openCapture: { select(.capture) },
                      openTasks: { index in
                          taskFilter = index
                          select(.tasks)
                      },
                      addTask: { sheet = .newTask },
                      editTask: { sheet = .editTask($0) },
                      addAnniversary: { sheet = .newAnniversary },
                      toast: showToast)
        case .tasks:
            TasksView(filterIndex: $taskFilter,
                      addTask: { sheet = .newTask },
                      editTask: { sheet = .editTask($0) },
                      toast: showToast)
        case .capture:
            CaptureView(openSettings: { select(.settings) }, toast: showToast)
        case .settings:
            SettingsView(toast: showToast)
        }
    }

    private var navTitle: String {
        switch tab {
        case .today: return "今天"
        case .tasks: return "任务"
        case .capture: return "记录"
        case .settings: return "设置"
        }
    }

    private var showsPlus: Bool {
        tab == .today || tab == .tasks
    }

    // MARK: - Top bar

    private var topBarLayer: some View {
        VStack(spacing: 0) {
            TopBarView(chrome: chrome,
                       title: navTitle,
                       showsPlus: showsPlus,
                       onPlus: { sheet = .newTask })
            Spacer(minLength: 0)
        }
        .zIndex(6)
    }

    // MARK: - Tab bar

    private var tabBarLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            TabBarView(chrome: chrome,
                       tab: tab,
                       onSelect: { select($0) })
        }
        .zIndex(5)
    }

    // MARK: - Sheet

    @ViewBuilder
    private var sheetLayer: some View {
        if let route = sheet {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { closeSheet() }
                    .transition(.opacity)

                sheetContent(route)
                    .frame(maxWidth: .infinity)
                    .background(Theme.bg)
                    .clipShape(TopRoundedShape(radius: 38))
                    .shadow(color: Color.black.opacity(0.22), radius: 30, x: 0, y: -8)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom))
            }
            .zIndex(10)
        }
    }

    @ViewBuilder
    private func sheetContent(_ route: SheetRoute) -> some View {
        switch route {
        case .newTask:
            TaskEditorView(task: nil,
                           onSave: { task in
                               store.add(task)
                               closeSheet()
                               showToast("已添加到提醒")
                           },
                           onDelete: nil,
                           onClose: closeSheet)
        case .editTask(let task):
            TaskEditorView(task: task,
                           onSave: { updated in
                               store.update(updated)
                               closeSheet()
                               showToast("已保存")
                           },
                           onDelete: { target in
                               store.delete(target)
                               closeSheet()
                               showToast("已删除")
                           },
                           onClose: closeSheet)
        case .newAnniversary:
            AnniversarySheet { item in
                store.addAnniversary(item)
                closeSheet()
                showToast("纪念日已添加")
            } onClose: {
                closeSheet()
            }
        }
    }

    private func closeSheet() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            sheet = nil
        }
    }

    // MARK: - Toast

    private var toastLayer: some View {
        VStack {
            if let text = toastText {
                ToastBanner(text: text, ok: toastOK)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .zIndex(20)
    }

    private func showToast(_ text: String, ok: Bool = true) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            toastText = text
            toastOK = ok
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeOut(duration: 0.25)) {
                toastText = nil
            }
        }
    }

    // MARK: - Lifecycle

    private func select(_ newTab: AppTab) {
        guard tab != newTab else { return }
        Haptics.tap()
        chrome.reset()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            tab = newTab
        }
    }

    private func bootstrap() {
        Haptics.enabled = settings.hapticEnabled
        if settings.notifyEnabled {
            NotificationManager.shared.requestAuthorization { _ in
                store.syncNotifications(enabled: settings.notifyEnabled)
            }
        } else {
            store.syncNotifications(enabled: false)
        }
    }
}

// MARK: - 顶栏（对应 HTML .topbar）

private struct TopBarView: View {
    @ObservedObject var chrome: ScrollChrome
    let title: String
    let showsPlus: Bool
    let onPlus: () -> Void

    var body: some View {
        let p = chrome.topBarOpacity
        ZStack(alignment: .bottom) {
            ZStack {
                Rectangle().fill(Material.ultraThinMaterial)
                Rectangle().fill(Theme.navBg)
            }
            .opacity(p)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5)
                .opacity(p)
                .allowsHitTesting(false)

            Text(title)
                .font(Theme.font(17, .semibold))
                .foregroundColor(Theme.label)
                .opacity(p)
                .padding(.bottom, 12)
                .allowsHitTesting(false)

            HStack {
                Spacer(minLength: 0)
                if showsPlus {
                    GlassCircleButton(icon: "plus", size: 44, action: onPlus)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 2)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showsPlus)
        }
        .frame(height: 48)
    }
}

// MARK: - 底部 tab bar（对应 HTML .tabbar / .mini）

private struct TabBarView: View {
    @ObservedObject var chrome: ScrollChrome
    let tab: AppTab
    let onSelect: (AppTab) -> Void

    @Namespace private var ns

    var body: some View {
        let mini = chrome.mini
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button(action: { onSelect(item) }) {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon)
                            .font(.system(size: 24, weight: .regular))
                        Text(item.title)
                            .font(Theme.font(10.5, .semibold))
                            .frame(height: mini ? 0 : 14)
                            .clipped()
                            .opacity(mini ? 0 : 1)
                    }
                    .foregroundColor(tab == item ? Theme.blue : Theme.label)
                    .frame(maxWidth: .infinity)
                    .frame(height: mini ? 44 : 56)
                    .background {
                        if tab == item {
                            Capsule()
                                .fill(Theme.fill2)
                                .matchedGeometryEffect(id: "tabPill", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            ZStack {
                Capsule().fill(Material.ultraThinMaterial)
                Capsule().fill(Theme.tabGlass)
            }
        )
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 0.5))
        .shadow(color: Theme.shadow, radius: 18, x: 0, y: 10)
        .padding(.horizontal, 21)
        .padding(.bottom, 14)
        .scaleEffect(mini ? 0.94 : 1, anchor: .bottom)
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: mini)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tab)
    }
}
