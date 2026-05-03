import SwiftUI
import UserNotifications
import AppKit
import Carbon.HIToolbox

// MARK: - App entry

@main
struct MenuBarTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window is opened manually via AppDelegate to avoid the
        // "Please use SettingsLink" error on macOS 15+.
        Settings { EmptyView() }
    }
}

// MARK: - Hotkey binding

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32  // Carbon-style flags: cmdKey, optionKey, controlKey, shiftKey
    var displayString: String

    static let empty = HotkeyBinding(keyCode: 0, modifiers: 0, displayString: "")
    var isEmpty: Bool { displayString.isEmpty || modifiers == 0 }
}

enum TimerAlertColor: String, CaseIterable, Codable, Hashable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink

    var displayName: String {
        switch self {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .pink: return .systemPink
        }
    }
}

extension Notification.Name {
    static let hotkeyBindingsChanged = Notification.Name("MenuBarTimer.hotkeyBindingsChanged")
}

// MARK: - Settings store

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let defaultMinutes = "defaultMinutes"
        static let incrementSeconds = "incrementSeconds"
        static let playSound = "playSound"
        static let soundName = "soundName"
        static let repeatSound = "repeatSound"
        static let repeatSoundInterval = "repeatSoundInterval"
        static let hideClockWhenRunning = "hideClockWhenRunning"
        static let showNotification = "showNotification"
        static let showTimeUpMessage = "showTimeUpMessage"
        static let alertColor = "alertColor"
        static let alertMessage = "alertMessage"
        static let toggleHotkey = "toggleHotkey"
        static let incrementHotkey = "incrementHotkey"
        static let decrementHotkey = "decrementHotkey"
    }

    @Published var defaultMinutes: Double { didSet { defaults.set(defaultMinutes, forKey: Key.defaultMinutes) } }
    @Published var incrementSeconds: Int { didSet { defaults.set(incrementSeconds, forKey: Key.incrementSeconds) } }
    @Published var playSound: Bool { didSet { defaults.set(playSound, forKey: Key.playSound) } }
    @Published var soundName: String { didSet { defaults.set(soundName, forKey: Key.soundName) } }
    @Published var repeatSound: Bool { didSet { defaults.set(repeatSound, forKey: Key.repeatSound) } }
    @Published var repeatSoundInterval: Int { didSet { defaults.set(repeatSoundInterval, forKey: Key.repeatSoundInterval) } }
    @Published var hideClockWhenRunning: Bool { didSet { defaults.set(hideClockWhenRunning, forKey: Key.hideClockWhenRunning) } }
    @Published var showNotification: Bool { didSet { defaults.set(showNotification, forKey: Key.showNotification) } }
    @Published var showTimeUpMessage: Bool { didSet { defaults.set(showTimeUpMessage, forKey: Key.showTimeUpMessage) } }
    @Published var alertColor: TimerAlertColor { didSet { defaults.set(alertColor.rawValue, forKey: Key.alertColor) } }
    @Published var alertMessage: String {
        didSet {
            let sanitized = Self.sanitizeAlertMessage(alertMessage)
            if alertMessage != sanitized {
                alertMessage = sanitized
            } else {
                defaults.set(alertMessage, forKey: Key.alertMessage)
            }
        }
    }
    @Published var toggleHotkey: HotkeyBinding { didSet { Self.save(toggleHotkey, key: Key.toggleHotkey); broadcastHotkeyChange() } }
    @Published var incrementHotkey: HotkeyBinding { didSet { Self.save(incrementHotkey, key: Key.incrementHotkey); broadcastHotkeyChange() } }
    @Published var decrementHotkey: HotkeyBinding { didSet { Self.save(decrementHotkey, key: Key.decrementHotkey); broadcastHotkeyChange() } }

    let availableSounds = ["Default", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    let availableAlertColors = TimerAlertColor.allCases

    static let alertMessageLimit = 14
    static let defaultAlertMessage = "Time's Up"

    private init() {
        defaults.register(defaults: [
            Key.defaultMinutes: 5.0,
            Key.incrementSeconds: 60,
            Key.playSound: true,
            Key.soundName: "Glass",
            Key.repeatSound: false,
            Key.repeatSoundInterval: 5,
            Key.hideClockWhenRunning: true,
            Key.showNotification: true,
            Key.showTimeUpMessage: true,
            Key.alertColor: TimerAlertColor.red.rawValue,
            Key.alertMessage: Self.defaultAlertMessage,
        ])
        defaultMinutes = defaults.double(forKey: Key.defaultMinutes)
        incrementSeconds = defaults.integer(forKey: Key.incrementSeconds)
        playSound = defaults.bool(forKey: Key.playSound)
        soundName = defaults.string(forKey: Key.soundName) ?? "Glass"
        repeatSound = defaults.bool(forKey: Key.repeatSound)
        repeatSoundInterval = defaults.integer(forKey: Key.repeatSoundInterval)
        hideClockWhenRunning = defaults.bool(forKey: Key.hideClockWhenRunning)
        showNotification = defaults.bool(forKey: Key.showNotification)
        showTimeUpMessage = defaults.bool(forKey: Key.showTimeUpMessage)
        let colorRawValue = defaults.string(forKey: Key.alertColor) ?? TimerAlertColor.red.rawValue
        alertColor = TimerAlertColor(rawValue: colorRawValue) ?? .red
        alertMessage = Self.sanitizeAlertMessage(defaults.string(forKey: Key.alertMessage) ?? Self.defaultAlertMessage)
        toggleHotkey = Self.load(key: Key.toggleHotkey) ?? .empty
        incrementHotkey = Self.load(key: Key.incrementHotkey) ?? .empty
        decrementHotkey = Self.load(key: Key.decrementHotkey) ?? .empty
    }

    static func sanitizeAlertMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return defaultAlertMessage }
        return String(trimmed.prefix(alertMessageLimit))
    }

    private func broadcastHotkeyChange() {
        NotificationCenter.default.post(name: .hotkeyBindingsChanged, object: nil)
    }

    private static func save(_ b: HotkeyBinding, key: String) {
        if let data = try? JSONEncoder().encode(b) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private static func load(key: String) -> HotkeyBinding? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }
}

// MARK: - Timer state machine

enum TimerState: Equatable {
    case idle              // No timer set
    case armed(Int)        // Time set, not ticking (post-pause or pre-start)
    case running(Int)      // Ticking down
    case done              // Hit zero, awaiting acknowledgement

    var remainingSeconds: Int? {
        switch self {
        case .idle, .done: return nil
        case .armed(let s), .running(let s): return s
        }
    }
}

final class TimerController {
    private(set) var state: TimerState = .idle {
        didSet { onStateChange?(state) }
    }
    var onStateChange: ((TimerState) -> Void)?
    var onComplete: (() -> Void)?
    var onAcknowledge: (() -> Void)?

    private var ticker: Timer?

    func setDuration(seconds: Int, andStart: Bool) {
        stopTicker()
        guard seconds > 0 else { state = .idle; return }
        if andStart {
            state = .running(seconds)
            startTicker()
        } else {
            state = .armed(seconds)
        }
    }

    func toggle() {
        switch state {
        case .idle:
            let secs = max(1, Int(SettingsStore.shared.defaultMinutes * 60))
            state = .running(secs)
            startTicker()
        case .armed(let s):
            state = .running(s)
            startTicker()
        case .running(let s):
            stopTicker()
            state = .armed(s)
        case .done:
            acknowledgeDone()
        }
    }

    func increment(by seconds: Int) {
        guard seconds > 0 else { return }
        switch state {
        case .idle:
            state = .armed(seconds)
        case .armed(let s):
            state = .armed(s + seconds)
        case .running(let s):
            state = .running(s + seconds)
        case .done:
            acknowledgeDone()
            state = .armed(seconds)
        }
    }

    func decrement(by seconds: Int) {
        guard seconds > 0 else { return }
        switch state {
        case .idle, .done:
            return
        case .armed(let s):
            let newVal = s - seconds
            state = newVal > 0 ? .armed(newVal) : .idle
        case .running(let s):
            let newVal = s - seconds
            if newVal > 0 {
                state = .running(newVal)
            } else {
                stopTicker()
                fireDone()
            }
        }
    }

    func endTimer() {
        stopTicker()
        state = .idle
    }

    func acknowledgeDone() {
        if case .done = state {
            state = .idle
            onAcknowledge?()
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }
    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
    private func tick() {
        guard case .running(let s) = state else { return }
        if s > 1 {
            state = .running(s - 1)
        } else {
            stopTicker()
            fireDone()
        }
    }
    private func fireDone() {
        state = .done
        onComplete?()
    }
}

// MARK: - Carbon global hotkey

final class GlobalHotkey {
    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        guard modifiers != 0 else { return nil }
        Self.installEventHandler()
        let myID = Self.nextID
        Self.nextID += 1
        self.id = myID
        Self.handlers[myID] = action

        let signature: OSType = 0x4D425452 // 'MBTR'
        let hkID = EventHotKeyID(signature: signature, id: myID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Self.handlers.removeValue(forKey: myID)
            return nil
        }
        self.hotKeyRef = ref
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        Self.handlers.removeValue(forKey: id)
    }

    private static func installEventHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            guard let eventRef else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            DispatchQueue.main.async {
                GlobalHotkey.handlers[hkID.id]?()
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

// MARK: - Menu layout

private enum TimerInputMetrics {
    static let menuWidth: CGFloat = 180
    static let rowHeight: CGFloat = 28
    static let inputX: CGFloat = 12
    static let inputY: CGFloat = 2
    static let inputWidth: CGFloat = 56
    static let inputHeight: CGFloat = 24
    static let unitX: CGFloat = 76
    static let unitY: CGFloat = 6
    static let unitWidth: CGFloat = 34
    static let unitHeight: CGFloat = 16
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    let controller = TimerController()

    private var pulseTimer: Timer?
    private var pulseOn = false
    private var soundRepeatTimer: Timer?
    private var hotkeys: [GlobalHotkey] = []

    private weak var inputTextField: NSTextField?
    private var settingsWindowController: NSWindowController?
    private var showingInput = false
    private var lastEnteredMinutes: String?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        registerNotificationCategories()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        controller.onStateChange = { [weak self] _ in self?.updateStatusItem() }
        controller.onComplete = { [weak self] in self?.handleTimerCompleted() }
        controller.onAcknowledge = { [weak self] in self?.handleAcknowledged() }

        registerHotkeys()
        NotificationCenter.default.addObserver(
            forName: .hotkeyBindingsChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.registerHotkeys() }

        updateStatusItem()
    }

    // MARK: Status item display

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let store = SettingsStore.shared

        switch controller.state {
        case .idle:
            stopPulse()
            button.attributedTitle = NSAttributedString()
            button.title = ""
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")

        case .armed(let s):
            stopPulse()
            button.image = store.hideClockWhenRunning ? nil : NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Paused")
            let attr = NSAttributedString(
                string: timeString(s),
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.menuBarFont(ofSize: 0)
                ]
            )
            button.attributedTitle = attr

        case .running(let s):
            stopPulse()
            button.image = store.hideClockWhenRunning ? nil : NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
            button.attributedTitle = NSAttributedString()
            button.title = timeString(s)

        case .done:
            if store.showTimeUpMessage {
                button.image = nil
                startPulse()
            } else {
                stopPulse()
                button.attributedTitle = NSAttributedString()
                button.title = ""
                button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer done")
            }
        }
    }

    private func startPulse() {
        guard pulseTimer == nil else { return }
        pulseOn = true
        renderPulse()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.pulseOn.toggle()
            self?.renderPulse()
        }
    }
    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
    private func renderPulse() {
        guard let button = statusItem.button else { return }
        let store = SettingsStore.shared
        let baseColor = store.alertColor.nsColor
        let color: NSColor = pulseOn ? baseColor : baseColor.withAlphaComponent(0.35)
        let attr = NSAttributedString(
            string: store.alertMessage,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.menuBarFont(ofSize: 0)
            ]
        )
        button.image = nil
        button.title = ""
        button.attributedTitle = attr
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let shouldShowInput = controller.state == .idle || showingInput
        if shouldShowInput {
            // Auto-focus only when the user explicitly asked for the input by
            // clicking "New Timer" (showingInput=true). On a plain idle-state
            // menu open, focusing inside the async block races with the menu's
            // mouse tracking and causes the textfield's action to fire — which
            // immediately starts a timer.
            addInputField(to: menu, autoFocus: showingInput)
        } else {
            addNewTimerButton(to: menu)
        }

        // In idle state the text field is the only way to start a timer — no toggle
        // item here, which also prevents it from landing in the click zone of the
        // mouse-up event that opened the menu. For active states the toggle/end
        // items appear without a separator (B4).
        switch controller.state {
        case .idle:
            break
        case .armed:
            let item = NSMenuItem(title: "Resume Timer", action: #selector(toggleAction), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            let end = NSMenuItem(title: "End Timer", action: #selector(endAction), keyEquivalent: "")
            end.target = self
            menu.addItem(end)
        case .running:
            let item = NSMenuItem(title: "Pause Timer", action: #selector(toggleAction), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            let end = NSMenuItem(title: "End Timer", action: #selector(endAction), keyEquivalent: "")
            end.target = self
            menu.addItem(end)
        case .done:
            let item = NSMenuItem(title: "Dismiss", action: #selector(toggleAction), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func addInputField(to menu: NSMenu, autoFocus: Bool) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: TimerInputMetrics.menuWidth, height: TimerInputMetrics.rowHeight))
        let textField = NSTextField(string: "")
        textField.placeholderString = "Minutes"
        textField.target = self
        textField.action = #selector(startTimerFromTextField(_:))
        textField.formatter = MaxLengthFormatter(maxCharacters: 3)
        textField.cell?.sendsActionOnEndEditing = false
        textField.frame = NSRect(
            x: TimerInputMetrics.inputX,
            y: TimerInputMetrics.inputY,
            width: TimerInputMetrics.inputWidth,
            height: TimerInputMetrics.inputHeight
        )

        textField.stringValue = timerInputValue()

        let unitLabel = NSTextField(labelWithString: "min")
        unitLabel.font = NSFont.menuFont(ofSize: 0)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.frame = NSRect(
            x: TimerInputMetrics.unitX,
            y: TimerInputMetrics.unitY,
            width: TimerInputMetrics.unitWidth,
            height: TimerInputMetrics.unitHeight
        )

        container.addSubview(textField)
        container.addSubview(unitLabel)
        let item = NSMenuItem()
        item.view = container
        inputTextField = textField
        menu.addItem(item)

        if autoFocus {
            DispatchQueue.main.async { [weak textField] in
                guard let tf = textField else { return }
                tf.window?.makeFirstResponder(tf)
                tf.selectText(nil)
            }
        }
    }

    private func addNewTimerButton(to menu: NSMenu) {
        let view = MenuButtonView(title: "New Timer")
        view.configureInput(target: self, action: #selector(startTimerFromTextField(_:)))
        view.onClick = { [weak self, weak view] in
            guard let self, let view else { return }
            self.activateInputInPlace(view)
        }
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
    }

    private func activateInputInPlace(_ view: MenuButtonView) {
        showingInput = true
        view.showInput(value: timerInputValue())
    }

    private func timerInputValue() -> String {
        let store = SettingsStore.shared
        if let last = lastEnteredMinutes, !last.isEmpty {
            return String(last.prefix(3))
        } else if store.defaultMinutes > 0 {
            return String(String(format: "%g", store.defaultMinutes).prefix(3))
        }
        return ""
    }

    func menuDidClose(_ menu: NSMenu) {
        if controller.state != .idle { showingInput = false }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Opening the menu acknowledges a "done" pulse — natural since the user is
        // already interacting with the timer to set the next one or dismiss it.
        if case .done = controller.state {
            controller.acknowledgeDone()
        }
    }

    // MARK: Actions

    @objc private func startTimerFromTextField(_ sender: NSTextField) {
        guard let input = Double(sender.stringValue), input > 0 else { return }
        lastEnteredMinutes = sender.stringValue
        let minutes = Int(input)
        let seconds = Int(((input - Double(minutes)) * 60).rounded())
        let total = minutes * 60 + seconds
        controller.setDuration(seconds: total, andStart: true)
        sender.stringValue = ""
        statusItem.menu?.cancelTracking()
    }

    @objc private func toggleAction() { controller.toggle() }
    @objc private func endAction() { controller.endTimer() }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let host = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(SettingsStore.shared)
            )
            let window = NSWindow(contentViewController: host)
            window.title = "Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 520, height: 380))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    // MARK: Done state

    private func handleTimerCompleted() {
        playCompletionSound()
        startSoundRepeat()
        if SettingsStore.shared.showNotification {
            sendNotification()
        }
        updateStatusItem()
    }

    private func handleAcknowledged() {
        stopSoundRepeat()
        stopPulse()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["timerDone"])
        updateStatusItem()
    }

    private func playCompletionSound() {
        let store = SettingsStore.shared
        guard store.playSound else { return }
        let name = store.soundName == "Default" ? "Glass" : store.soundName
        NSSound(named: name)?.play()
    }

    private func startSoundRepeat() {
        let store = SettingsStore.shared
        guard store.playSound, store.repeatSound, store.repeatSoundInterval > 0 else { return }
        soundRepeatTimer?.invalidate()
        soundRepeatTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(store.repeatSoundInterval),
            repeats: true
        ) { [weak self] _ in self?.playCompletionSound() }
    }
    private func stopSoundRepeat() {
        soundRepeatTimer?.invalidate()
        soundRepeatTimer = nil
    }

    // MARK: Notifications

    private func registerNotificationCategories() {
        let dismiss = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [])
        let category = UNNotificationCategory(
            identifier: "TIMER_DONE",
            actions: [dismiss],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func sendNotification() {
        let store = SettingsStore.shared
        let content = UNMutableNotificationContent()
        content.title = "Timer Completed"
        content.body = store.alertMessage
        content.categoryIdentifier = "TIMER_DONE"
        if store.playSound { content.sound = .default }
        if #available(macOS 12, *) { content.interruptionLevel = .timeSensitive }
        let request = UNNotificationRequest(identifier: "timerDone", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { self.controller.acknowledgeDone() }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: Hotkeys

    private func registerHotkeys() {
        hotkeys.removeAll()
        let store = SettingsStore.shared
        if !store.toggleHotkey.isEmpty,
           let hk = GlobalHotkey(
            keyCode: store.toggleHotkey.keyCode,
            modifiers: store.toggleHotkey.modifiers,
            action: { [weak self] in self?.controller.toggle() }) {
            hotkeys.append(hk)
        }
        if !store.incrementHotkey.isEmpty,
           let hk = GlobalHotkey(
            keyCode: store.incrementHotkey.keyCode,
            modifiers: store.incrementHotkey.modifiers,
            action: { [weak self] in
                self?.controller.increment(by: SettingsStore.shared.incrementSeconds)
            }) {
            hotkeys.append(hk)
        }
        if !store.decrementHotkey.isEmpty,
           let hk = GlobalHotkey(
            keyCode: store.decrementHotkey.keyCode,
            modifiers: store.decrementHotkey.modifiers,
            action: { [weak self] in
                self?.controller.decrement(by: SettingsStore.shared.incrementSeconds)
            }) {
            hotkeys.append(hk)
        }
    }

    // MARK: Helpers

    private func timeString(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            let s = seconds % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Text field formatting

final class MaxLengthFormatter: Formatter {
    private let maxCharacters: Int

    init(maxCharacters: Int) {
        self.maxCharacters = maxCharacters
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func string(for obj: Any?) -> String? {
        guard let obj else { return nil }
        if let string = obj as? String { return string }
        return "\(obj)"
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        obj?.pointee = String(string.prefix(maxCharacters)) as NSString
        return true
    }

    override func isPartialStringValid(
        _ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>,
        proposedSelectedRange proposedSelRangePtr: NSRangePointer?,
        originalString origString: String,
        originalSelectedRange origSelRange: NSRange,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        guard partialStringPtr.pointee.length > maxCharacters else { return true }
        partialStringPtr.pointee = partialStringPtr.pointee.substring(to: maxCharacters) as NSString
        proposedSelRangePtr?.pointee = NSRange(location: maxCharacters, length: 0)
        return false
    }
}

// MARK: - Menu button view

// A custom view-based menu item. Unlike a standard NSMenuItem action, clicking
// this view does not dismiss the menu, which lets us swap "New Timer" for the
// input field in place.
final class MenuButtonView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let textField = NSTextField(string: "")
    private let unitLabel = NSTextField(labelWithString: "min")
    var onClick: (() -> Void)?
    private var showingInput = false
    private var hovered = false {
        didSet { needsDisplay = true; updateLabelColor() }
    }

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: TimerInputMetrics.menuWidth, height: TimerInputMetrics.rowHeight))
        label.stringValue = title
        label.font = NSFont.menuFont(ofSize: 0)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(x: 12, y: 6, width: 150, height: 16)
        addSubview(label)

        textField.placeholderString = "Minutes"
        textField.formatter = MaxLengthFormatter(maxCharacters: 3)
        textField.cell?.sendsActionOnEndEditing = false
        textField.frame = NSRect(
            x: TimerInputMetrics.inputX,
            y: TimerInputMetrics.inputY,
            width: TimerInputMetrics.inputWidth,
            height: TimerInputMetrics.inputHeight
        )
        textField.isHidden = true
        addSubview(textField)

        unitLabel.font = NSFont.menuFont(ofSize: 0)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.frame = NSRect(
            x: TimerInputMetrics.unitX,
            y: TimerInputMetrics.unitY,
            width: TimerInputMetrics.unitWidth,
            height: TimerInputMetrics.unitHeight
        )
        unitLabel.isHidden = true
        addSubview(unitLabel)

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    func configureInput(target: AnyObject, action: Selector) {
        textField.target = target
        textField.action = action
    }

    func showInput(value: String) {
        showingInput = true
        hovered = false
        label.isHidden = true
        textField.isHidden = false
        unitLabel.isHidden = false
        textField.stringValue = value
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self.textField)
            self.textField.selectText(nil)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard !showingInput else { return }
        hovered = true
    }

    override func mouseExited(with event: NSEvent) {
        guard !showingInput else { return }
        hovered = false
    }

    override func mouseUp(with event: NSEvent) {
        guard !showingInput else { return }
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        if hovered && !showingInput {
            NSColor.selectedContentBackgroundColor.setFill()
            bounds.fill()
        }
    }

    private func updateLabelColor() {
        label.textColor = hovered ? .white : .labelColor
    }
}
