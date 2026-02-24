import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let settingsStore: SettingsStore
    let sessionController: AppSessionController
    let modelManager: ModelManager
    let hotkeyController: GlobalHotkeyController
    let networkReachability: NetworkReachability

    @Published var modelDownloadStatus: String?
    @Published var isDownloadingModel = false
    @Published var selectedModelExists = false

    init() {
        let settingsStore = SettingsStore()
        let modelManager = ModelManager()
        let hotkeyController = GlobalHotkeyController()
        let networkReachability = NetworkReachability()

        let fallbackSnapshot = UserSettingsSnapshot(
            shortcut: .optionSpace,
            cloudEnabled: true,
            openAIAPIKeyExists: false,
            defaultLanguagePolicy: "zh-Hant,en",
            offlineModelVariant: .small,
            playStartStopSounds: true,
            whisperBinaryPath: nil,
            quickCopySpellingFixMode: false,
            autoPasteToFocusedCursor: false,
            autoPasteContentMode: .spellingFix
        )

        let cloudASR = CloudOpenAIASRService(apiKeyProvider: { [weak settingsStore] in
            settingsStore?.openAIAPIKey
        })

        let localASR = LocalWhisperASRService(settingsProvider: { [weak settingsStore] in
            settingsStore?.snapshot ?? fallbackSnapshot
        }, modelManager: modelManager)

        let orchestrator = ASROrchestrator(
            cloudService: cloudASR,
            localService: localASR,
            settingsProvider: { [weak settingsStore] in
                settingsStore?.snapshot ?? fallbackSnapshot
            },
            network: networkReachability
        )

        let refinementService = OpenAILLMRefinementService(apiKeyProvider: { [weak settingsStore] in
            settingsStore?.openAIAPIKey
        })

        let sessionController = AppSessionController(
            audioService: AVAudioRecorderRecordingService(),
            promptSoundPlayer: PromptSoundPlayer(),
            asrOrchestrator: orchestrator,
            refinementService: refinementService,
            clipboardService: ClipboardService(),
            focusedTextInsertionService: FocusedTextInsertionService(),
            settingsStore: settingsStore
        )

        self.settingsStore = settingsStore
        self.sessionController = sessionController
        self.modelManager = modelManager
        self.hotkeyController = hotkeyController
        self.networkReachability = networkReachability

        hotkeyController.onTrigger = { [weak sessionController] in
            Task { @MainActor in
                sessionController?.handleHotkeyTrigger()
            }
        }

        refreshModelPresence()
    }

    func registerHotkey() {
        do {
            try hotkeyController.register(settingsStore.shortcut)
        } catch {
            sessionController.clearStatusMessage()
        }
    }

    func persistSettingsAndRebindHotkey() {
        settingsStore.persist()
        do {
            try hotkeyController.register(settingsStore.shortcut)
        } catch {
            sessionController.clearStatusMessage()
        }
    }

    func downloadSelectedModel() {
        guard !isDownloadingModel else { return }
        isDownloadingModel = true
        modelDownloadStatus = "下載模型中…"

        let variant = settingsStore.offlineModelVariant
        Task {
            do {
                _ = try await modelManager.downloadRecommendedModel(variant)
                await MainActor.run {
                    self.modelDownloadStatus = "模型下載完成：\(variant.displayName)"
                    self.isDownloadingModel = false
                    self.selectedModelExists = true
                }
            } catch {
                await MainActor.run {
                    self.modelDownloadStatus = (error as? AppError)?.errorDescription ?? error.localizedDescription
                    self.isDownloadingModel = false
                }
            }
        }
    }

    func refreshModelPresence() {
        let variant = settingsStore.offlineModelVariant
        Task {
            let exists = await modelManager.hasModel(variant)
            await MainActor.run {
                self.selectedModelExists = exists
            }
        }
    }
}
