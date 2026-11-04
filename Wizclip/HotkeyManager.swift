import AppKit
import Carbon
import Foundation

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let defaultShortcut = Hotkey(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    var displayString: String {
        Self.modifierSymbols(carbonModifiers: carbonModifiers) + Self.keyGlyph(for: keyCode)
    }

    var hasPrimaryModifier: Bool {
        carbonModifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    static func load() -> Hotkey {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Hotkey.self, from: data),
              decoded.hasPrimaryModifier,
              !modifierKeyCodes.contains(decoded.keyCode) else {
            return .defaultShortcut
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    static func modifierSymbols(carbonModifiers: UInt32) -> String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    static func modifierSymbols(flags: NSEvent.ModifierFlags) -> String {
        modifierSymbols(carbonModifiers: carbonModifiers(from: flags))
    }

    enum Capture {
        case ignore
        case cancel
        case needsModifier
        case captured(Hotkey)
    }

    static func capture(_ event: NSEvent) -> Capture {
        let keyCode = UInt32(event.keyCode)
        if modifierKeyCodes.contains(keyCode) {
            return .ignore
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let hasPrimary = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
        if keyCode == UInt32(kVK_Escape), !hasPrimary {
            return .cancel
        }
        guard hasPrimary else { return .needsModifier }
        return .captured(Hotkey(keyCode: keyCode, carbonModifiers: carbonModifiers(from: flags)))
    }

    private static let defaultsKey = "Wizclip.globalHotkey"

    private static let modifierKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command),
        UInt32(kVK_Shift),
        UInt32(kVK_CapsLock),
        UInt32(kVK_Option),
        UInt32(kVK_Control),
        UInt32(kVK_RightCommand),
        UInt32(kVK_RightShift),
        UInt32(kVK_RightOption),
        UInt32(kVK_RightControl),
        UInt32(kVK_Function)
    ]

    private static let namedKeys: [UInt32: String] = [
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_Home): "↖",
        UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞",
        UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_ANSI_KeypadEnter): "Keypad ⌅",
        UInt32(kVK_ANSI_KeypadClear): "Keypad ⌧",
        UInt32(kVK_ANSI_KeypadDecimal): "Keypad .",
        UInt32(kVK_ANSI_KeypadEquals): "Keypad =",
        UInt32(kVK_ANSI_KeypadMultiply): "Keypad *",
        UInt32(kVK_ANSI_KeypadPlus): "Keypad +",
        UInt32(kVK_ANSI_KeypadDivide): "Keypad /",
        UInt32(kVK_ANSI_KeypadMinus): "Keypad -",
        UInt32(kVK_ANSI_Keypad0): "Keypad 0",
        UInt32(kVK_ANSI_Keypad1): "Keypad 1",
        UInt32(kVK_ANSI_Keypad2): "Keypad 2",
        UInt32(kVK_ANSI_Keypad3): "Keypad 3",
        UInt32(kVK_ANSI_Keypad4): "Keypad 4",
        UInt32(kVK_ANSI_Keypad5): "Keypad 5",
        UInt32(kVK_ANSI_Keypad6): "Keypad 6",
        UInt32(kVK_ANSI_Keypad7): "Keypad 7",
        UInt32(kVK_ANSI_Keypad8): "Keypad 8",
        UInt32(kVK_ANSI_Keypad9): "Keypad 9",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13",
        UInt32(kVK_F14): "F14",
        UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17",
        UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19",
        UInt32(kVK_F20): "F20"
    ]

    private static func keyGlyph(for keyCode: UInt32) -> String {
        if let named = namedKeys[keyCode] {
            return named
        }
        let translated = translateKey(keyCode)
        if translated.count == 1, let character = translated.first, character.isLetter {
            return String(character).uppercased()
        }
        if !translated.isEmpty, !translated.unicodeScalars.contains(where: { $0.value < 32 }) {
            return translated
        }
        return ansiKeys[keyCode] ?? "Key \(keyCode)"
    }

    private static let ansiKeys: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_RightBracket): "]", UInt32(kVK_ANSI_LeftBracket): "[",
        UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Slash): "/", UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Grave): "`"
    ]

    private static func translateKey(_ keyCode: UInt32) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return ""
        }
        let data = unsafeBitCast(rawLayout, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return "" }
        let layout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(bytes))

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        guard status == noErr, length > 0 else { return "" }
        return String(utf16CodeUnits: chars, count: Int(length))
    }
}

enum HotkeyRecorder {
    private static var monitor: Any?

    static func start(_ handler: @escaping @MainActor (NSEvent) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown, event.isARepeat {
                return nil
            }
            MainActor.assumeIsolated {
                handler(event)
            }
            return nil
        }
    }

    static func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    @discardableResult
    func register(_ hotkey: Hotkey) -> Bool {
        unregister()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyCallback,
            1,
            &spec,
            nil,
            &handlerRef
        )
        guard handlerStatus == noErr else { return false }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("WZCL"), id: 1)
        let keyStatus = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard keyStatus == noErr else {
            unregister()
            return false
        }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for char in string.utf16.prefix(4) {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}

private func carbonHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        HotkeyManager.shared.onHotkey?()
    }
    return noErr
}
