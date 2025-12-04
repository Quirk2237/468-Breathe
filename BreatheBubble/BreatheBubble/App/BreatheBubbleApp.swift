import SwiftUI

@main
struct BreatheBubbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we manage windows manually via AppDelegate
        Settings {
            EmptyView()
        }
    }
}

