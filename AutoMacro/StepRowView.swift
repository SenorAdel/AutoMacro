//
//  StepRowView.swift
//  AutoMacro+
//
//  Displays a single macro step as an expandable row with reorder, edit, and
//  delete controls. Shows the step type, delay badge, and an inline editor
//  for adjusting delay, click position mode, and fixed coordinates.
//

import SwiftUI

// MARK: - Step Row View

struct StepRowView: View {
    @Binding var step: MacroStep
    let index: Int
    let totalSteps: Int
    let isActive: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded: Bool = false
    @State private var delayText: String = ""
    @State private var xText: String = ""
    @State private var yText: String = ""

    private var isFirst: Bool { index == 0 }
    private var isLast: Bool { index == totalSteps - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header Row ──────────────────────────────────────
            HStack(spacing: 12) {
                // Step number badge
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : .secondary)
                }
                .animation(.spring(response: 0.3), value: isActive)

                // Icon + Label
                HStack(spacing: 8) {
                    Image(systemName: step.type.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(stepColor)
                        .frame(width: 20)

                    Text(step.type.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // Delay badge
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(step.delayMs)ms")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                // Move up/down buttons
                VStack(spacing: 2) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isFirst ? Color.secondary.opacity(0.25) : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFirst)

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isLast ? Color.secondary.opacity(0.25) : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLast)
                }
                .frame(width: 20)

                // Expand toggle
                Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // ── Expanded Editor ──────────────────────────────────
            if isExpanded {
                VStack(spacing: 10) {
                    Divider().opacity(0.2)

                    // Delay control
                    HStack {
                        Label("Delay before step", systemImage: "timer")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("ms", text: $delayText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                if let n = Int(delayText), n >= 0 { step.delayMs = n }
                            }
                        Text("ms")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // Position control (only for click steps)
                    if step.type == .leftClick || step.type == .rightClick {
                        HStack {
                            Label("Click position", systemImage: "cursorarrow")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $step.positionMode) {
                                ForEach(ClickPositionMode.allCases, id: \.self) { mode in
                                    Text(mode == .dynamic ? "Dynamic" : "Fixed")
                                        .tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }

                        if step.positionMode == .fixed {
                            HStack(spacing: 8) {
                                Text("X:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                TextField("0", text: $xText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(width: 70)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .onChange(of: xText) { v in
                                        if let n = Double(v) { step.fixedPosition.x = n }
                                    }
                                Text("Y:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                TextField("0", text: $yText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(width: 70)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .onChange(of: yText) { v in
                                        if let n = Double(v) { step.fixedPosition.y = n }
                                    }

                                Button(action: captureCurrentPosition) {
                                    Label("Capture", systemImage: "scope")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive
                      ? Color.accentColor.opacity(0.15)
                      : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            delayText = "\(step.delayMs)"
            xText = "\(Int(step.fixedPosition.x))"
            yText = "\(Int(step.fixedPosition.y))"
        }
    }

    private var stepColor: Color {
        switch step.type {
        case .leftClick:  return Color(red: 0.35, green: 0.68, blue: 1.0)
        case .rightClick: return Color(red: 0.78, green: 0.45, blue: 1.0)
        case .keyPress:   return Color(red: 0.35, green: 0.90, blue: 0.65)
        case .delay:      return Color(red: 1.0, green: 0.72, blue: 0.3)
        }
    }

    private func captureCurrentPosition() {
        let pos = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        let flippedY = screen.frame.height - pos.y
        step.fixedPosition = CGPoint(x: pos.x, y: flippedY)
        xText = "\(Int(pos.x))"
        yText = "\(Int(flippedY))"
    }
}
