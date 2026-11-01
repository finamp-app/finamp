import SwiftUI

@main
struct FinampWatchApp: App {
    init() {
        PhoneConnection.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Text follows Text Size up to two steps above Large; larger sizes cut most titles short
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
    }
}
