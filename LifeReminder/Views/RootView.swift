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

    @Namespace private var tabNamespace

    var body: some View {
        ZStack {
            AuroraBackground()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            plusButtonLayer
            tabBarLayer
            sheetLayer
            toastLayer
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

    // MARK: - Tab bar

    private var tabBarLayer: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { item in
                    Button(action: { select(item) }) {
                        VStack(spacing: 3) {
                            Image(systemName: item.icon)
                                .font(.system(size: 19, weight: .regular))
                            Text(item.title)
                                .font(Theme.font(10.5, tab == item ? .semibold : .regular))
                        }
                        .foregroundColor(tab == item ? Theme.blue : Theme.label2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            if tab == item {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.fill)
                                    .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.glass))
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Material.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.glassBorder, lineWidth: 0.5))
            .shadow(color: Theme.shadow, radius: 18, x: 0, y: 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: tab)
        .zIndex(5)
    }

    // MARK: - Floating plus

    private var plusButtonLayer: some View {
        VStack {
            HStack {
                Spacer()
                if tab == .today || tab == .tasks {
                    GlassCircleButton(icon: "plus", size: 44) {
                        sheet = .newTask
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.trailing, 18)
            .padding(.top, 6)
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: tab)
        .zIndex(4)
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
                    .padding(.top, 8)
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
