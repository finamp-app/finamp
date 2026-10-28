import SwiftUI

@main
struct FinampWatchApp: App {
    init() {
        PhoneConnection.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
