import SwiftUI
import AppKit

// MARK: - App Entry Point
@main
struct DeskFitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we manage windows manually via AppDelegate
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = WindowManager()
        windowManager?.showFloatingBubble()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
