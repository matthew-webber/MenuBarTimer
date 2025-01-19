import SwiftUI
import UserNotifications

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
    var initialTime: Int?
    var shouldClearZeroTimer: Bool = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
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
            textField.frame = NSRect(x: 0, y: 0, width: 100, height: 30)
            if let initialTime = initialTime {
                textField.stringValue = "\(initialTime / 60)"
            }
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
        guard let input = Double(sender.stringValue) else { return } // Accept fractional input
        let minutesPart = Int(input) // Whole number part represents minutes
        let secondsPart = Int((input - Double(minutesPart)) * 60) // Fractional part converted to seconds

        timeRemaining = (minutesPart * 60) + secondsPart
        initialTime = timeRemaining
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateTimer()
            }
        }
        sender.stringValue = ""
        updateButtonTitle()
        statusItem.menu?.cancelTracking() // Close the menu after starting the timer
    }

    func updateTimer() {
        if let timeRemaining = self.timeRemaining, timeRemaining > 0 {
            self.timeRemaining = timeRemaining - 1
            updateButtonTitle()
        } else {
            timer?.invalidate()
            timeRemaining = nil
            initialTime = 0
            shouldClearZeroTimer = false
            updateButtonTitle()
        }
    }

    func updateButtonTitle() {
        if let button = statusItem.button {
            if let timeRemaining = self.timeRemaining {
                button.title = timeString(time: timeRemaining)
            } else if initialTime == 0 && shouldClearZeroTimer == false {
                button.title = "00:00"
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
        initialTime = 0
        shouldClearZeroTimer = true
        updateButtonTitle()
    }

    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
