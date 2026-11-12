// アプリの入口

import SwiftUI

@main
struct NyansoroApp: App {
    @StateObject private var model = AppModel()

    init() {
        AppFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
