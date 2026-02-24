import SwiftUI

struct ResultPanelView: View {
    @EnvironmentObject var session: AppSessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if case .processing = session.state {
                ProgressView("語音辨識中…")
                    .padding(.vertical, 8)
            }

            if let transcription = session.currentTranscription {
                rawTextSection(transcription)
                refineActions
                refinedSection
            }

            if case .error(let error) = session.state {
                Text(error.errorDescription ?? "Unknown error")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if let status = session.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Close") {
                    session.dismissResultPanel()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 360)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ASR4me")
                .font(.title3.weight(.semibold))

            if let result = session.currentTranscription {
                HStack(spacing: 8) {
                    Text("Provider: \(providerName(result.provider))")
                    Text("Latency: \(result.latencyMs)ms")
                    if let lang = result.languageDetected, !lang.isEmpty {
                        Text("Lang: \(lang)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func rawTextSection(_ result: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("原始文字")
                    .font(.headline)
                Spacer()
                Button("Copy Raw") {
                    session.copyRawText()
                }
            }

            ScrollView {
                Text(result.rawText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 110)
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var refineActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文字修飾")
                .font(.headline)
            HStack {
                ForEach([RefinementMode.spellingFix, .formalTone, .conciseRewrite]) { mode in
                    Button(mode.title) {
                        session.refine(mode: mode)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var refinedSection: some View {
        Group {
            if let mode = session.activeRefinementMode,
               let refined = session.refinementResults[mode] {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("修飾結果（\(mode.title)）")
                            .font(.headline)
                        Spacer()
                        Button("Copy Refined") {
                            session.copyRefinedText(mode)
                        }
                    }
                    ScrollView {
                        Text(refined.outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func providerName(_ provider: ASRProvider) -> String {
        switch provider {
        case .openAIWhisper: "OpenAI Whisper"
        case .localWhisper: "Local Whisper"
        }
    }
}

