import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let hostingController: NSHostingController<AnyView>
    var onClose: (() -> Void)?

    init(content: AnyView, title: String, size: NSSize) {
        self.panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.hostingController = NSHostingController(rootView: content)
        super.init()

        panel.title = title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.contentViewController = hostingController
    }

    func update(content: AnyView) {
        hostingController.rootView = content
    }

    func showAndActivate() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
