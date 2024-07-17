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
    var timer: Timer?
    var timeRemaining: Int?
    var isPaused: Bool = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
            button.action = #selector(showMenu)
        }
    }

    @objc func showMenu() {
        if let button = statusItem.button {
            let menu = NSMenu()

            let textFieldItem = NSMenuItem()
            let textField = NSTextField(string: "")
            textField.placeholderString = "Minutes"
            textField.target = self
            textField.action = #selector(startTimer(_:))
            textFieldItem.view = textField

            menu.addItem(textFieldItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Pause Timer", action: #selector(pauseTimer), keyEquivalent: "p"))
            menu.addItem(NSMenuItem(title: "End Timer", action: #selector(endTimer), keyEquivalent: "e"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        }
    }

    @objc func startTimer(_ sender: NSTextField) {
        guard let minutes = Int(sender.stringValue) else { return }
        timeRemaining = minutes * 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateTimer()
            }
        }
        updateButtonTitle()
    }

    func updateTimer() {
        if let timeRemaining = self.timeRemaining, timeRemaining > 0 {
            self.timeRemaining = timeRemaining - 1
            updateButtonTitle()
        } else {
            timer?.invalidate()
            timeRemaining = nil
            updateButtonTitle()
        }
    }

    func updateButtonTitle() {
        if let button = statusItem.button {
            if let timeRemaining = self.timeRemaining {
                button.title = timeString(time: timeRemaining)
            } else {
                button.title = ""
                button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
            }
        }
    }

    @objc func pauseTimer() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.updateTimer()
                }
            }
        }
    }

    @objc func endTimer() {
        timer?.invalidate()
        timeRemaining = nil
        updateButtonTitle()
    }

    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
