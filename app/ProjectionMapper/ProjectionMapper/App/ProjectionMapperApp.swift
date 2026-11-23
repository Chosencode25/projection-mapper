import Darwin
import SwiftUI

struct ProjectionMapperApp: App {
    @NSApplicationDelegateAdaptor(EditorLifecycleCoordinator.self) private var coordinator

    var body: some Scene {
        Settings { EmptyView() }
            .commands { AppCommands(coordinator: coordinator) }
    }
}


@main
enum ProjectionMapperEntry {
    @MainActor
    static func main() {
        if let status = ReleaseUpdateInstaller.runHelper(Array(CommandLine.arguments.dropFirst()), bundle: Bundle.main.bundleURL) {
            exit(status)
        }
        ProjectionMapperApp.main()
    }
}
