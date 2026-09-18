//
//  MacroEngine.swift
//  AutoMacro+
//
//  Core macro execution engine. Handles:
//  - Running macro step sequences with configurable loop modes
//  - Recording live mouse clicks and key presses from any app
//  - Firing simulated input events via CGEvent
//  - Persisting saved sequences to UserDefaults
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Execution State

/// Tracks whether the engine is idle, actively running a macro, or in the process of stopping.
enum ExecutionState: Equatable {
    case idle
    case running(loop: Int, stepIndex: Int)
    case stopping
}

// MARK: - Macro Engine

@MainActor
final class MacroEngine: ObservableObject {

    // MARK: Published State

    /// The current list of macro steps to execute.
    @Published var steps: [MacroStep] = []
    /// How many times to loop (infinite or a fixed count).
    @Published var loopMode: LoopMode = .infinite
    /// Current execution state (idle, running, stopping).
    @Published var executionState: ExecutionState = .idle
    /// Which loop iteration we're on (1-indexed).
    @Published var currentLoopCount: Int = 0
    /// Which step is currently executing (0-indexed).
    @Published var currentStepIndex: Int = 0
    /// All saved macro sequences.
    @Published var savedSequences: [MacroSequence] = []
    /// Name of the current sequence being edited.
    @Published var currentSequenceName: String = "Untitled Sequence"
    /// Whether we're currently recording live input.
    @Published var isRecording: Bool = false

    /// When it has a target app selected, key presses go only to that app.
    weak var targetManager: TargetAppManager?

    // MARK: Private State

    private var executionTask: Task<Void, Never>?
    private let persistenceKey = "savedSequences"

    // Recording monitors
    private var recordLocalMonitor: Any?
    private var recordGlobalMonitor: Any?
    private var lastRecordTime: Date?

    init() {
        loadSequences()
    }

    // MARK: - Execution Control

    /// Whether the macro is currently running.
    var isRunning: Bool { executionState != .idle && executionState != .stopping }

    /// Toggles between start and stop.
    func toggleExecution() {
        if isRunning { stop() } else { start() }
    }

    /// Starts executing the macro step sequence.
    func start() {
        guard !steps.isEmpty else { return }
        executionTask?.cancel()
        currentLoopCount = 0
        executionTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    /// Stops the currently running macro.
    func stop() {
        executionState = .stopping
        executionTask?.cancel()
        executionTask = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            self.executionState = .idle
        }
    }

    // MARK: - Sequence Management

    /// Saves the current steps and loop mode as a named sequence.
    func saveCurrentSequence() {
        let seq = MacroSequence(
            name: currentSequenceName,
            steps: steps,
            loopMode: loopMode
        )
        if let i = savedSequences.firstIndex(where: { $0.name == currentSequenceName }) {
            savedSequences[i] = seq
        } else {
            savedSequences.append(seq)
        }
        persistSequences()
    }

    /// Loads a saved sequence into the editor.
    func loadSequence(_ seq: MacroSequence) {
        steps = seq.steps
        loopMode = seq.loopMode
        currentSequenceName = seq.name
    }

    /// Deletes a saved sequence.
    func deleteSequence(_ seq: MacroSequence) {
        savedSequences.removeAll { $0.id == seq.id }
        persistSequences()
    }

    /// Clears all steps and resets the sequence name.
    func clearSteps() {
        steps = []
        currentSequenceName = "Untitled Sequence"
    }

    // MARK: - Step Management

    /// Appends a new step to the end of the list.
    func addStep(_ step: MacroStep) {
        steps.append(step)
    }

    /// Removes steps at the given indices.
    func removeStep(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }

    /// Moves steps from source indices to a destination index.
    func moveStep(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Live Recording

    /// Toggles recording on/off.
    func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    /// Starts capturing mouse clicks and key presses from any app.
    /// Each captured event is appended as a MacroStep with real timing.
    func startRecording() {
        isRecording = true
        lastRecordTime = Date()

        // Local monitor — captures events when our app is focused
        recordLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            self?.handleRecordedInput(event)
            return event  // Pass through so the event still works normally
        }

        // Global monitor — captures events when other apps are focused
        // Requires Accessibility permission
        recordGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            self?.handleRecordedInput(event)
        }
    }

    /// Stops recording and tears down the event monitors.
    func stopRecording() {
        isRecording = false
        if let m = recordLocalMonitor  { NSEvent.removeMonitor(m); recordLocalMonitor = nil }
        if let m = recordGlobalMonitor { NSEvent.removeMonitor(m); recordGlobalMonitor = nil }
        lastRecordTime = nil
    }

    /// Processes a captured NSEvent and appends it as a MacroStep.
    private func handleRecordedInput(_ event: NSEvent) {
        // Calculate delay since the last recorded event
        let now = Date()
        let delayMs: Int
        if let last = lastRecordTime {
            delayMs = max(Int(now.timeIntervalSince(last) * 1000), 0)
        } else {
            delayMs = 0
        }
        lastRecordTime = now

        var step: MacroStep?

        switch event.type {
        case .leftMouseDown:
            step = MacroStep(type: .leftClick, delayMs: delayMs)

        case .rightMouseDown:
            step = MacroStep(type: .rightClick, delayMs: delayMs)

        case .otherMouseDown where event.buttonNumber == 2:
            step = MacroStep(type: .middleClick, delayMs: delayMs)

        case .keyDown:
            let keyCode = CGKeyCode(event.keyCode)
            // Convert NSEvent modifier flags to CGEventFlags
            var mods: CGEventFlags = []
            if event.modifierFlags.contains(.control)  { mods.insert(.maskControl) }
            if event.modifierFlags.contains(.option)   { mods.insert(.maskAlternate) }
            if event.modifierFlags.contains(.shift)    { mods.insert(.maskShift) }
            if event.modifierFlags.contains(.command)  { mods.insert(.maskCommand) }
            // Build a display string like "⌃⌥R"
            let modStr = (event.modifierFlags.contains(.control) ? "⌃" : "")
                       + (event.modifierFlags.contains(.option) ? "⌥" : "")
                       + (event.modifierFlags.contains(.shift) ? "⇧" : "")
                       + (event.modifierFlags.contains(.command) ? "⌘" : "")
            let keyName = keyDisplayName(for: UInt32(keyCode))
            step = MacroStep(type: .keyPress(keyCode: keyCode, modifiers: mods, displayName: modStr + keyName), delayMs: delayMs)

        default:
            break
        }

        if let step {
            DispatchQueue.main.async { [weak self] in
                self?.steps.append(step)
            }
        }
    }

    // MARK: - Execution Loop

    /// Main execution loop. Iterates through steps, firing each one after its delay.
    /// Respects cancellation (via Task.isCancelled) and loop mode limits.
    private func runLoop() async {
        var loop = 0
        while !Task.isCancelled {
            loop += 1
            await MainActor.run { currentLoopCount = loop }

            for (index, step) in steps.enumerated() {
                if Task.isCancelled { break }
                await MainActor.run {
                    currentStepIndex = index
                    executionState = .running(loop: loop, stepIndex: index)
                }

                // Wait the step's configured delay
                if step.delayMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.delayMs) * 1_000_000)
                }

                if Task.isCancelled { break }

                // Simulate the input event
                fireEvent(step)
            }

            if Task.isCancelled { break }

            // Check if we've reached the loop limit
            if case .count(let max) = loopMode, loop >= max { break }
        }

        await MainActor.run { executionState = .idle }
    }

    // MARK: - CGEvent Simulation

    /// Dispatches the appropriate CGEvent(s) for a given step.
    private func fireEvent(_ step: MacroStep) {
        switch step.type {
        case .leftClick:
            click(step, button: .left, down: .leftMouseDown, up: .leftMouseUp)

        case .rightClick:
            click(step, button: .right, down: .rightMouseDown, up: .rightMouseUp)

        case .middleClick:
            click(step, button: .center, down: .otherMouseDown, up: .otherMouseUp)

        case .keyPress(let keyCode, let modifiers, _):
            let pid = targetManager?.target?.pid
            postKeyEvent(keyCode: keyCode, modifiers: modifiers, down: true, pid: pid)
            postKeyEvent(keyCode: keyCode, modifiers: modifiers, down: false, pid: pid)

        case .delay:
            break  // Pure delay step — timing is handled by delayMs above
        }
    }

    /// Fires a click at the step's position.
    private func click(_ step: MacroStep, button: CGMouseButton, down: CGEventType, up: CGEventType) {
        let pos = clickPosition(for: step)
        postMouseEvent(type: down, button: button, at: pos)
        postMouseEvent(type: up, button: button, at: pos)
    }

    /// Resolves the click position based on the step's position mode.
    private func clickPosition(for step: MacroStep) -> CGPoint {
        switch step.positionMode {
        case .dynamic:
            return NSEvent.mouseLocation.cgPointFlipped
        case .fixed:
            return step.fixedPosition
        }
    }

    /// Posts a system-wide mouse event (down or up) at the given screen coordinate.
    private func postMouseEvent(type: CGEventType, button: CGMouseButton, at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
        event.post(tap: .cghidEventTap)
    }

    /// Posts a keyboard event (key down or key up) with optional modifier flags —
    /// system-wide, or only to `pid` in target-app mode.
    private func postKeyEvent(keyCode: CGKeyCode, modifiers: CGEventFlags, down: Bool, pid: pid_t? = nil) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else { return }
        event.flags = modifiers
        if let pid {
            event.postToPid(pid)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Key Display Name

    /// Maps a virtual key code to a human-readable key name for the recording display.
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

    private func persistSequences() {
        if let data = try? JSONEncoder().encode(savedSequences) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadSequences() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let seqs = try? JSONDecoder().decode([MacroSequence].self, from: data) else { return }
        savedSequences = seqs
    }
}

// MARK: - CGPoint Coordinate Conversion

extension NSPoint {
    /// Converts an NSEvent mouse location (origin at bottom-left) to a CGEvent
    /// screen coordinate (origin at top-left) by flipping the Y axis.
    var cgPointFlipped: CGPoint {
        guard let screen = NSScreen.main else { return CGPoint(x: self.x, y: self.y) }
        return CGPoint(x: self.x, y: screen.frame.height - self.y)
    }
}
