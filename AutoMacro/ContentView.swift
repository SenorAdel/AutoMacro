//
//  ContentView.swift
//  AutoMacro+
//
//  Main application UI. Contains the step list, status bar with permission
//  warnings, control panel (loop mode, hotkeys, start/stop), and the Add Step
//  sheet for building macro sequences manually.
//

import SwiftUI
import CoreGraphics

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var engine: MacroEngine
    @EnvironmentObject var hotkeyManager: GlobalHotkeyManager
    @EnvironmentObject var permissions: PermissionsManager

    @State private var showAddStep     = false
    @State private var showSequences   = false
    @State private var loopCountText   = "1"
    @State private var isInfiniteLoop  = true
    @State private var showClearAlert  = false
    @State private var sequenceNameText = "Untitled Sequence"

    var body: some View {
        ZStack {
            // ── Background gradient ──────────────────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.09),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            mainContent
        }
        .frame(width: 520, height: 700)
        .onAppear {
            sequenceNameText = engine.currentSequenceName
            isInfiniteLoop = engine.loopMode == .infinite
            if case .count(let n) = engine.loopMode { loopCountText = "\(n)" }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerBar
            statusBar
            stepList
            bottomControls
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // App icon + title
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color(red: 0.5, green: 0.2, blue: 1.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AutoMacro+")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Macro Automation")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Sequence name field
            TextField("Sequence name", text: $sequenceNameText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 150)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .onChange(of: sequenceNameText) { engine.currentSequenceName = $0 }

            // Saved sequences button
            Button(action: { showSequences.toggle() }) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Saved Sequences")
            .popover(isPresented: $showSequences) {
                SequencesPopover()
                    .environmentObject(engine)
            }

            // Save button
            Button(action: { engine.saveCurrentSequence() }) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Save Sequence")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        VStack(spacing: 0) {
            // Permission warning banner
            if !hotkeyManager.tapActive {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Accessibility permission needed for global hotkey")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Grant Access") {
                        permissions.requestPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            hotkeyManager.retryEventTap()
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.orange)

                    Button(action: { hotkeyManager.retryEventTap() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                    .help("Retry after granting permission")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
            }

            HStack(spacing: 12) {
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(statusColor.opacity(0.4), lineWidth: 4)
                                .scaleEffect(engine.isRunning ? 1.8 : 1.0)
                                .opacity(engine.isRunning ? 0.0 : 0.5)
                                .animation(engine.isRunning ? .easeOut(duration: 0.8).repeatForever() : .default, value: engine.isRunning)
                        )
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(statusColor)
                }

                Spacer()

                // Loop info when running
                if engine.isRunning {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                        Text("Loop \(engine.currentLoopCount)\(loopSuffix) · Step \(engine.currentStepIndex + 1)/\(engine.steps.count)")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                // Hotkey display
                HStack(spacing: 4) {
                    Text("Shortcut:")
                        .font(.system(size: 11))
                        .foregroundColor(Color.secondary.opacity(0.6))
                    Text(hotkeyManager.startHotkey.displayString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    // Scope badge
                    Text(hotkeyManager.tapActive ? "Global" : "In-App")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(hotkeyManager.tapActive ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(hotkeyManager.tapActive ? .green : .orange)
                        .clipShape(Capsule())
                }

                Divider().frame(height: 14).opacity(0.3)

                // Record hotkey display
                HStack(spacing: 4) {
                    Text("Rec:")
                        .font(.system(size: 11))
                        .foregroundColor(Color.secondary.opacity(0.6))
                    Text(hotkeyManager.recordHotkey.displayString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(engine.isRecording ? .red : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))
            .animation(.easeInOut(duration: 0.3), value: engine.isRunning)
        }
    }

    // MARK: - Step List

    private var stepList: some View {
        VStack(spacing: 0) {
            if engine.steps.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(engine.steps.indices), id: \.self) { i in
                            if i < engine.steps.count {
                                StepRowView(
                                    step: $engine.steps[i],
                                    index: i,
                                    totalSteps: engine.steps.count,
                                    isActive: engine.isRunning && engine.currentStepIndex == i,
                                    onMoveUp: { withAnimation(.spring(response: 0.3)) { engine.moveStep(from: IndexSet(integer: i), to: i - 1) } },
                                    onMoveDown: { withAnimation(.spring(response: 0.3)) { engine.moveStep(from: IndexSet(integer: i), to: i + 2) } },
                                    onDelete: { withAnimation { engine.removeStep(at: IndexSet(integer: i)) } }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            // Add Step + Record buttons
            HStack(spacing: 0) {
                // Add step button
                Button(action: { showAddStep = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Step")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(Color.accentColor)
                    .background(Color.accentColor.opacity(0.1))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showAddStep) {
                    AddStepSheet()
                        .environmentObject(engine)
                }

                Divider().frame(height: 30).opacity(0.3)

                // Record button
                Button(action: { engine.toggleRecording() }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(engine.isRecording ? Color.red : Color.red.opacity(0.6))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.4), lineWidth: 3)
                                    .scaleEffect(engine.isRecording ? 1.8 : 1.0)
                                    .opacity(engine.isRecording ? 0.0 : 0.5)
                                    .animation(engine.isRecording ? .easeOut(duration: 0.8).repeatForever() : .default, value: engine.isRecording)
                            )
                        Text(engine.isRecording ? "Stop" : "Record")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(engine.isRecording ? .red : Color.red.opacity(0.8))
                    .background(engine.isRecording ? Color.red.opacity(0.15) : Color.red.opacity(0.05))
                }
                .buttonStyle(.plain)
            }
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.08)),
                alignment: .top
            )
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.6), Color.purple.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 6) {
                Text("No Steps Yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Tap \"Add Step\" to build your macro sequence.\nDrag steps to reorder them.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)

            VStack(spacing: 12) {
                // Loop controls
                HStack(spacing: 12) {
                    Text("Loops:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Toggle("Infinite", isOn: $isInfiniteLoop)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 13))
                        .onChange(of: isInfiniteLoop) { val in
                            if val {
                                engine.loopMode = .infinite
                            } else {
                                let n = Int(loopCountText) ?? 1
                                engine.loopMode = .count(n)
                            }
                        }

                    if !isInfiniteLoop {
                        HStack(spacing: 6) {
                            TextField("1", text: $loopCountText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .frame(width: 60)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .onChange(of: loopCountText) { v in
                                    if let n = Int(v), n > 0 {
                                        engine.loopMode = .count(n)
                                    }
                                }
                            Text("times")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    Spacer()

                    // Clear button
                    Button(action: { showClearAlert = true }) {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .opacity(engine.steps.isEmpty ? 0 : 1)
                    .confirmationDialog("Clear all steps?", isPresented: $showClearAlert) {
                        Button("Clear All", role: .destructive) { withAnimation { engine.clearSteps() } }
                    }
                }
                .animation(.spring(response: 0.3), value: isInfiniteLoop)

                // Hotkey rows
                HStack(spacing: 8) {
                    Text("Start:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    HotkeyRecorderView(slot: .start)
                        .environmentObject(hotkeyManager)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Text("Record:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    HotkeyRecorderView(slot: .record)
                        .environmentObject(hotkeyManager)
                    Spacer()
                }

                // Main start/stop button
                Button(action: { engine.toggleExecution() }) {
                    HStack(spacing: 10) {
                        Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(engine.isRunning ? "Stop Macro" : "Start Macro")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: engine.isRunning
                                ? [Color(red: 0.9, green: 0.2, blue: 0.3), Color(red: 0.7, green: 0.1, blue: 0.2)]
                                : [Color.accentColor, Color(red: 0.3, green: 0.5, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: (engine.isRunning ? Color.red : Color.accentColor).opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(engine.steps.isEmpty)
                .opacity(engine.steps.isEmpty ? 0.4 : 1.0)
                .animation(.spring(response: 0.3), value: engine.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch engine.executionState {
        case .idle:     return Color(red: 0.3, green: 0.85, blue: 0.5)
        case .running:  return Color.accentColor
        case .stopping: return Color.orange
        }
    }

    private var statusText: String {
        switch engine.executionState {
        case .idle:     return "Ready"
        case .running:  return "Running"
        case .stopping: return "Stopping…"
        }
    }

    private var loopSuffix: String {
        if case .count(let max) = engine.loopMode { return "/\(max)" }
        return "/∞"
    }
}

// MARK: - Add Step Sheet

struct AddStepSheet: View {
    @EnvironmentObject var engine: MacroEngine
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: StepCategory = .mouseClick
    @State private var selectedKey: String = "A"
    @State private var delayMs: Int = 500
    @State private var delayText: String = "500"
    @State private var modCtrl: Bool = false
    @State private var modAlt: Bool = false
    @State private var modShift: Bool = false
    @State private var modCmd: Bool = false

    enum StepCategory: String, CaseIterable {
        case mouseClick = "Mouse"
        case keyboard   = "Keyboard"
        case delay      = "Delay"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Step")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider().opacity(0.15)

            // Category picker
            Picker("", selection: $selectedCategory) {
                ForEach(StepCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedCategory {
                    case .mouseClick:
                        mouseSection
                    case .keyboard:
                        keyboardSection
                    case .delay:
                        delaySection
                    }

                    // Delay (shared for non-delay steps)
                    if selectedCategory != .delay {
                        delayEditor
                    }
                }
                .padding()
            }

            Divider().opacity(0.15)

            // Add button
            Button(action: addStep) {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.12))
        .frame(width: 360, height: 480)
    }

    private var mouseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "cursorarrow.click", title: "Choose Click Type")
            HStack(spacing: 10) {
                clickOption(title: "Left Click", icon: "cursorarrow.click", tag: "left")
                clickOption(title: "Right Click", icon: "cursorarrow.click.2", tag: "right")
            }
        }
    }

    @State private var selectedClick: String = "left"

    private func clickOption(title: String, icon: String, tag: String) -> some View {
        Button(action: { selectedClick = tag }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedClick == tag
                ? Color.accentColor.opacity(0.2)
                : Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedClick == tag ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundColor(selectedClick == tag ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "keyboard", title: "Choose Key")

            // Modifier keys
            HStack(spacing: 8) {
                modifierToggle("⌃", binding: $modCtrl)
                modifierToggle("⌥", binding: $modAlt)
                modifierToggle("⇧", binding: $modShift)
                modifierToggle("⌘", binding: $modCmd)
            }

            // Key picker
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                ForEach(KeyCodeHelper.map, id: \.name) { entry in
                    keyButton(name: entry.name)
                }
            }
        }
    }

    private func keyButton(name: String) -> some View {
        Button(action: { selectedKey = name }) {
            Text(name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(minWidth: 40)
                .padding(.vertical, 6)
                .background(selectedKey == name ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selectedKey == name ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundColor(selectedKey == name ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func modifierToggle(_ label: String, binding: Binding<Bool>) -> some View {
        Button(action: { binding.wrappedValue.toggle() }) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 36)
                .background(binding.wrappedValue
                    ? Color.accentColor.opacity(0.25)
                    : Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(binding.wrappedValue ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(binding.wrappedValue ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "timer", title: "Wait Duration")
            HStack(spacing: 12) {
                TextField("500", text: $delayText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 140)
                    .onSubmit {
                        if let n = Int(delayText), n >= 0 { delayMs = n }
                    }
                Text("ms")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            // Quick presets for delay step
            HStack(spacing: 8) {
                ForEach([100, 250, 500, 1000, 2000, 5000], id: \.self) { preset in
                    Button(action: { delayMs = preset; delayText = "\(preset)" }) {
                        Text("\(preset)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(delayMs == preset ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .foregroundColor(delayMs == preset ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var delayEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "timer", title: "Delay Before This Step")
            HStack(spacing: 8) {
                TextField("500", text: $delayText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15, design: .monospaced))
                    .frame(width: 90)
                    .multilineTextAlignment(.center)
                    .onSubmit {
                        if let n = Int(delayText), n >= 0 { delayMs = n }
                    }
                Text("ms")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                // Quick presets
                ForEach([100, 250, 500, 1000], id: \.self) { preset in
                    Button(action: { delayMs = preset; delayText = "\(preset)" }) {
                        Text("\(preset)")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(delayMs == preset ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .foregroundColor(delayMs == preset ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addStep() {
        // Always sync the text field value before adding
        let finalDelay = Int(delayText) ?? delayMs

        switch selectedCategory {
        case .mouseClick:
            let type: StepType = selectedClick == "left" ? .leftClick : .rightClick
            engine.addStep(MacroStep(type: type, delayMs: finalDelay))
        case .keyboard:
            guard let kc = KeyCodeHelper.keyCode(for: selectedKey) else { return }
            var mods: CGEventFlags = []
            if modCtrl  { mods.insert(.maskControl) }
            if modAlt   { mods.insert(.maskAlternate) }
            if modShift { mods.insert(.maskShift) }
            if modCmd   { mods.insert(.maskCommand) }
            let modStr = (modCtrl ? "⌃" : "") + (modAlt ? "⌥" : "") + (modShift ? "⇧" : "") + (modCmd ? "⌘" : "")
            let step = MacroStep(type: .keyPress(keyCode: kc, modifiers: mods, displayName: modStr + selectedKey), delayMs: finalDelay)
            engine.addStep(step)
        case .delay:
            engine.addStep(MacroStep(type: .delay, delayMs: max(finalDelay, 1)))
        }
        dismiss()
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// MARK: - Sequences Popover

struct SequencesPopover: View {
    @EnvironmentObject var engine: MacroEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Saved Sequences")
                .font(.system(size: 14, weight: .bold))
                .padding()

            Divider().opacity(0.15)

            if engine.savedSequences.isEmpty {
                Text("No saved sequences")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(engine.savedSequences) { seq in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(seq.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("\(seq.steps.count) steps · \(seq.loopMode.displayString)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { engine.loadSequence(seq); dismiss() }) {
                                    Text("Load")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)

                                Button(action: { engine.deleteSequence(seq) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 300, height: 300)
        .background(Color(red: 0.08, green: 0.08, blue: 0.13))
    }
}
