import SwiftUI
import UserNotifications

@main
struct MenuBarTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main app window, but provide a settings placeholder
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem! // Represents the icon in the macOS menu bar
    var timer: Timer? // The timer instance
    var timeRemaining: Int? // Remaining time in seconds
    var isPaused: Bool = false // Tracks whether the timer is paused
    var initialTime: Int? // The initial time set for the timer in seconds
    var shouldClearZeroTimer: Bool = false // Ensures the UI clears when timer ends

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request permission to send notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Create the status item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
            button.action = #selector(showMenu) // Set the menu to display when clicked
        }
    }

    @objc func showMenu() {
        if let button = statusItem.button {
            let menu = NSMenu()

            // Add a text field for timer input
            let textFieldItem = NSMenuItem()
            let textField = NSTextField(string: "")
            textField.placeholderString = "Minutes" // Hint text
            textField.target = self
            textField.action = #selector(startTimer(_:))
            textField.frame = NSRect(x: 0, y: 0, width: 100, height: 30) // TextField dimensions
            if let initialTime = initialTime {
                textField.stringValue = "\(initialTime / 60)" // Prefill if timer is running
            }
            textFieldItem.view = textField

            // Add menu items for timer controls and quitting
            menu.addItem(textFieldItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Pause Timer", action: #selector(pauseTimer), keyEquivalent: "p"))
            menu.addItem(NSMenuItem(title: "End Timer", action: #selector(endTimer), keyEquivalent: "e"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

            // Attach the menu to the status item
            statusItem.menu = menu
            statusItem.button?.performClick(nil) // Display the menu immediately
        }
    }

    @objc func startTimer(_ sender: NSTextField) {
        // Parse input from the text field
        guard let input = Double(sender.stringValue) else { return } // Ensure input is a valid number
        let minutesPart = Int(input) // Whole part as minutes
        let secondsPart = Int((input - Double(minutesPart)) * 60) // Fractional part as seconds

        // Convert input into total seconds
        timeRemaining = (minutesPart * 60) + secondsPart
        initialTime = timeRemaining

        // Reset and start a new timer
        timer?.invalidate() // Stop any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateTimer()
            }
        }

        sender.stringValue = "" // Clear the input field
        updateButtonTitle() // Update the menu bar icon with the new time
        statusItem.menu?.cancelTracking() // Close the menu after starting the timer
    }

    func updateTimer() {
        if let timeRemaining = self.timeRemaining, timeRemaining > 0 {
            // Decrease the timer every second
            self.timeRemaining = timeRemaining - 1
            updateButtonTitle()
        } else if timeRemaining == 0 {
            // Handle timer completion
            timer?.invalidate()
            self.timeRemaining = nil
            initialTime = 0
            shouldClearZeroTimer = false
            updateButtonTitle()

            // Notify the user that the timer is complete
            sendTimerDoneNotification()
        }
    }

    func sendTimerDoneNotification() {
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Timer Completed"
        content.body = "Your timer is up!"
        content.sound = .default

        // Trigger the notification immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create and add the notification request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }

    func updateButtonTitle() {
        // Update the menu bar icon to show the remaining time
        if let button = statusItem.button {
            if let timeRemaining = self.timeRemaining {
                button.title = timeString(time: timeRemaining)
            } else if initialTime == 0 && shouldClearZeroTimer == false {
                button.title = "00:00" // Default to zero when timer ends
            } else {
                button.title = ""
                button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer") // Reset to default clock icon
            }
        }
    }

    @objc func pauseTimer() {
        // Toggle timer pause state
        isPaused.toggle()
        if isPaused {
            timer?.invalidate() // Stop the timer
        } else {
            // Resume the timer
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.updateTimer()
                }
            }
        }
    }

    @objc func endTimer() {
        // End the timer and reset state
        timer?.invalidate()
        timeRemaining = nil
        initialTime = 0
        shouldClearZeroTimer = true
        updateButtonTitle()
    }

    func timeString(time: Int) -> String {
        // Format seconds into a "MM:SS" string
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
