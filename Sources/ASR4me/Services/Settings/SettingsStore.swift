import Combine
import Foundation

final class SettingsStore: ObservableObject, @unchecked Sendable {
    @Published var shortcut: HotkeyShortcut
    @Published var cloudEnabled: Bool
    @Published var defaultLanguagePolicy: String
    @Published var offlineModelVariant: OfflineModelVariant
    @Published var playStartStopSounds: Bool
    @Published var keepRecordedAudioFilesForDebug: Bool
    @Published var whisperBinaryPath: String
    @Published var quickCopySpellingFixMode: Bool
    @Published var autoPasteToFocusedCursor: Bool
    @Published var autoPasteContentMode: AutoPasteContentMode
    @Published var spellingFixCustomizationPrompt: String

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.shortcut = Self.loadShortcut(defaults: defaults)
        self.cloudEnabled = defaults.object(forKey: Keys.cloudEnabled) as? Bool ?? true
        self.defaultLanguagePolicy = defaults.string(forKey: Keys.languagePolicy) ?? "zh-Hant,en"
        self.offlineModelVariant = OfflineModelVariant(rawValue: defaults.string(forKey: Keys.offlineModelVariant) ?? "") ?? .small
        self.playStartStopSounds = defaults.object(forKey: Keys.playSounds) as? Bool ?? true
        self.keepRecordedAudioFilesForDebug = defaults.object(forKey: Keys.keepRecordings) as? Bool ?? false
        self.whisperBinaryPath = defaults.string(forKey: Keys.whisperBinaryPath) ?? Self.recommendedWhisperBinaryPath()
        self.quickCopySpellingFixMode = defaults.object(forKey: Keys.quickCopySpellingFixMode) as? Bool ?? false
        self.autoPasteToFocusedCursor = defaults.object(forKey: Keys.autoPasteToFocusedCursor) as? Bool ?? false
        self.autoPasteContentMode = AutoPasteContentMode(rawValue: defaults.string(forKey: Keys.autoPasteContentMode) ?? "") ?? .spellingFix
        self.spellingFixCustomizationPrompt = defaults.string(forKey: Keys.spellingFixCustomizationPrompt) ?? ""
    }

    var openAIAPIKey: String? {
        KeychainHelper.loadOpenAIAPIKey()
    }

    var snapshot: UserSettingsSnapshot {
        .init(
            shortcut: shortcut,
            cloudEnabled: cloudEnabled,
            openAIAPIKeyExists: !(openAIAPIKey?.isEmpty ?? true),
            defaultLanguagePolicy: defaultLanguagePolicy,
            offlineModelVariant: offlineModelVariant,
            playStartStopSounds: playStartStopSounds,
            whisperBinaryPath: whisperBinaryPath.isEmpty ? nil : whisperBinaryPath,
            quickCopySpellingFixMode: quickCopySpellingFixMode,
            autoPasteToFocusedCursor: autoPasteToFocusedCursor,
            autoPasteContentMode: autoPasteContentMode
        )
    }

    func setOpenAIAPIKey(_ value: String) throws {
        try KeychainHelper.saveOpenAIAPIKey(value)
        objectWillChange.send()
    }

    func persist() {
        defaults.set(cloudEnabled, forKey: Keys.cloudEnabled)
        defaults.set(defaultLanguagePolicy, forKey: Keys.languagePolicy)
        defaults.set(offlineModelVariant.rawValue, forKey: Keys.offlineModelVariant)
        defaults.set(playStartStopSounds, forKey: Keys.playSounds)
        defaults.set(keepRecordedAudioFilesForDebug, forKey: Keys.keepRecordings)
        defaults.set(whisperBinaryPath, forKey: Keys.whisperBinaryPath)
        defaults.set(quickCopySpellingFixMode, forKey: Keys.quickCopySpellingFixMode)
        defaults.set(autoPasteToFocusedCursor, forKey: Keys.autoPasteToFocusedCursor)
        defaults.set(autoPasteContentMode.rawValue, forKey: Keys.autoPasteContentMode)
        defaults.set(spellingFixCustomizationPrompt, forKey: Keys.spellingFixCustomizationPrompt)
        defaults.set(shortcut.keyCode, forKey: Keys.shortcutKeyCode)
        defaults.set(shortcut.carbonModifiers, forKey: Keys.shortcutModifiers)
        defaults.set(shortcut.displayName, forKey: Keys.shortcutName)
    }

    private static func loadShortcut(defaults: UserDefaults) -> HotkeyShortcut {
        guard
            defaults.object(forKey: Keys.shortcutKeyCode) != nil,
            defaults.object(forKey: Keys.shortcutModifiers) != nil
        else {
            return .optionSpace
        }

        return HotkeyShortcut(
            keyCode: UInt32(defaults.integer(forKey: Keys.shortcutKeyCode)),
            carbonModifiers: UInt32(defaults.integer(forKey: Keys.shortcutModifiers)),
            displayName: defaults.string(forKey: Keys.shortcutName) ?? HotkeyShortcut.optionSpace.displayName
        )
    }

    private enum Keys {
        static let cloudEnabled = "cloudEnabled"
        static let languagePolicy = "defaultLanguagePolicy"
        static let offlineModelVariant = "offlineModelVariant"
        static let playSounds = "playStartStopSounds"
        static let keepRecordings = "keepRecordedAudioFilesForDebug"
        static let whisperBinaryPath = "whisperBinaryPath"
        static let quickCopySpellingFixMode = "quickCopySpellingFixMode"
        static let autoPasteToFocusedCursor = "autoPasteToFocusedCursor"
        static let autoPasteContentMode = "autoPasteContentMode"
        static let spellingFixCustomizationPrompt = "spellingFixCustomizationPrompt"
        static let shortcutKeyCode = "shortcut.keyCode"
        static let shortcutModifiers = "shortcut.modifiers"
        static let shortcutName = "shortcut.displayName"
    }

    private static func recommendedWhisperBinaryPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/bin/main",
            "/usr/local/bin/whisper-cli",
            "/usr/local/bin/main"
        ]
        let fm = FileManager.default
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) }) ?? "/opt/homebrew/bin/whisper-cli"
    }
}
