import SwiftUI

@main
struct TranscribeHoldPasteApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 10) {
                Text(appModel.statusLine)
                    .font(.callout)

                HStack(spacing: 10) {
                    Button(appModel.isListeningEnabled ? "Disable hotkey" : "Enable hotkey") {
                        appModel.toggleListening()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appModel.isListeningEnabled ? .red : .green)
                    Button("Settings…") {
                        appModel.showSettingsWindow()
                    }
                }

                Divider()

                Button("Quit") {
                    appModel.quit()
                }
            }
            .padding(12)
            .frame(width: 280)
        } label: {
            Image(systemName: appModel.menuBarSymbolName)
                .accessibilityLabel(Text("HoldSpeak"))
        }
    }
}
