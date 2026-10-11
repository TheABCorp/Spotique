import SwiftUI
import SwiftData

@main
struct SpotiqueApp: App {
    @State private var environment = AppEnvironment.live()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(router)
                .modelContainer(ModelContainerFactory.shared)
                .task {
                    await environment.sessionStore.restore()
                }
        }
    }
}
