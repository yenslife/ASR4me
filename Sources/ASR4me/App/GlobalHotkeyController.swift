import Carbon
import Foundation

final class GlobalHotkeyController: HotkeyService {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x41535234), id: 1) // "ASR4"

    func register(_ shortcut: HotkeyShortcut) throws {
        unregister()

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let statusInstall = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let controller = Unmanaged<GlobalHotkeyController>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if result == noErr, hotKeyID.id == controller.hotKeyID.id {
                    controller.onTrigger?()
                }
                return noErr
            },
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )

        guard statusInstall == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(statusInstall))
        }

        var keyRef: EventHotKeyRef?
        let statusRegister = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            UInt32(shortcut.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &keyRef
        )
        guard statusRegister == noErr, let keyRef else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(statusRegister))
        }

        hotKeyRef = keyRef
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}

