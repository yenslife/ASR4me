import Foundation

struct OpenAILLMRefinementService: TextRefinementService {
    private let apiKeyProvider: @Sendable () -> String?
    private let session: URLSession

    init(apiKeyProvider: @escaping @Sendable () -> String?, session: URLSession = .shared) {
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    func refine(text: String, mode: RefinementMode, context: RefinementContext?) async throws -> RefinedTextResult {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw AppError.llmRefinementFailed("Missing API key")
        }

        let payload = ChatCompletionsRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(role: "system", content: systemPrompt(for: mode, context: context)),
                .init(role: "user", content: text)
            ],
            temperature: 0.2
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.llmRefinementFailed("Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.llmRefinementFailed(parseOpenAIError(from: data) ?? "HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AppError.llmRefinementFailed("Empty model output")
        }
        return RefinedTextResult(mode: mode, outputText: content)
    }

    private func systemPrompt(for mode: RefinementMode, context: RefinementContext?) -> String {
        var prompt = "You are a text post-processor for speech transcription. Preserve meaning, names, and bilingual Chinese/English terms. Output only the rewritten text."
        if let hint = context?.preferredLanguageHint {
            prompt += " Preferred language hint: \(hint)."
        }
        if let custom = context?.userCustomizationPrompt, !custom.isEmpty {
            prompt += " User customization (must follow when applicable, especially for names/terms): \(custom)"
        }
        prompt += " Task: \(mode.instruction)"
        return prompt
    }

    private func parseOpenAIError(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = payload["error"] as? [String: Any]
        else {
            return nil
        }
        return error["message"] as? String
    }
}

private struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
