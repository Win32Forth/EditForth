import SwiftUI

@main
struct EditForthApp: App {
    var body: some Scene {
        Window("EditForth", id: "workspace") {
            ContentView()
        }
        .defaultSize(width: 960, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
