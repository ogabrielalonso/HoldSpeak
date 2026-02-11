import Foundation
import TranscribeHoldPasteKit

@MainActor
final class AppModel: ObservableObject {
    @Published var statusLine: String = "Idle"
    @Published var isListeningEnabled: Bool = false
    @Published var modelName: String = "gpt-4o-mini-transcribe"

    private let keychain = KeychainStore(service: "TranscribeHoldPaste")
    private var controller: HoldToTranscribeController?
    private var monitor: PressAndHoldHotkeyMonitor?

    func toggleListening() {
        if isListeningEnabled {
            monitor?.stop()
            monitor = nil
            controller = nil
            isListeningEnabled = false
            statusLine = "Idle"
            return
        }

        do {
            let apiKey = try keychain.getString(account: "openai_api_key") ?? ""
            if apiKey.isEmpty {
                statusLine = "Set API key in Settings"
                return
            }

            let client = OpenAIClient(apiKey: apiKey)
            let controller = HoldToTranscribeController(
                client: client,
                config: .init(model: modelName)
            )
            controller.setStateHandler { [weak self] state in
                Task { @MainActor in
                    self?.statusLine = Self.stateLine(state)
                }
            }

            let monitor = PressAndHoldHotkeyMonitor(
                hotkey: .init(requiredFlags: [.maskSecondaryFn]),
                onPressed: { controller.handleHotkeyPressed() },
                onReleased: { controller.handleHotkeyReleased() }
            )
            try monitor.start()

            self.controller = controller
            self.monitor = monitor
            self.isListeningEnabled = true
            self.statusLine = "Idle (hold Fn/Globe)"
        } catch {
            statusLine = "Failed to enable hotkey: \(error)"
        }
    }

    func saveAPIKey(_ key: String) {
        do {
            try keychain.setString(key, account: "openai_api_key")
            statusLine = isListeningEnabled ? "Idle (hold Fn/Globe)" : "Saved API key"
        } catch {
            statusLine = "Failed to save key: \(error)"
        }
    }

    private static func stateLine(_ state: HoldToTranscribeController.State) -> String {
        switch state {
        case .idle:
            return "Idle (hold Fn/Globe)"
        case .recording:
            return "Listening… (release to transcribe)"
        case .transcribing:
            return "Transcribing…"
        case .failed(let message):
            return message
        }
    }
}
