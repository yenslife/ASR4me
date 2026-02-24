import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow
    private let hostingController: NSHostingController<AnyView>

    init(content: AnyView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ASR4me Settings"
        window.isReleasedWhenClosed = false
        self.window = window
        self.hostingController = NSHostingController(rootView: content)
        window.contentViewController = hostingController
    }

    func update(content: AnyView) {
        hostingController.rootView = content
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

