import SwiftUI

@main
struct ProjectionMapperApp: App {
    @NSApplicationDelegateAdaptor(EditorLifecycleCoordinator.self) private var coordinator

    var body: some Scene {
        Settings { EmptyView() }
            .commands { AppCommands(coordinator: coordinator) }
    }
}
