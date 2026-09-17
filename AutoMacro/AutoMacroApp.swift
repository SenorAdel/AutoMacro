//
//  AutoMacroApp.swift
//  AutoMacro+
//
//  Main app entry point. Creates the shared state objects (engine, hotkey manager,
//  permissions) and wires the global hotkey callbacks to the macro engine.
//

import SwiftUI

@main
struct AutoMacroApp: App {
    @StateObject private var engine = MacroEngine()
    @StateObject private var hotkeyManager = GlobalHotkeyManager()
    @StateObject private var permissions = PermissionsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(hotkeyManager)
                .environmentObject(permissions)
                .onAppear {
                    // Wire global hotkey callbacks to engine actions
                    hotkeyManager.onToggle = { [weak engine] in
                        engine?.toggleExecution()
                    }
                    hotkeyManager.onRecordToggle = { [weak engine] in
                        engine?.toggleRecording()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // Disable ⌘N
        }
    }
}
