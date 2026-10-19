import Carbon
import Foundation

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        unregister()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyCallback,
            1,
            &spec,
            nil,
            &handlerRef
        )
        guard status == noErr else { return }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("WZCL"), id: 1)
        // ⌘⇧V — the closest Mac equivalent of Win+V
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotKeyRef = ref
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
