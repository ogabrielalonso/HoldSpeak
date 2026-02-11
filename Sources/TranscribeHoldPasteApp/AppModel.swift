import AppKit
import Foundation
import TranscribeHoldPasteKit

@MainActor
final class AppModel: ObservableObject {
    struct TranscriptHistoryItem: Codable, Identifiable, Equatable {
        enum Mode: String, Codable {
            case transcript
            case prompted
        }

        var id: String
        var date: Date
        var mode: Mode
        var transcript: String?
        var finalText: String?
        var didPaste: Bool
        var didCopyToClipboard: Bool
        var errorMessage: String?
    }

    @Published var statusLine: String = "Idle"
    @Published var isListeningEnabled: Bool = false

    @Published var modelName: String = "gpt-4o-mini-transcribe"
    @Published var promptModelName: String = "gpt-4.1-nano"
    @Published var promptTemplate: String = "Rewrite the text to be clear and concise. Keep the meaning. Output only the rewritten text."
    @Published var apiKeyIsSet: Bool = false
    @Published var apiKeyLength: Int = 0
    @Published var microphoneState: Permissions.MicrophoneState = .notDetermined
    @Published var accessibilityTrusted: Bool = false
    @Published var inputMonitoringAllowed: Bool = false
    @Published var hotkeyRegistered: Bool = false
    @Published var hotkeyLastError: String?
    @Published var settingsFeedback: String?
    @Published var settingsFeedbackIsError: Bool = false
    @Published var lastHotkeyEventAt: Date?
    @Published var transcriptHistory: [TranscriptHistoryItem] = []

    private let keychain = KeychainStore(service: "HoldSpeak")
    private let legacyKeychain = KeychainStore(service: "TranscribeHoldPaste")
    private var controller: HoldToTranscribeController?
    private var monitorRaw: PressAndHoldHotkeyMonitor?
    private var monitorPrompt: PressAndHoldHotkeyMonitor?
    private var settingsWindow: SettingsWindowController?
    private var toast: ToastWindowController?

    private let historyKey = "transcript_history_v1"
    private let maxHistoryCount = 10

    private enum Activity {
        case idle
        case recording
        case transcribing
    }

    private var activity: Activity = .idle
    private var pulseTimer: Timer?
    @Published private(set) var pulseTick: Bool = false

    init() {
        modelName = UserDefaults.standard.string(forKey: "transcribe_model") ?? modelName
        refreshKeychainState()
        refreshPermissionStates()
        promptTemplate = UserDefaults.standard.string(forKey: "prompt_template") ?? promptTemplate
        promptModelName = UserDefaults.standard.string(forKey: "prompt_model") ?? promptModelName
        loadHistory()

        if !apiKeyIsSet {
            DispatchQueue.main.async { [weak self] in
                self?.showSettingsWindow()
            }
        }
    }

    func showSettingsWindow() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(appModel: self)
        }
        settingsWindow?.show()
    }

    func refreshKeychainState() {
        let value =
            (try? keychain.getString(account: "openai_api_key")) ??
            (try? legacyKeychain.getString(account: "openai_api_key"))
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        apiKeyIsSet = !trimmed.isEmpty
        apiKeyLength = trimmed.count
    }

    func refreshPermissionStates() {
        microphoneState = Permissions.microphoneState()
        accessibilityTrusted = AccessibilityPermissions.isTrusted()
        inputMonitoringAllowed = InputMonitoringPermissions.isAllowed()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    var appBundlePath: String {
        Bundle.main.bundleURL.path
    }

    var menuBarSymbolName: String {
        switch activity {
        case .idle:
            return "waveform"
        case .recording:
            return pulseTick ? "mic.circle.fill" : "mic.fill"
        case .transcribing:
            return pulseTick ? "waveform.circle.fill" : "waveform"
        }
    }

    func requestMicrophoneAccess() {
        Task {
            _ = await Permissions.requestMicrophoneAccess()
            await MainActor.run {
                self.microphoneState = Permissions.microphoneState()
            }
        }
    }

    func requestAccessibilityPrompt() {
        AccessibilityPermissions.prompt()
        accessibilityTrusted = AccessibilityPermissions.isTrusted()
    }

    func requestInputMonitoringAccess() {
        _ = InputMonitoringPermissions.request()
        inputMonitoringAllowed = InputMonitoringPermissions.isAllowed()
    }

    func saveSettings(newAPIKeyIfProvided apiKey: String) {
        UserDefaults.standard.set(promptTemplate, forKey: "prompt_template")
        UserDefaults.standard.set(promptModelName, forKey: "prompt_model")
        UserDefaults.standard.set(modelName, forKey: "transcribe_model")

        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            do {
                try keychain.setString(trimmed, account: "openai_api_key")
                apiKeyIsSet = true
                showSettingsFeedback("Saved API key", isError: false)
            } catch {
                showSettingsFeedback("Failed to save key: \(error)", isError: true)
            }
        } else {
            refreshKeychainState()
            if apiKeyIsSet {
                showSettingsFeedback("Saved", isError: false)
            } else {
                showSettingsFeedback("Enter an API key", isError: true)
            }
        }
    }

    func clearAPIKey() {
        do {
            try keychain.delete(account: "openai_api_key")
            try? legacyKeychain.delete(account: "openai_api_key")
            apiKeyIsSet = false
            showSettingsFeedback("Cleared API key", isError: false)
        } catch {
            showSettingsFeedback("Failed to clear key: \(error)", isError: true)
        }
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func clearHistory() {
        transcriptHistory = []
        saveHistory()
        showSettingsFeedback("Cleared history", isError: false)
    }

    func toggleListening() {
        Task { await toggleListeningAsync() }
    }

    private func toggleListeningAsync() async {
        if isListeningEnabled {
            monitorRaw?.stop()
            monitorPrompt?.stop()
            monitorRaw = nil
            monitorPrompt = nil
            controller = nil
            stopPulsing()
            activity = .idle
            isListeningEnabled = false
            hotkeyRegistered = false
            hotkeyLastError = nil
            statusLine = "Idle"
            return
        }

        let key =
            ((try? keychain.getString(account: "openai_api_key")) ??
                (try? legacyKeychain.getString(account: "openai_api_key")))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            apiKeyIsSet = false
            statusLine = "Set API key in Settings"
            showSettingsWindow()
            return
        }
        apiKeyIsSet = true

        if Permissions.microphoneState() == .notDetermined {
            _ = await Permissions.requestMicrophoneAccess()
        }
        refreshPermissionStates()
        guard microphoneState == .authorized else {
            statusLine = "Microphone permission required"
            showSettingsWindow()
            return
        }

        if !accessibilityTrusted {
            statusLine = "Grant Accessibility permission (for paste)"
            AccessibilityPermissions.prompt()
            refreshPermissionStates()
        }

        do {
            let client = OpenAIClient(apiKey: key)
            let controller = HoldToTranscribeController(
                client: client,
                config: .init(model: modelName, promptModel: promptModelName, promptTemplate: promptTemplate)
            )
            controller.setStateHandler { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .idle:
                        self.statusLine = "Idle (Ctrl+Opt+Space; Ctrl+Opt+Cmd+Space = prompt)"
                    default:
                        self.statusLine = Self.stateLine(state)
                    }
                    self.updateActivity(from: state)

                    if case .failed(let message) = state {
                        self.showToast(message)
                    }
                }
            }
            controller.setResultHandler { [weak self] result in
                Task { @MainActor in
                    self?.recordResult(result)
                }
            }

            let rawMonitor = PressAndHoldHotkeyMonitor(
                hotkey: .controlOptionSpace,
                carbonHotKeyID: 1,
                onPressed: { [weak self] in
                    controller.handleHotkeyPressed(behavior: .pasteTranscript)
                    Task { @MainActor in self?.lastHotkeyEventAt = Date() }
                },
                onReleased: { [weak self] in
                    controller.handleHotkeyReleased()
                    Task { @MainActor in self?.lastHotkeyEventAt = Date() }
                }
            )
            let promptMonitor = PressAndHoldHotkeyMonitor(
                hotkey: .controlOptionCommandSpace,
                carbonHotKeyID: 2,
                onPressed: { [weak self] in
                    controller.handleHotkeyPressed(behavior: .pastePrompted)
                    Task { @MainActor in self?.lastHotkeyEventAt = Date() }
                },
                onReleased: { [weak self] in
                    controller.handleHotkeyReleased()
                    Task { @MainActor in self?.lastHotkeyEventAt = Date() }
                }
            )
            try rawMonitor.start()
            try promptMonitor.start()

            self.controller = controller
            self.monitorRaw = rawMonitor
            self.monitorPrompt = promptMonitor
            self.isListeningEnabled = true
            self.hotkeyRegistered = true
            self.hotkeyLastError = nil
            self.statusLine = "Idle (Ctrl+Opt+Space; Ctrl+Opt+Cmd+Space = prompt)"
            self.activity = .idle
        } catch PressAndHoldHotkeyMonitor.MonitorError.tapCreationFailed {
            statusLine = "Grant Input Monitoring permission (hotkey)"
            showSettingsWindow()
        } catch PressAndHoldHotkeyMonitor.MonitorError.hotKeyRegistrationFailed(let status) {
            hotkeyRegistered = false
            hotkeyLastError = "Hotkey registration failed (OSStatus \(status)). Try another hotkey."
            statusLine = "Hotkey registration failed"
            showSettingsWindow()
        } catch {
            hotkeyRegistered = false
            hotkeyLastError = "Enable failed: \(error)"
            statusLine = "Enable hotkey failed: \(error)"
        }
    }

    private func updateActivity(from state: HoldToTranscribeController.State) {
        switch state {
        case .idle:
            activity = .idle
            stopPulsing()
        case .recording:
            activity = .recording
            startPulsingIfNeeded()
        case .transcribing:
            activity = .transcribing
            startPulsingIfNeeded()
        case .failed:
            activity = .idle
            stopPulsing()
        }
    }

    private func startPulsingIfNeeded() {
        guard pulseTimer == nil else { return }
        pulseTick = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.pulseTick.toggle()
            }
        }
        RunLoop.main.add(pulseTimer!, forMode: .common)
    }

    private func stopPulsing() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulseTick = false
    }

    private func showSettingsFeedback(_ message: String, isError: Bool) {
        settingsFeedback = message
        settingsFeedbackIsError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.settingsFeedback = nil
        }
    }

    private func showToast(_ message: String) {
        if toast == nil { toast = ToastWindowController() }
        toast?.show(message: message)
    }

    private func recordResult(_ result: HoldToTranscribeController.Result) {
        let mode: TranscriptHistoryItem.Mode
        switch result.behavior {
        case .pasteTranscript: mode = .transcript
        case .pastePrompted: mode = .prompted
        }

        let item = TranscriptHistoryItem(
            id: UUID().uuidString,
            date: Date(),
            mode: mode,
            transcript: result.transcript,
            finalText: result.finalText,
            didPaste: result.didPaste,
            didCopyToClipboard: result.didCopyToClipboard,
            errorMessage: result.errorMessage
        )

        transcriptHistory.insert(item, at: 0)
        if transcriptHistory.count > maxHistoryCount {
            transcriptHistory = Array(transcriptHistory.prefix(maxHistoryCount))
        }
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        guard let decoded = try? JSONDecoder().decode([TranscriptHistoryItem].self, from: data) else { return }
        transcriptHistory = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(transcriptHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private static func stateLine(_ state: HoldToTranscribeController.State) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .recording:
            return "Listening… (release to transcribe)"
        case .transcribing:
            return "Transcribing…"
        case .failed(let message):
            return message
        }
    }
}
