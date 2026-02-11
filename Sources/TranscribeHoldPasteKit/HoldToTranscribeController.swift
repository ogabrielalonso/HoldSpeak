import Foundation

public final class HoldToTranscribeController: @unchecked Sendable {
    public enum State: Sendable, Equatable {
        case idle
        case recording
        case transcribing
        case failed(message: String)
    }

    public struct Config: Sendable {
        public var model: String
        public var language: String?
        public var restoreClipboardDelaySeconds: TimeInterval
        public var promptModel: String
        public var promptTemplate: String
        public var maxRecordingSeconds: TimeInterval

        public init(
            model: String = "gpt-4o-mini-transcribe",
            language: String? = nil,
            restoreClipboardDelaySeconds: TimeInterval = 0.3,
            promptModel: String = "gpt-4.1-nano",
            promptTemplate: String = "Rewrite the text to be clear and concise. Keep the meaning. Output only the rewritten text.",
            maxRecordingSeconds: TimeInterval = 200
        ) {
            self.model = model
            self.language = language
            self.restoreClipboardDelaySeconds = restoreClipboardDelaySeconds
            self.promptModel = promptModel
            self.promptTemplate = promptTemplate
            self.maxRecordingSeconds = maxRecordingSeconds
        }
    }

    public enum Behavior: Sendable, Equatable {
        case pasteTranscript
        case pastePrompted
    }

    public struct Result: Sendable {
        public var behavior: Behavior
        public var transcript: String?
        public var finalText: String?
        public var didPaste: Bool
        public var didCopyToClipboard: Bool
        public var errorMessage: String?

        public init(
            behavior: Behavior,
            transcript: String?,
            finalText: String?,
            didPaste: Bool,
            didCopyToClipboard: Bool,
            errorMessage: String?
        ) {
            self.behavior = behavior
            self.transcript = transcript
            self.finalText = finalText
            self.didPaste = didPaste
            self.didCopyToClipboard = didCopyToClipboard
            self.errorMessage = errorMessage
        }
    }

    private let recorder: AudioHoldRecorder
    private let client: OpenAIClient
    private let inserter: ClipboardInserter
    private let config: Config

    private var transcriptionTask: Task<Void, Never>?
    private var stateHandler: (@Sendable (State) -> Void)?
    private var resultHandler: (@Sendable (Result) -> Void)?
    private var pendingBehavior: Behavior = .pasteTranscript
    private var maxDurationStop: DispatchWorkItem?

    public init(
        recorder: AudioHoldRecorder = AudioHoldRecorder(),
        client: OpenAIClient,
        inserter: ClipboardInserter = ClipboardInserter(),
        config: Config = Config()
    ) {
        self.recorder = recorder
        self.client = client
        self.inserter = inserter
        self.config = config
    }

    public func setStateHandler(_ handler: (@Sendable (State) -> Void)?) {
        self.stateHandler = handler
    }

    public func setResultHandler(_ handler: (@Sendable (Result) -> Void)?) {
        self.resultHandler = handler
    }

    public func handleHotkeyPressed(behavior: Behavior = .pasteTranscript) {
        transcriptionTask?.cancel()
        maxDurationStop?.cancel()
        pendingBehavior = behavior

        do {
            try recorder.start()
            stateHandler?(.recording)

            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.recorder.isRecording else { return }
                self.handleHotkeyReleased()
            }
            maxDurationStop = item
            DispatchQueue.main.asyncAfter(deadline: .now() + config.maxRecordingSeconds, execute: item)
        } catch {
            stateHandler?(.failed(message: "Failed to start recording: \(error)"))
            resultHandler?(
                Result(
                    behavior: behavior,
                    transcript: nil,
                    finalText: nil,
                    didPaste: false,
                    didCopyToClipboard: false,
                    errorMessage: "Failed to start recording: \(error)"
                )
            )
        }
    }

    public func handleHotkeyReleased() {
        maxDurationStop?.cancel()

        let fileURL: URL
        do {
            fileURL = try recorder.stop()
        } catch {
            if let recorderError = error as? AudioHoldRecorder.RecorderError, recorderError == .notRecording {
                // Happens if we auto-stopped at max duration but the user releases later.
                return
            }
            stateHandler?(.failed(message: "Failed to stop recording: \(error)"))
            resultHandler?(
                Result(
                    behavior: pendingBehavior,
                    transcript: nil,
                    finalText: nil,
                    didPaste: false,
                    didCopyToClipboard: false,
                    errorMessage: "Failed to stop recording: \(error)"
                )
            )
            return
        }

        stateHandler?(.transcribing)

        let model = config.model
        let language = config.language
        let restoreDelay = config.restoreClipboardDelaySeconds
        let behavior = pendingBehavior
        let promptModel = config.promptModel
        let promptTemplate = config.promptTemplate

        transcriptionTask = Task { [client, inserter, stateHandler, resultHandler] in
            do {
                defer { try? FileManager.default.removeItem(at: fileURL) }
                let text = try await client.transcribe(fileURL: fileURL, model: model, language: language)
                let finalText: String
                switch behavior {
                case .pasteTranscript:
                    finalText = text
                case .pastePrompted:
                    finalText = try await client.promptTransform(text: text, prompt: promptTemplate, model: promptModel)
                }

                do {
                    try inserter.insertByPasting(text: finalText, restoreAfter: restoreDelay)
                    stateHandler?(.idle)
                    resultHandler?(
                        Result(
                            behavior: behavior,
                            transcript: text,
                            finalText: finalText,
                            didPaste: true,
                            didCopyToClipboard: false,
                            errorMessage: nil
                        )
                    )
                } catch {
                    // Fallback: at least put the result on the clipboard.
                    try? inserter.copyToClipboard(text: finalText)
                    let message: String
                    if let insertError = error as? ClipboardInserter.InsertError, insertError == .accessibilityNotTrusted {
                        message = "Grant Accessibility permission (to paste). Copied to clipboard."
                    } else {
                        message = "Could not paste. Copied to clipboard."
                    }
                    stateHandler?(.failed(message: message))
                    resultHandler?(
                        Result(
                            behavior: behavior,
                            transcript: text,
                            finalText: finalText,
                            didPaste: false,
                            didCopyToClipboard: true,
                            errorMessage: "Could not paste: \(error)"
                        )
                    )
                }
            } catch is CancellationError {
                stateHandler?(.idle)
            } catch {
                stateHandler?(.failed(message: "Transcription failed: \(error)"))
                resultHandler?(
                    Result(
                        behavior: behavior,
                        transcript: nil,
                        finalText: nil,
                        didPaste: false,
                        didCopyToClipboard: false,
                        errorMessage: "Transcription failed: \(error)"
                    )
                )
            }
        }
    }
}
