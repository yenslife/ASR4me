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
        request.httpBody = makeMultipartBody(fileData: fileData, fileName: audioURL.lastPathComponent, boundary: boundary)

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

    private func makeMultipartBody(fileData: Data, fileName: String, boundary: String) -> Data {
        var data = Data()
        func append(_ string: String) {
            data.append(Data(string.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("whisper-1\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        append("zh\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        data.append(fileData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return data
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

