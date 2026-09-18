//
//  TargetAppManager.swift
//  AutoMacro+
//
//  Target-app mode. Lets the user pick one running app that the macro sends its
//  key presses to directly (via CGEvent.postToPid), so the app keeps receiving
//  them even when it isn't focused — e.g. a fullscreen game on another Space.
//  Click steps are unaffected and still click normally.
//

import AppKit

// MARK: - Model

/// A running app that can be chosen as the macro target.
struct TargetApp: Identifiable, Equatable {
    let pid: pid_t
    let bundleID: String?
    let name: String
    let icon: NSImage?
    var id: pid_t { pid }
}

// MARK: - Target App Manager

@MainActor
final class TargetAppManager: ObservableObject {

    /// Apps shown in the target picker (regular, user-facing apps only).
    @Published private(set) var runningApps: [TargetApp] = []
    /// The selected target, or nil for "Whole system" (the original behavior).
    @Published private(set) var target: TargetApp?
    /// Problem to show in the UI (e.g. the target quit), or nil when all is well.
    @Published private(set) var statusMessage: String?

    private var observers: [NSObjectProtocol] = []
    private let bundleKey = "targetBundleID"

    init() {
        refreshRunningApps()

        // Restore the last target if it's running.
        if let bundleID = UserDefaults.standard.string(forKey: bundleKey) {
            target = runningApps.first { $0.bundleID == bundleID }
        }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.appsChanged() }
            })
        }
    }

    /// Selects a target app (nil = whole system).
    func select(_ app: TargetApp?) {
        target = app
        UserDefaults.standard.set(app?.bundleID, forKey: bundleKey)
        statusMessage = nil
    }

    // MARK: - Private

    private func appsChanged() {
        refreshRunningApps()
        // Target quit → fall back to whole-system mode.
        if let target, !runningApps.contains(where: { $0.pid == target.pid }) {
            self.target = nil
            statusMessage = "\(target.name) quit — target cleared"
        }
    }

    private func refreshRunningApps() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .map { app in
                let icon = app.icon?.copy() as? NSImage
                icon?.size = NSSize(width: 16, height: 16)
                return TargetApp(pid: app.processIdentifier,
                                 bundleID: app.bundleIdentifier,
                                 name: app.localizedName ?? "Unknown",
                                 icon: icon)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
