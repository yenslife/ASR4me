import AVFoundation
import Foundation

final class AVAudioRecorderRecordingService: NSObject, AudioRecordingService {
    private var recorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private let fm = FileManager.default

    func startRecording() async throws {
        try await ensureMicrophonePermission()

        let url = try makeRecordingURL()
        currentRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = false
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw AppError.recordingStartFailed("AVAudioRecorder record() returned false")
            }
            self.recorder = recorder
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.recordingStartFailed(error.localizedDescription)
        }
    }

    func stopRecording() async throws -> RecordedAudio {
        guard let recorder else {
            throw AppError.recordingStartFailed("Recorder not initialized")
        }
        let url = recorder.url
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        return RecordedAudio(fileURL: url, duration: duration)
    }

    private func ensureMicrophonePermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                throw AppError.microphonePermissionDenied
            }
        default:
            throw AppError.microphonePermissionDenied
        }
    }

    private func makeRecordingURL() throws -> URL {
        let caches = try fm.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = caches.appendingPathComponent("ASR4me/Recordings", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let filename = "recording-\(formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).wav"
        return dir.appendingPathComponent(filename)
    }
}
