import Combine
import Foundation

@MainActor
final class AppSessionController: ObservableObject {
    @Published private(set) var state: AppSessionState = .idle
    @Published private(set) var currentTranscription: TranscriptionResult?
    @Published private(set) var refinementResults: [RefinementMode: RefinedTextResult] = [:]
    @Published private(set) var activeRefinementMode: RefinementMode?
    @Published private(set) var isResultPanelVisible = false
    @Published private(set) var statusMessage: String?

    private let audioService: AudioRecordingService
    private let promptSoundPlayer: PromptSoundPlaying
    private let asrOrchestrator: ASROrchestrator
    private let refinementService: TextRefinementService
    private let clipboardService: ClipboardServiceProtocol
    private let focusedTextInsertionService: FocusedTextInsertionServiceProtocol
    private let settingsStore: SettingsStore

    init(
        audioService: AudioRecordingService,
        promptSoundPlayer: PromptSoundPlaying,
        asrOrchestrator: ASROrchestrator,
        refinementService: TextRefinementService,
        clipboardService: ClipboardServiceProtocol,
        focusedTextInsertionService: FocusedTextInsertionServiceProtocol,
        settingsStore: SettingsStore
    ) {
        self.audioService = audioService
        self.promptSoundPlayer = promptSoundPlayer
        self.asrOrchestrator = asrOrchestrator
        self.refinementService = refinementService
        self.clipboardService = clipboardService
        self.focusedTextInsertionService = focusedTextInsertionService
        self.settingsStore = settingsStore
    }

    func handleHotkeyTrigger() {
        switch state {
        case .idle, .showingResult, .error:
            Task { await startRecordingFlow() }
        case .recording:
            Task { await stopRecordingAndTranscribeFlow() }
        case .processing:
            statusMessage = AppError.busy.errorDescription
        }
    }

    func copyRawText() {
        guard let text = currentTranscription?.rawText else { return }
        clipboardService.copy(text)
        statusMessage = "已複製原始文字"
    }

    func copyRefinedText(_ mode: RefinementMode) {
        guard let text = refinementResults[mode]?.outputText else { return }
        clipboardService.copy(text)
        statusMessage = "已複製 \(mode.title)"
    }

    func refine(mode: RefinementMode) {
        guard let baseText = currentTranscription?.rawText else { return }
        if let existing = refinementResults[mode] {
            activeRefinementMode = existing.mode
            return
        }

        statusMessage = "正在執行 \(mode.title)…"
        Task {
            do {
                let result = try await refinementService.refine(
                    text: baseText,
                    mode: mode,
                    context: refinementContext(for: mode)
                )
                refinementResults[mode] = result
                activeRefinementMode = mode
                statusMessage = "\(mode.title)完成"
            } catch let error as AppError {
                state = .error(error)
                statusMessage = error.errorDescription
            } catch {
                let wrapped = AppError.llmRefinementFailed(error.localizedDescription)
                state = .error(wrapped)
                statusMessage = wrapped.errorDescription
            }
        }
    }

    func dismissResultPanel() {
        isResultPanelVisible = false
    }

    func showResultPanel() {
        isResultPanelVisible = true
    }

    func clearStatusMessage() {
        statusMessage = nil
    }

    private func startRecordingFlow() async {
        do {
            if settingsStore.playStartStopSounds {
                promptSoundPlayer.playStartSound()
            }
            try await audioService.startRecording()
            currentTranscription = nil
            refinementResults = [:]
            activeRefinementMode = nil
            statusMessage = "錄音中…"
            state = .recording(startedAt: Date())
        } catch let error as AppError {
            state = .error(error)
            statusMessage = error.errorDescription
        } catch {
            let wrapped = AppError.recordingStartFailed(error.localizedDescription)
            state = .error(wrapped)
            statusMessage = wrapped.errorDescription
        }
    }

    private func stopRecordingAndTranscribeFlow() async {
        do {
            let recorded = try await audioService.stopRecording()
            if settingsStore.playStartStopSounds {
                promptSoundPlayer.playStopSound()
            }
            if recorded.duration < 0.15 {
                throw AppError.emptyAudio
            }

            statusMessage = "語音辨識中…"
            state = .processing(audioURL: recorded.fileURL)
            if !settingsStore.quickCopySpellingFixMode && !settingsStore.autoPasteToFocusedCursor {
                isResultPanelVisible = true
            }

            let options = ASROptions(
                preferredLanguageHint: settingsStore.defaultLanguagePolicy,
                useCloudPreferred: settingsStore.cloudEnabled,
                enableOfflineFallback: true
            )

            let transcription = try await asrOrchestrator.transcribe(audioURL: recorded.fileURL, options: options)
            currentTranscription = transcription
            state = .showingResult(transcription)

            if settingsStore.quickCopySpellingFixMode {
                let refined = try await spellingFix(text: transcription.rawText)
                refinementResults[.spellingFix] = refined
                activeRefinementMode = .spellingFix
                try await deliverOutputText(refined.outputText, message: "已拼字修正")
            } else {
                if settingsStore.autoPasteToFocusedCursor {
                    switch settingsStore.autoPasteContentMode {
                    case .rawTranscription:
                        try await deliverOutputText(transcription.rawText, message: "已轉寫")
                    case .spellingFix:
                        let refined = try await spellingFix(text: transcription.rawText)
                        refinementResults[.spellingFix] = refined
                        activeRefinementMode = .spellingFix
                        try await deliverOutputText(refined.outputText, message: "已拼字修正")
                    }
                } else {
                    statusMessage = "辨識完成"
                }
            }

            if !settingsStore.keepRecordedAudioFilesForDebug {
                try? FileManager.default.removeItem(at: recorded.fileURL)
            }
        } catch let error as AppError {
            state = .error(error)
            isResultPanelVisible = true
            statusMessage = error.errorDescription
        } catch {
            let wrapped = AppError.cloudASRFailed(error.localizedDescription)
            state = .error(wrapped)
            isResultPanelVisible = true
            statusMessage = wrapped.errorDescription
        }
    }

    private func refinementContext(for mode: RefinementMode) -> RefinementContext {
        let customPrompt: String?
        if mode == .spellingFix {
            let trimmed = settingsStore.spellingFixCustomizationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            customPrompt = trimmed.isEmpty ? nil : trimmed
        } else {
            customPrompt = nil
        }

        return .init(
            preferredLanguageHint: settingsStore.defaultLanguagePolicy,
            userCustomizationPrompt: customPrompt
        )
    }

    private func spellingFix(text: String) async throws -> RefinedTextResult {
        do {
            return try await refinementService.refine(
                text: text,
                mode: .spellingFix,
                context: refinementContext(for: .spellingFix)
            )
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.llmRefinementFailed(error.localizedDescription)
        }
    }

    private func deliverOutputText(_ text: String, message: String) async throws {
        if settingsStore.autoPasteToFocusedCursor {
            try await focusedTextInsertionService.pasteToFocusedElement(text)
            isResultPanelVisible = false
            statusMessage = "\(message)並貼到目前游標位置"
        } else {
            clipboardService.copy(text)
            isResultPanelVisible = false
            statusMessage = "\(message)並複製到剪貼簿"
        }
    }
}
