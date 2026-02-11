import AVFoundation
import AudioToolbox
import Foundation

public final class AudioHoldRecorder {
    public enum RecorderError: Error {
        case alreadyRecording
        case notRecording
        case recorderInitFailed
        case startFailed
        case stopFailed
    }

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    public init() {}

    public var isRecording: Bool { recorder?.isRecording ?? false }

    public func start() throws {
        guard recorder == nil else { throw RecorderError.alreadyRecording }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcribe-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
            throw RecorderError.recorderInitFailed
        }

        recorder.isMeteringEnabled = false

        guard recorder.record() else {
            throw RecorderError.startFailed
        }

        self.currentURL = url
        self.recorder = recorder
    }

    public func stop() throws -> URL {
        guard let recorder else { throw RecorderError.notRecording }
        guard let url = currentURL else { throw RecorderError.stopFailed }

        recorder.stop()
        self.recorder = nil
        self.currentURL = nil

        return url
    }
}
