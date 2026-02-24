import Foundation

struct LocalWhisperASRService: ASRService {
    private let settingsProvider: @Sendable () -> UserSettingsSnapshot
    private let modelManager: ModelManager

    init(settingsProvider: @escaping @Sendable () -> UserSettingsSnapshot, modelManager: ModelManager) {
        self.settingsProvider = settingsProvider
        self.modelManager = modelManager
    }

    func transcribe(audioURL: URL, options: ASROptions) async throws -> TranscriptionResult {
        let settings = settingsProvider()
        let variant = settings.offlineModelVariant
        try await modelManager.ensureModelExists(variant)

        guard let binary = settings.whisperBinaryPath, !binary.isEmpty else {
            throw AppError.localASRFailed("請在設定中填入 whisper.cpp 可執行檔路徑（例如 main 或 whisper-cli）")
        }

        let modelURL = await modelManager.modelURL(for: variant)
        let start = Date()
        let baseOutput = audioURL.deletingPathExtension()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = [
            "-m", modelURL.path,
            "-f", audioURL.path,
            "-l", "auto",
            "-otxt",
            "-of", baseOutput.path
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AppError.localASRFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8) ?? "whisper.cpp exit \(process.terminationStatus)"
            throw AppError.localASRFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let txtURL = baseOutput.appendingPathExtension("txt")
        guard let text = try? String(contentsOf: txtURL), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.localASRFailed("找不到辨識輸出文字檔")
        }

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        return TranscriptionResult(
            rawText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            provider: .localWhisper,
            latencyMs: latency,
            languageDetected: nil
        )
    }
}

