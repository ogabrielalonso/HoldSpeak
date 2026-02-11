import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Text("Hotkey: hold Fn/Globe")

            TextField("OpenAI API key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            Button("Save") {
                appModel.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            Divider()

            Text("If the hotkey doesn’t work, grant permissions:")
            HStack {
                Button("Open Input Monitoring") { SystemSettingsLinks.openPrivacyInputMonitoring() }
                Button("Open Accessibility") { SystemSettingsLinks.openPrivacyAccessibility() }
                Button("Open Microphone") { SystemSettingsLinks.openPrivacyMicrophone() }
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            apiKey = ""
        }
    }
}
