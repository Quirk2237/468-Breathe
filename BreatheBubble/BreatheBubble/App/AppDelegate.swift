import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the window manager which handles all our floating windows
        windowManager = WindowManager()
        windowManager?.showFloatingBubble()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even if all windows are closed
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

