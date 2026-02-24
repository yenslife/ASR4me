import AppKit
import ApplicationServices
import Foundation

struct FocusedTextInsertionService: FocusedTextInsertionServiceProtocol {
    func pasteToFocusedElement(_ text: String) async throws {
        guard isAccessibilityTrusted(promptIfNeeded: true) else {
            throw AppError.accessibilityPermissionDenied
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Give the pasteboard a moment to propagate before posting Cmd+V.
        try? await Task.sleep(nanoseconds: 80_000_000)
        try sendCommandV()
    }

    private func isAccessibilityTrusted(promptIfNeeded: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func sendCommandV() throws {
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),  // V
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            throw AppError.accessibilityPermissionDenied
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
