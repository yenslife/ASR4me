import Foundation

struct CloudOpenAIASRService: ASRService {
    private let apiKeyProvider: @Sendable () -> String?
    private let session: URLSession

    init(apiKeyProvider: @escaping @Sendable () -> String?, session: URLSession = .shared) {
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    func transcribe(audioURL: URL, options: ASROptions) async throws -> TranscriptionResult {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw AppError.cloudASRFailed("Missing API key")
        }

        let start = Date()
        let fileData = try Data(contentsOf: audioURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeMultipartBody(fileData: fileData, fileName: audioURL.lastPathComponent, boundary: boundary, options: options)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.cloudASRFailed("Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.cloudASRFailed(parseOpenAIError(from: data) ?? "HTTP \(http.statusCode)")
        }

        let payload = try JSONDecoder().decode(OpenAIWhisperResponse.self, from: data)
        let latency = Int(Date().timeIntervalSince(start) * 1000)
        return TranscriptionResult(
            rawText: payload.text.trimmingCharacters(in: .whitespacesAndNewlines),
            provider: .openAIWhisper,
            latencyMs: latency,
            languageDetected: payload.language
        )
    }

    private func makeMultipartBody(fileData: Data, fileName: String, boundary: String, options: ASROptions) -> Data {
        var data = Data()
        func append(_ string: String) {
            data.append(Data(string.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("whisper-1\r\n")

        let languageCode = extractLanguageCode(from: options.preferredLanguageHint)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        append("\(languageCode)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        append("Bilingual Traditional Chinese and English speech.\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        data.append(fileData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return data
    }

    private func extractLanguageCode(from hint: String) -> String {
        let parts = hint.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first else { return "zh" }
        let code = first.split(separator: "-").first.map(String.init) ?? first
        return code
    }

    private func parseOpenAIError(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = payload["error"] as? [String: Any]
        else {
            return nil
        }
        return error["message"] as? String
    }

    private struct OpenAIWhisperResponse: Decodable {
        let text: String
        let language: String?
    }
}

