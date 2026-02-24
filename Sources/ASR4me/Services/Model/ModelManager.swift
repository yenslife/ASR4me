import Foundation

actor ModelManager {
    private let fm = FileManager.default
    private let baseDirectory: URL

    init(appName: String = "ASR4me") {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseDirectory = appSupport.appendingPathComponent("\(appName)/Models", isDirectory: true)
        try? fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    func modelURL(for variant: OfflineModelVariant) -> URL {
        baseDirectory.appendingPathComponent(variant.fileName)
    }

    func hasModel(_ variant: OfflineModelVariant) -> Bool {
        fm.fileExists(atPath: modelURL(for: variant).path)
    }

    func ensureModelExists(_ variant: OfflineModelVariant) throws {
        guard hasModel(variant) else { throw AppError.offlineModelMissing }
    }

    func downloadRecommendedModel(_ variant: OfflineModelVariant) async throws -> URL {
        try await downloadModel(from: variant.defaultDownloadURL, as: variant)
    }

    func downloadModel(from url: URL, as variant: OfflineModelVariant) async throws -> URL {
        try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        let destination = modelURL(for: variant)

        do {
            let (tmpURL, response) = try await URLSession.shared.download(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw AppError.offlineModelDownloadFailed("HTTP error")
            }
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: tmpURL, to: destination)
            return destination
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.offlineModelDownloadFailed(error.localizedDescription)
        }
    }
}
