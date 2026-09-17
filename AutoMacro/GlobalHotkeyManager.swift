//
//  GlobalHotkeyManager.swift
//  AutoMacro+
//
//  Manages system-wide global hotkeys using the Carbon RegisterEventHotKey API.
//  This approach does NOT require Accessibility permission for hotkey detection
//  (only CGEvent simulation needs it). Supports two configurable hotkeys:
//  - Start/Stop macro (default: ⌃⌥S)
//  - Start/Stop recording (default: ⌃⌥R)
//  Both hotkeys are persisted to UserDefaults and can be changed via the UI.
//

import Foundation
import CoreGraphics
import AppKit
import Carbon

// MARK: - Recorded Hotkey

struct RecordedHotkey: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String

    static let defaultStart = RecordedHotkey(
        keyCode: 1,           // S key
        carbonModifiers: UInt32(controlKey | optionKey),
        displayString: "⌃⌥S"
    )

    static let defaultRecord = RecordedHotkey(
        keyCode: 15,          // R key
        carbonModifiers: UInt32(controlKey | optionKey),
        displayString: "⌃⌥R"
    )
}

// MARK: - Which hotkey is being edited

enum HotkeySlot {
    case start
    case record
}

// MARK: - Global Hotkey Manager

final class GlobalHotkeyManager: ObservableObject {

    @Published var startHotkey: RecordedHotkey = RecordedHotkey.defaultStart
    @Published var recordHotkey: RecordedHotkey = RecordedHotkey.defaultRecord
    @Published var isRecordingHotkey: Bool = false
    @Published var tapActive: Bool = false

    // Which hotkey slot we're currently editing
    var editingSlot: HotkeySlot = .start

    var onToggle: (() -> Void)?
    var onRecordToggle: (() -> Void)?

    private let startPersistKey = "savedHotkey_start"
    private let recordPersistKey = "savedHotkey_record"
    private var startHotKeyRef: EventHotKeyRef?
    private var recordHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private var recordingLocalMonitor: Any?
    private var localKeyMonitor: Any?

    private static weak var shared: GlobalHotkeyManager?

    init() {
        GlobalHotkeyManager.shared = self
        loadHotkeys()
        registerCarbonHotkeys()
        setupLocalMonitor()
    }

    deinit {
        unregisterCarbonHotkeys()
        tearDownLocalMonitor()
    }

    // MARK: - Public: Hotkey Recording

    func startRecording(slot: HotkeySlot) {
        editingSlot = slot
        isRecordingHotkey = true
        recordingLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedEvent(event)
            return nil
        }
    }

    func applyRecordedHotkey(_ hk: RecordedHotkey) {
        switch editingSlot {
        case .start:
            startHotkey = hk
        case .record:
            recordHotkey = hk
        }
        isRecordingHotkey = false
        saveHotkeys()

        if let m = recordingLocalMonitor { NSEvent.removeMonitor(m); recordingLocalMonitor = nil }

        unregisterCarbonHotkeys()
        registerCarbonHotkeys()
    }

    func resetToDefault(slot: HotkeySlot) {
        switch slot {
        case .start:
            startHotkey = .defaultStart
        case .record:
            recordHotkey = .defaultRecord
        }
        saveHotkeys()
        unregisterCarbonHotkeys()
        registerCarbonHotkeys()
    }

    func retryEventTap() {
        unregisterCarbonHotkeys()
        registerCarbonHotkeys()
    }

    // MARK: - Carbon Hot Key Registration

    private func registerCarbonHotkeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotkeyID = EventHotKeyID()
                GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &hotkeyID)

                switch hotkeyID.id {
                case 1:
                    GlobalHotkeyManager.shared?.onToggle?()
                case 2:
                    GlobalHotkeyManager.shared?.onRecordToggle?()
                default:
                    break
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard status == noErr else {
            DispatchQueue.main.async { self.tapActive = false }
            return
        }

        // Hotkey 1: Start/Stop
        let id1 = EventHotKeyID(signature: OSType(0x4155544F), id: 1)
        let reg1 = RegisterEventHotKey(
            startHotkey.keyCode,
            startHotkey.carbonModifiers,
            id1,
            GetApplicationEventTarget(),
            0,
            &startHotKeyRef
        )

        // Hotkey 2: Record
        let id2 = EventHotKeyID(signature: OSType(0x4155544F), id: 2)
        RegisterEventHotKey(
            recordHotkey.keyCode,
            recordHotkey.carbonModifiers,
            id2,
            GetApplicationEventTarget(),
            0,
            &recordHotKeyRef
        )

        DispatchQueue.main.async {
            self.tapActive = (reg1 == noErr)
        }
    }

    private func unregisterCarbonHotkeys() {
        if let ref = startHotKeyRef {
            UnregisterEventHotKey(ref)
            startHotKeyRef = nil
        }
        if let ref = recordHotKeyRef {
            UnregisterEventHotKey(ref)
            recordHotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    // MARK: - Local Key Monitor

    private func setupLocalMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isRecordingHotkey else { return event }
            let keyCode = UInt32(event.keyCode)
            let carbonMods = self.nsModifiersToCarbonModifiers(event.modifierFlags)
            if keyCode == self.startHotkey.keyCode && carbonMods == self.startHotkey.carbonModifiers {
                self.onToggle?()
                return nil
            }
            if keyCode == self.recordHotkey.keyCode && carbonMods == self.recordHotkey.carbonModifiers {
                self.onRecordToggle?()
                return nil
            }
            return event
        }
    }

    private func tearDownLocalMonitor() {
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
        if let m = recordingLocalMonitor { NSEvent.removeMonitor(m); recordingLocalMonitor = nil }
    }

    // MARK: - Recording

    private func handleRecordedEvent(_ event: NSEvent) {
        guard isRecordingHotkey else { return }
        let keyCode = UInt32(event.keyCode)
        let carbonMods = nsModifiersToCarbonModifiers(event.modifierFlags)
        let display = buildDisplayString(keyCode: keyCode, carbonMods: carbonMods)
        let recorded = RecordedHotkey(keyCode: keyCode, carbonModifiers: carbonMods, displayString: display)
        DispatchQueue.main.async { [weak self] in
            self?.applyRecordedHotkey(recorded)
        }
    }

    // MARK: - Helpers

    private func nsModifiersToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control)  { carbon |= UInt32(controlKey) }
        if flags.contains(.option)   { carbon |= UInt32(optionKey) }
        if flags.contains(.shift)    { carbon |= UInt32(shiftKey) }
        if flags.contains(.command)  { carbon |= UInt32(cmdKey) }
        return carbon
    }

    private func buildDisplayString(keyCode: UInt32, carbonMods: UInt32) -> String {
        var s = ""
        if (carbonMods & UInt32(controlKey)) != 0 { s += "⌃" }
        if (carbonMods & UInt32(optionKey))  != 0 { s += "⌥" }
        if (carbonMods & UInt32(shiftKey))   != 0 { s += "⇧" }
        if (carbonMods & UInt32(cmdKey))     != 0 { s += "⌘" }
        s += keyDisplayName(for: keyCode)
        return s
    }

    private func keyDisplayName(for keyCode: UInt32) -> String {
        let nameMap: [UInt32: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
            11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",
            20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",
            29:"0",31:"O",32:"U",34:"I",35:"P",36:"↩",37:"L",38:"J",39:"'",
            40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",
            48:"⇥",49:"Space",51:"⌫",53:"⎋",
            96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",118:"F4",120:"F2",122:"F1",
            123:"←",124:"→",125:"↓",126:"↑",
        ]
        return nameMap[keyCode] ?? "Key\(keyCode)"
    }

    // MARK: - Persistence

    private func saveHotkeys() {
        if let data = try? JSONEncoder().encode(startHotkey) {
            UserDefaults.standard.set(data, forKey: startPersistKey)
        }
        if let data = try? JSONEncoder().encode(recordHotkey) {
            UserDefaults.standard.set(data, forKey: recordPersistKey)
        }
    }

    private func loadHotkeys() {
        if let data = UserDefaults.standard.data(forKey: startPersistKey),
           let hk = try? JSONDecoder().decode(RecordedHotkey.self, from: data) {
            startHotkey = hk
        }
        if let data = UserDefaults.standard.data(forKey: recordPersistKey),
           let hk = try? JSONDecoder().decode(RecordedHotkey.self, from: data) {
            recordHotkey = hk
        }
    }
}
