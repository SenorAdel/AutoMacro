//
//  MacroStep.swift
//  AutoMacro+
//
//  Data models for the macro system. Defines step types (mouse clicks, key presses,
//  delays), macro sequences, loop modes, and key code mappings. All models are
//  Codable for JSON persistence via UserDefaults.
//

import Foundation
import CoreGraphics

// MARK: - Step Type

/// The type of action a macro step performs.
enum StepType: Codable, Equatable {
    case leftClick
    case rightClick
    case middleClick
    case keyPress(keyCode: CGKeyCode, modifiers: CGEventFlags, displayName: String)
    case delay  // Pure delay — no action, just waits

    /// Human-readable label for the step type.
    var displayName: String {
        switch self {
        case .leftClick:    return "Left Click"
        case .rightClick:   return "Right Click"
        case .middleClick:  return "Middle Click"
        case .keyPress(_, _, let name): return "Key: \(name)"
        case .delay:        return "Delay"
        }
    }

    /// SF Symbol icon name for the step type.
    var icon: String {
        switch self {
        case .leftClick:    return "cursorarrow.click"
        case .rightClick:   return "cursorarrow.click.2"
        case .middleClick:  return "computermouse"
        case .keyPress:     return "keyboard"
        case .delay:        return "timer"
        }
    }

    /// Whether this step is a mouse click (of any button).
    var isClick: Bool {
        switch self {
        case .leftClick, .rightClick, .middleClick: return true
        case .keyPress, .delay:                     return false
        }
    }

    // MARK: Custom Codable (needed because of associated values)

    private enum CodingKeys: String, CodingKey {
        case type, keyCode, modifiers, displayName
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .leftClick:
            try c.encode("leftClick", forKey: .type)
        case .rightClick:
            try c.encode("rightClick", forKey: .type)
        case .middleClick:
            try c.encode("middleClick", forKey: .type)
        case .keyPress(let kc, let mods, let name):
            try c.encode("keyPress", forKey: .type)
            try c.encode(kc, forKey: .keyCode)
            try c.encode(mods.rawValue, forKey: .modifiers)
            try c.encode(name, forKey: .displayName)
        case .delay:
            try c.encode("delay", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "leftClick":  self = .leftClick
        case "rightClick": self = .rightClick
        case "middleClick": self = .middleClick
        case "keyPress":
            let kc   = try c.decode(CGKeyCode.self, forKey: .keyCode)
            let mods = try c.decode(UInt64.self, forKey: .modifiers)
            let name = try c.decode(String.self, forKey: .displayName)
            self = .keyPress(keyCode: kc, modifiers: CGEventFlags(rawValue: mods), displayName: name)
        default:
            self = .delay
        }
    }
}

// MARK: - Click Position Mode

/// Whether a click step uses the current cursor position or a fixed coordinate.
enum ClickPositionMode: String, Codable, CaseIterable {
    case dynamic    = "Dynamic (cursor position)"
    case fixed      = "Fixed coordinate"
}

// MARK: - Macro Step

/// A single step in a macro sequence.
struct MacroStep: Identifiable, Codable {
    var id: UUID = UUID()
    var type: StepType
    /// Delay in milliseconds BEFORE this step fires.
    var delayMs: Int = 500
    /// Screen coordinate for fixed-position clicks.
    var fixedPosition: CGPoint = .zero
    /// Whether the click uses the current cursor or a fixed coordinate.
    var positionMode: ClickPositionMode = .dynamic

    init(type: StepType, delayMs: Int = 500) {
        self.type = type
        self.delayMs = delayMs
    }
}

// MARK: - Loop Mode

/// How many times the macro sequence repeats.
enum LoopMode: Codable, Equatable {
    case infinite
    case count(Int)

    var displayString: String {
        switch self {
        case .infinite:       return "∞"
        case .count(let n):   return "\(n)×"
        }
    }

    private enum CodingKeys: String, CodingKey { case mode, count }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .infinite:
            try c.encode("infinite", forKey: .mode)
        case .count(let n):
            try c.encode("count", forKey: .mode)
            try c.encode(n, forKey: .count)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try c.decode(String.self, forKey: .mode)
        if mode == "infinite" { self = .infinite }
        else { self = .count(try c.decode(Int.self, forKey: .count)) }
    }
}

// MARK: - Saved Sequence

/// A named, persistable macro sequence with its steps and loop configuration.
struct MacroSequence: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var steps: [MacroStep]
    var loopMode: LoopMode
    var createdAt: Date = Date()
}

// MARK: - Key Code Helpers

/// Maps human-readable key names to macOS virtual key codes (CGKeyCode).
struct KeyCodeHelper {
    static let map: [(name: String, keyCode: CGKeyCode)] = [
        // Letters
        ("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3),
        ("G", 5), ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37),
        ("M", 46), ("N", 45), ("O", 31), ("P", 35), ("Q", 12), ("R", 15),
        ("S", 1), ("T", 17), ("U", 32), ("V", 9), ("W", 13), ("X", 7),
        ("Y", 16), ("Z", 6),
        // Numbers
        ("0", 29), ("1", 18), ("2", 19), ("3", 20), ("4", 21),
        ("5", 23), ("6", 22), ("7", 26), ("8", 28), ("9", 25),
        // Special keys
        ("Space", 49), ("Return", 36), ("Tab", 48), ("Escape", 53),
        ("Delete", 51), ("F1", 122), ("F2", 120), ("F3", 99), ("F4", 118),
        ("F5", 96), ("F6", 97), ("F7", 98), ("F8", 100),
        // Arrow keys
        ("↑ Up", 126), ("↓ Down", 125), ("← Left", 123), ("→ Right", 124),
    ]

    /// Returns the virtual key code for a given key name, or nil if not found.
    static func keyCode(for name: String) -> CGKeyCode? {
        map.first { $0.name == name }?.keyCode
    }
}
