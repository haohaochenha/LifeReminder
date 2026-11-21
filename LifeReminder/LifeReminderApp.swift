import SwiftUI
import UIKit

@main
struct LifeReminderApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var settings = SettingsStore()

    init() {
        // 让 TextEditor 在玻璃卡片上保持透明（iOS 15 没有 scrollContentBackground）。
        UITextView.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        }
    }
}
