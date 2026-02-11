import Foundation
import TranscribeHoldPasteKit

enum CLIError: Error, CustomStringConvertible {
    case missingAPIKey

    var description: String {
        switch self {
        case .missingAPIKey:
            return "Missing OPENAI_API_KEY in environment."
        }
    }
}

@main
struct TranscribeHoldPasteCLI {
    static func main() async {
        do {
            let args = CommandLine.arguments
            if args.contains("--help") || args.contains("-h") {
                print(
                    """
                    TranscribeHoldPasteCLI

                    This is a smoke-test harness for TranscribeHoldPasteKit.
                    It doesn't record audio. Use the example app in Examples/MacApp for the real UX.

                    Env:
                      OPENAI_API_KEY  (required by the example transcription call)
                    """
                )
                return
            }

            guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
                throw CLIError.missingAPIKey
            }

            let client = OpenAIClient(apiKey: apiKey)
            print("OpenAI baseURL:", client.baseURL.absoluteString)
            print("OK (kit loads).")
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

