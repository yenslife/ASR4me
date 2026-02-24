import Foundation

protocol ASRService: Sendable {
    func transcribe(audioURL: URL, options: ASROptions) async throws -> TranscriptionResult
}

protocol TextRefinementService: Sendable {
    func refine(text: String, mode: RefinementMode, context: RefinementContext?) async throws -> RefinedTextResult
}

protocol AudioRecordingService: AnyObject {
    func startRecording() async throws
    func stopRecording() async throws -> RecordedAudio
}

protocol HotkeyService: AnyObject {
    var onTrigger: (() -> Void)? { get set }
    func register(_ shortcut: HotkeyShortcut) throws
    func unregister()
}

protocol ClipboardServiceProtocol: Sendable {
    func copy(_ text: String)
}

protocol FocusedTextInsertionServiceProtocol: Sendable {
    func pasteToFocusedElement(_ text: String) async throws
}
