import Carbon
import Foundation

enum ASRProvider: String, Codable, Sendable {
    case openAIWhisper
    case localWhisper
}

enum RefinementMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case spellingFix
    case formalTone
    case conciseRewrite
    case customPrompt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spellingFix: "拼字修正"
        case .formalTone: "正式口吻"
        case .conciseRewrite: "精簡重寫"
        case .customPrompt: "自訂"
        }
    }

    var instruction: String {
        switch self {
        case .spellingFix:
            return "Correct spelling and punctuation mistakes while preserving the original meaning and mixed Chinese/English terms."
        case .formalTone:
            return "Rewrite the text in a professional and formal tone. Keep the original meaning."
        case .conciseRewrite:
            return "Rewrite the text to be concise and clear while preserving meaning."
        case .customPrompt:
            return "Refine the text."
        }
    }
}

struct ASROptions: Sendable {
    var preferredLanguageHint: String = "zh-Hant,en"
    var useCloudPreferred: Bool = true
    var enableOfflineFallback: Bool = true
}

struct TranscriptionResult: Sendable {
    let rawText: String
    let provider: ASRProvider
    let latencyMs: Int
    let languageDetected: String?
}

struct RefinementContext: Sendable {
    let preferredLanguageHint: String?
    let userCustomizationPrompt: String?
}

struct RefinedTextResult: Sendable {
    let mode: RefinementMode
    let outputText: String
}

struct RecordedAudio: Sendable {
    let fileURL: URL
    let duration: TimeInterval
}

enum OfflineModelVariant: String, CaseIterable, Codable, Identifiable {
    case base
    case small

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .base: "ggml-base.bin"
        case .small: "ggml-small.bin"
        }
    }

    var displayName: String { rawValue.capitalized }

    var defaultDownloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }
}

enum AutoPasteContentMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case rawTranscription
    case spellingFix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rawTranscription: "原始轉寫"
        case .spellingFix: "拼字修正版本"
        }
    }
}

struct HotkeyShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let displayName: String

    static let optionSpace = HotkeyShortcut(
        keyCode: 49, // space
        carbonModifiers: UInt32(optionKey),
        displayName: "Option + Space"
    )
}

struct UserSettingsSnapshot: Sendable {
    let shortcut: HotkeyShortcut
    let cloudEnabled: Bool
    let openAIAPIKeyExists: Bool
    let defaultLanguagePolicy: String
    let offlineModelVariant: OfflineModelVariant
    let playStartStopSounds: Bool
    let whisperBinaryPath: String?
    let quickCopySpellingFixMode: Bool
    let autoPasteToFocusedCursor: Bool
    let autoPasteContentMode: AutoPasteContentMode
}

enum AppError: Error, LocalizedError, Sendable {
    case microphonePermissionDenied
    case recordingStartFailed(String)
    case emptyAudio
    case networkUnavailable
    case cloudASRFailed(String)
    case offlineModelMissing
    case offlineModelDownloadFailed(String)
    case localASRFailed(String)
    case llmRefinementFailed(String)
    case accessibilityPermissionDenied
    case busy

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "麥克風權限未授權。"
        case .recordingStartFailed(let msg):
            return "無法開始錄音：\(msg)"
        case .emptyAudio:
            return "錄音內容太短或為空。"
        case .networkUnavailable:
            return "目前沒有網路連線。"
        case .cloudASRFailed(let msg):
            return "雲端語音辨識失敗：\(msg)"
        case .offlineModelMissing:
            return "找不到本機 Whisper 模型，請先下載模型。"
        case .offlineModelDownloadFailed(let msg):
            return "模型下載失敗：\(msg)"
        case .localASRFailed(let msg):
            return "本機語音辨識失敗：\(msg)"
        case .llmRefinementFailed(let msg):
            return "文字修飾失敗：\(msg)"
        case .accessibilityPermissionDenied:
            return "需要『輔助使用』權限才能自動貼到目前游標位置。"
        case .busy:
            return "目前仍在處理中，請稍後再試。"
        }
    }
}

enum AppSessionState: Sendable {
    case idle
    case recording(startedAt: Date)
    case processing(audioURL: URL)
    case showingResult(TranscriptionResult)
    case error(AppError)
}
