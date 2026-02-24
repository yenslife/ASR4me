import Foundation

struct ASROrchestrator: ASRService {
    private let cloudService: ASRService
    private let localService: ASRService
    private let settingsProvider: @Sendable () -> UserSettingsSnapshot
    private let network: NetworkReachability

    init(
        cloudService: ASRService,
        localService: ASRService,
        settingsProvider: @escaping @Sendable () -> UserSettingsSnapshot,
        network: NetworkReachability
    ) {
        self.cloudService = cloudService
        self.localService = localService
        self.settingsProvider = settingsProvider
        self.network = network
    }

    func transcribe(audioURL: URL, options: ASROptions) async throws -> TranscriptionResult {
        let settings = settingsProvider()
        let cloudAllowed = options.useCloudPreferred && settings.cloudEnabled && settings.openAIAPIKeyExists
        let online = network.isOnline

        if cloudAllowed && online {
            do {
                return try await cloudService.transcribe(audioURL: audioURL, options: options)
            } catch {
                if options.enableOfflineFallback {
                    return try await localService.transcribe(audioURL: audioURL, options: options)
                }
                throw AppError.cloudASRFailed(error.localizedDescription)
            }
        }

        return try await localService.transcribe(audioURL: audioURL, options: options)
    }
}

