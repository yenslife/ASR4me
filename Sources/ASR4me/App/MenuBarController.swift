import AppKit
import Combine
import Foundation

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let session: AppSessionController
    private let openSettings: () -> Void
    private let openResultPanel: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private let toggleItem = NSMenuItem(title: "Start Recording", action: nil, keyEquivalent: "")
    private let openResultItem = NSMenuItem(title: "Open Last Result", action: nil, keyEquivalent: "")

    init(
        session: AppSessionController,
        openSettings: @escaping () -> Void,
        openResultPanel: @escaping () -> Void
    ) {
        self.session = session
        self.openSettings = openSettings
        self.openResultPanel = openResultPanel
        configureMenu()
        bind()
        updateAppearance(for: .idle)
    }

    private func configureMenu() {
        let menu = NSMenu()

        toggleItem.target = self
        toggleItem.action = #selector(toggleRecording)
        menu.addItem(toggleItem)

        openResultItem.target = self
        openResultItem.action = #selector(openLastResult)
        menu.addItem(openResultItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
    }

    private func bind() {
        session.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateAppearance(for: state)
            }
            .store(in: &cancellables)

        session.$currentTranscription
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                self?.openResultItem.isEnabled = (result != nil)
            }
            .store(in: &cancellables)
    }

    private func updateAppearance(for state: AppSessionState) {
        let symbolName: String
        let title: String

        switch state {
        case .idle:
            symbolName = "mic"
            title = "Start Recording"
        case .recording:
            symbolName = "record.circle.fill"
            title = "Stop Recording"
        case .processing:
            symbolName = "hourglass"
            title = "Processing…"
        case .showingResult:
            symbolName = "text.bubble"
            title = "Start Recording"
        case .error:
            symbolName = "exclamationmark.triangle"
            title = "Start Recording"
        }

        toggleItem.title = title
        toggleItem.isEnabled = {
            if case .processing = state { return false }
            return true
        }()

        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ASR4me")
    }

    @objc private func toggleRecording() {
        session.handleHotkeyTrigger()
    }

    @objc private func openLastResult() {
        session.showResultPanel()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
