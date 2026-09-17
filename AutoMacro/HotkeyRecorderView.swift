//
//  HotkeyRecorderView.swift
//  AutoMacro+
//
//  A reusable SwiftUI view for displaying and configuring a global hotkey.
//  Supports both the Start/Stop and Record hotkey slots.
//

import SwiftUI

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @EnvironmentObject var hotkeyManager: GlobalHotkeyManager
    var slot: HotkeySlot = .start

    private var currentHotkey: RecordedHotkey {
        switch slot {
        case .start:  return hotkeyManager.startHotkey
        case .record: return hotkeyManager.recordHotkey
        }
    }

    private var isEditing: Bool {
        hotkeyManager.isRecordingHotkey && hotkeyManager.editingSlot == slot
    }

    private var defaultLabel: String {
        switch slot {
        case .start:  return "⌃⌥S"
        case .record: return "⌃⌥R"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Current hotkey display
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if isEditing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .controlSize(.mini)
                        Text("Press shortcut…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.accentColor)
                    }
                } else {
                    Text(currentHotkey.displayString)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .frame(minWidth: 110)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEditing
                          ? Color.accentColor.opacity(0.15)
                          : Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEditing
                                    ? Color.accentColor.opacity(0.5)
                                    : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )

            // Change button
            Button(action: {
                if isEditing {
                    hotkeyManager.isRecordingHotkey = false
                } else {
                    hotkeyManager.startRecording(slot: slot)
                }
            }) {
                Text(isEditing ? "Cancel" : "Change")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // Reset to default
            Button(action: { hotkeyManager.resetToDefault(slot: slot) }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reset to \(defaultLabel)")
        }
    }
}
