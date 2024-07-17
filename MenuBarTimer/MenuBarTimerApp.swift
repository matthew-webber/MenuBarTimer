import SwiftUI

@main
struct MenuBarTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timerView: TimerView!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
            button.action = #selector(showMenu)
        }

        timerView = TimerView()
        constructMenu()
    }

    @objc func showMenu() {
        if let button = statusItem.button {
            let menu = NSMenu()

            let timerViewItem = NSHostingView(rootView: timerView)
            timerViewItem.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
            let customMenuItem = NSMenuItem()
            customMenuItem.view = timerViewItem

            menu.addItem(customMenuItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Pause Timer", action: #selector(pauseTimer), keyEquivalent: "p"))
            menu.addItem(NSMenuItem(title: "End Timer", action: #selector(endTimer), keyEquivalent: "e"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        }
    }

    func constructMenu() {
        // This method remains empty since we create the menu dynamically in showMenu()
    }

    @objc func pauseTimer() {
        timerView.pauseTimer()
    }

    @objc func endTimer() {
        timerView.endTimer()
    }
}
