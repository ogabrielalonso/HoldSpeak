import AVFoundation
import Foundation

enum Permissions {
    enum MicrophoneState: String {
        case notDetermined
        case restricted
        case denied
        case authorized
    }

    static func microphoneState() -> MicrophoneState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .notDetermined
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cont.resume(returning: granted)
            }
        }
    }
}

