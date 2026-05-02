import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Settings UI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            soundTab
                .tabItem { Label("Sound", systemImage: "speaker.wave.2") }
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .padding(20)
    }

    private var generalTab: some View {
        Form {
            HStack {
                Text("Default duration:")
                TextField("", value: $store.defaultMinutes, formatter: minutesFormatter)
                    .frame(width: 70)
                Stepper("", value: $store.defaultMinutes, in: 0.5...600, step: 0.5)
                    .labelsHidden()
                Text("minutes")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Increment / decrement step:")
                TextField("", value: $store.incrementSeconds, formatter: NumberFormatter())
                    .frame(width: 60)
                Stepper("", value: $store.incrementSeconds, in: 5...3600, step: 5)
                    .labelsHidden()
                Text("seconds")
                    .foregroundStyle(.secondary)
            }
            Toggle("Hide clock icon while timer is active", isOn: $store.hideClockWhenRunning)
        }
        .padding(.vertical, 8)
    }

    private var soundTab: some View {
        Form {
            Toggle("Play sound when timer ends", isOn: $store.playSound)
            HStack {
                Text("Sound:")
                Picker("", selection: $store.soundName) {
                    ForEach(store.availableSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                .disabled(!store.playSound)
                Button("Test") { previewSound() }
                    .disabled(!store.playSound)
            }
            Toggle("Repeat sound until acknowledged", isOn: $store.repeatSound)
                .disabled(!store.playSound)
            HStack {
                Text("Repeat every:")
                TextField("", value: $store.repeatSoundInterval, formatter: NumberFormatter())
                    .frame(width: 50)
                Stepper("", value: $store.repeatSoundInterval, in: 1...60)
                    .labelsHidden()
                Text("seconds")
                    .foregroundStyle(.secondary)
            }
            .disabled(!store.playSound || !store.repeatSound)
        }
        .padding(.vertical, 8)
    }

    private var shortcutsTab: some View {
        Form {
            Text("Global shortcuts work anywhere on the system. Click Record, then press a combination including at least one modifier (⌘ ⌥ ⌃ ⇧).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            shortcutRow(title: "Toggle (start / pause / dismiss)", binding: $store.toggleHotkey)
            shortcutRow(title: "Increase timer", binding: $store.incrementHotkey)
            shortcutRow(title: "Decrease timer", binding: $store.decrementHotkey)
        }
        .padding(.vertical, 8)
    }

    private func shortcutRow(title: String, binding: Binding<HotkeyBinding>) -> some View {
        HStack {
            Text(title)
            Spacer()
            HotkeyRecorderField(binding: binding)
                .frame(width: 200, height: 26)
        }
    }

    private func previewSound() {
        let name = store.soundName == "Default" ? "Glass" : store.soundName
        NSSound(named: name)?.play()
    }

    private var minutesFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.minimum = 0
        return f
    }
}

// MARK: - Hotkey recorder

struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var binding: HotkeyBinding

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.binding = binding
        view.onChange = { newValue in
            DispatchQueue.main.async { self.binding = newValue }
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        if nsView.binding != binding {
            nsView.binding = binding
        }
    }
}

final class HotkeyRecorderNSView: NSView {
    var binding: HotkeyBinding = .empty {
        didSet { updateLabel() }
    }
    var onChange: ((HotkeyBinding) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "Record", target: nil, action: nil)
    private let clearButton = NSButton(title: "✕", target: nil, action: nil)
    private var recording = false {
        didSet {
            recordButton.title = recording ? "Press keys…" : "Record"
            if recording {
                window?.makeFirstResponder(self)
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        addSubview(recordButton)
        addSubview(clearButton)
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        recordButton.bezelStyle = .rounded
        recordButton.controlSize = .small
        clearButton.target = self
        clearButton.action = #selector(clearBinding)
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.toolTip = "Clear shortcut"
        updateLabel()
    }

    override func layout() {
        super.layout()
        let h: CGFloat = 22
        let y = (bounds.height - h) / 2
        clearButton.frame = NSRect(x: bounds.width - 28, y: y, width: 28, height: h)
        recordButton.frame = NSRect(x: bounds.width - 28 - 80 - 4, y: y, width: 80, height: h)
        label.frame = NSRect(x: 4, y: y, width: bounds.width - 28 - 80 - 12, height: h)
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    @objc private func toggleRecording() {
        recording.toggle()
    }

    @objc private func clearBinding() {
        recording = false
        binding = .empty
        onChange?(.empty)
    }

    override func keyDown(with event: NSEvent) {
        if recording {
            handle(event)
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording {
            handle(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            recording = false
            return
        }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbonMods = HotkeyRecorderNSView.carbonModifiers(from: mods)
        guard carbonMods != 0 else { return }  // Need at least one modifier
        let display = HotkeyRecorderNSView.displayString(modifiers: mods, keyCode: event.keyCode, characters: event.charactersIgnoringModifiers ?? "")
        let newBinding = HotkeyBinding(keyCode: UInt32(event.keyCode), modifiers: carbonMods, displayString: display)
        binding = newBinding
        onChange?(newBinding)
        recording = false
    }

    private func updateLabel() {
        label.stringValue = binding.isEmpty ? "(none)" : binding.displayString
        label.textColor = binding.isEmpty ? .tertiaryLabelColor : .labelColor
    }

    static func carbonModifiers(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if cocoa.contains(.command) { m |= UInt32(cmdKey) }
        if cocoa.contains(.option) { m |= UInt32(optionKey) }
        if cocoa.contains(.control) { m |= UInt32(controlKey) }
        if cocoa.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    static func displayString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, characters: String) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += keyName(for: keyCode, characters: characters)
        return s
    }

    static func keyName(for keyCode: UInt16, characters: String) -> String {
        let specials: [Int: String] = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
            kVK_Escape: "⎋", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
            kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
            kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let s = specials[Int(keyCode)] { return s }
        return characters.uppercased()
    }
}
