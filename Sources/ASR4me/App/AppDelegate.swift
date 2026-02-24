import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let env = AppEnvironment()

    private var menuBarController: MenuBarController?
    private var resultPanelController: FloatingPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        resultPanelController = FloatingPanelController(
            content: AnyView(
                ResultPanelView()
                    .environmentObject(env.sessionController)
            ),
            title: "ASR Result",
            size: .init(width: 560, height: 480)
        )
        resultPanelController?.onClose = { [weak self] in
            Task { @MainActor in
                self?.env.sessionController.dismissResultPanel()
            }
        }

        settingsWindowController = SettingsWindowController(
            content: AnyView(
                SettingsView()
                    .environmentObject(env)
                    .environmentObject(env.settingsStore)
            )
        )

        menuBarController = MenuBarController(
            session: env.sessionController,
            openSettings: { [weak self] in self?.showSettingsWindow() },
            openResultPanel: { [weak self] in self?.showResultPanel() }
        )

        bindSessionVisibility()
        env.registerHotkey()
    }

    private func bindSessionVisibility() {
        env.sessionController.$isResultPanelVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                guard let self else { return }
                if visible {
                    self.showResultPanel()
                } else {
                    self.resultPanelController?.hide()
                }
            }
            .store(in: &cancellables)

        env.settingsStore.$shortcut
            .dropFirst()
            .sink { [weak self] _ in
                self?.env.persistSettingsAndRebindHotkey()
            }
            .store(in: &cancellables)
    }

    private func showResultPanel() {
        guard let resultPanelController else { return }
        resultPanelController.update(
            content: AnyView(
                ResultPanelView()
                    .environmentObject(env.sessionController)
            )
        )
        resultPanelController.showAndActivate()
    }

    private func showSettingsWindow() {
        settingsWindowController?.update(
            content: AnyView(
                SettingsView()
                    .environmentObject(env)
                    .environmentObject(env.settingsStore)
            )
        )
        settingsWindowController?.show()
    }
}
