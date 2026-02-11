import SwiftUI
import TranscribeHoldPasteKit

@main
struct TranscribeHoldPasteApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("TranscribeHoldPaste", systemImage: "waveform") {
            VStack(alignment: .leading, spacing: 8) {
                Text(appModel.statusLine)
                    .font(.callout)

                Divider()

                Button(appModel.isListeningEnabled ? "Disable hotkey" : "Enable hotkey") {
                    appModel.toggleListening()
                }

                SettingsLink()

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(10)
        }
        Settings {
            SettingsView(appModel: appModel)
        }
    }
}
