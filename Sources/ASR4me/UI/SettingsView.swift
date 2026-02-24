import Carbon
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var settings: SettingsStore
    @State private var apiKeyDraft: String = ""
    @State private var apiKeySaveStatus: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable cloud ASR/LLM by default", isOn: $settings.cloudEnabled)
                Toggle("Play start/stop sounds", isOn: $settings.playStartStopSounds)
                Toggle("Keep recorded audio for debug", isOn: $settings.keepRecordedAudioFilesForDebug)
                Toggle("Quick copy mode (no result window)", isOn: $settings.quickCopySpellingFixMode)
                Toggle("Auto paste to current cursor", isOn: $settings.autoPasteToFocusedCursor)

                TextField("Language hint", text: $settings.defaultLanguagePolicy)
                    .textFieldStyle(.roundedBorder)
                if settings.quickCopySpellingFixMode {
                    Text("錄音完成後會自動做拼字修正並直接複製到剪貼簿。若失敗會跳出錯誤視窗。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if settings.autoPasteToFocusedCursor {
                    Text("錄音完成後會把結果貼到目前游標位置（需要『輔助使用』權限）。啟用時不會跳結果視窗。若同時啟用 Quick copy mode，會先做拼字修正再貼上。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Hotkey", selection: Binding(
                    get: { settings.shortcut.displayName },
                    set: { newValue in
                        if newValue == "Option + Space" {
                            settings.shortcut = .optionSpace
                        } else if newValue == "Control + Space" {
                            settings.shortcut = .init(keyCode: 49, carbonModifiers: UInt32(controlKey), displayName: "Control + Space")
                        }
                    }
                )) {
                    Text("Option + Space").tag("Option + Space")
                    Text("Control + Space").tag("Control + Space")
                }
            }

            Section("OpenAI") {
                SecureField("OpenAI API Key", text: $apiKeyDraft)
                HStack {
                    Button("Save API Key") {
                        do {
                            try settings.setOpenAIAPIKey(apiKeyDraft)
                            apiKeySaveStatus = "Saved to Keychain"
                        } catch {
                            apiKeySaveStatus = error.localizedDescription
                        }
                    }
                    Text(settings.openAIAPIKey == nil ? "No key stored" : "Key stored")
                        .foregroundStyle(.secondary)
                }
                if let apiKeySaveStatus {
                    Text(apiKeySaveStatus).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Local Whisper") {
                Picker("Model", selection: $settings.offlineModelVariant) {
                    ForEach(OfflineModelVariant.allCases) { variant in
                        Text(variant.displayName).tag(variant)
                    }
                }
                TextField(
                    "whisper.cpp binary path",
                    text: $settings.whisperBinaryPath,
                    prompt: Text("/opt/homebrew/bin/whisper-cli (recommended)")
                )
                    .textFieldStyle(.roundedBorder)
                Text("建議預設路徑（Apple Silicon）: /opt/homebrew/bin/whisper-cli；Intel 常見為 /usr/local/bin/whisper-cli")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button(env.isDownloadingModel ? "Downloading…" : "Download Model") {
                        env.downloadSelectedModel()
                    }
                    .disabled(env.isDownloadingModel)

                    Text(env.selectedModelExists ? "Model exists" : "Model missing")
                        .foregroundStyle(.secondary)
                }

                if let status = env.modelDownloadStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Spelling Fix Customization") {
                Text("可輸入你常用的專有名詞、人名、產品名、拼字偏好，提供給 LLM 在「拼字修正」模式使用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $settings.spellingFixCustomizationPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 110)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Text("範例：\n- ASR4me 不要改成 Ask for me\n- Yenslife 是人名/帳號\n- whisper.cpp 保持原樣")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Save Settings") {
                    env.persistSettingsAndRebindHotkey()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 540, height: 520)
        .onAppear {
            apiKeyDraft = settings.openAIAPIKey ?? ""
            env.refreshModelPresence()
        }
    }
}
