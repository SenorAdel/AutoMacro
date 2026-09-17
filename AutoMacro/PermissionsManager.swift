//
//  PermissionsManager.swift
//  AutoMacro+
//
//  Manages Accessibility permission state. Polls every second until permission
//  is granted so the UI can react when the user toggles it in System Settings.
//  Accessibility is required for CGEvent-based mouse/keyboard simulation.
//

import Foundation
import ApplicationServices

final class PermissionsManager: ObservableObject {

    /// Whether the app currently has Accessibility permission.
    @Published var hasAccessibilityPermission: Bool = false

    private var pollTimer: Timer?

    init() {
        checkPermission()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Checks if the process is trusted for Accessibility (without prompting).
    func checkPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    /// Checks and prompts the user to grant Accessibility if not already granted.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    /// Polls every 1 second until Accessibility is granted, then stops.
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            self?.checkPermission()
            if self?.hasAccessibilityPermission == true {
                timer.invalidate()
                self?.pollTimer = nil
            }
        }
    }
}
