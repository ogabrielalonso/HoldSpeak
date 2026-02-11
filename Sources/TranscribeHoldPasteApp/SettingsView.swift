import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Activation") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Normal: hold Control + Option + Space")
                        Text("Prompted: hold Control + Option + Command + Space")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Hotkey enabled: \(appModel.isListeningEnabled ? "yes" : "no")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Hotkey registered: \(appModel.hotkeyRegistered ? "yes" : "no")")
                            .font(.footnote)
                            .foregroundColor(appModel.hotkeyRegistered ? .secondary : .orange)
                        if let err = appModel.hotkeyLastError {
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        Text("Last hotkey event: \(appModel.lastHotkeyEventAt?.formatted(date: .abbreviated, time: .standard) ?? "never")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Input Monitoring: \(appModel.inputMonitoringAllowed ? "allowed" : "not allowed")")
                            .font(.footnote)
                            .foregroundColor(appModel.inputMonitoringAllowed ? .secondary : .orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                GroupBox("OpenAI") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(appModel.apiKeyIsSet ? "API key is saved in Keychain (length \(appModel.apiKeyLength))" : "API key is not set")
                                .foregroundColor(appModel.apiKeyIsSet ? .secondary : .red)
                            Spacer()
                            Button("Re-check") { appModel.refreshKeychainState() }
                            Button("Clear") {
                                apiKeyInput = ""
                                appModel.clearAPIKey()
                            }
                            .disabled(!appModel.apiKeyIsSet)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("New API key (leave blank to keep existing)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if showAPIKey {
                                TextField("", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Toggle(isOn: $showAPIKey) { Text("Show") }
                                .toggleStyle(.switch)
                                .fixedSize()
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Models")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Transcription model")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Picker("Transcription model", selection: $appModel.modelName) {
                                    Text("gpt-4o-mini-transcribe").tag("gpt-4o-mini-transcribe")
                                    Text("gpt-4o-transcribe").tag("gpt-4o-transcribe")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                TextField("Custom transcription model", text: $appModel.modelName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Prompt model")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Picker("Prompt model", selection: $appModel.promptModelName) {
                                    Text("gpt-4.1-nano").tag("gpt-4.1-nano")
                                    Text("gpt-4.1-mini").tag("gpt-4.1-mini")
                                    Text("gpt-4o-mini").tag("gpt-4o-mini")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                TextField("Custom prompt model", text: $appModel.promptModelName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Divider()

                            Text("Prompt template")
                                .font(.headline)

                            Text("Prompt template (system instruction). Used only for Ctrl+Opt+Cmd+Space.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            TextEditor(text: $appModel.promptTemplate)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 120)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                GroupBox("History (last 10)") {
                    VStack(alignment: .leading, spacing: 10) {
                        if appModel.transcriptHistory.isEmpty {
                            Text("No transcripts yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appModel.transcriptHistory) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Text(item.mode == .prompted ? "Prompted" : "Transcript")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if let text = item.finalText, !text.isEmpty {
                                            Button("Copy") { appModel.copyToClipboard(text) }
                                        }
                                    }

                                    if let err = item.errorMessage, !err.isEmpty {
                                        Text(err)
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                    }

                                    if let preview = (item.finalText ?? item.transcript)?.trimmingCharacters(in: .whitespacesAndNewlines),
                                       !preview.isEmpty {
                                        Text(preview)
                                            .font(.footnote)
                                            .lineLimit(3)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.25)))
                            }
                        }

                        HStack {
                            Button("Clear history") { appModel.clearHistory() }
                            Spacer()
                            Text("Max recording length: 200s")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                GroupBox("Permissions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hotkey requires Input Monitoring. Pasting requires Accessibility. Recording requires Microphone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Microphone: \(appModel.microphoneState.rawValue)")
                                .font(.footnote)
                                .foregroundColor(appModel.microphoneState == .authorized ? .secondary : .orange)
                            Text("Accessibility: \(appModel.accessibilityTrusted ? "trusted" : "not trusted")")
                                .font(.footnote)
                                .foregroundColor(appModel.accessibilityTrusted ? .secondary : .orange)
                        }

                        HStack(spacing: 10) {
                            Button("Input Monitoring") {
                                appModel.requestInputMonitoringAccess()
                                SystemSettingsLinks.openPrivacyInputMonitoring()
                            }
                            Button("Accessibility") {
                                appModel.requestAccessibilityPrompt()
                                SystemSettingsLinks.openPrivacyAccessibility()
                            }
                            Button("Microphone") {
                                appModel.requestMicrophoneAccess()
                                SystemSettingsLinks.openPrivacyMicrophone()
                            }
                            Button("Refresh") { appModel.refreshPermissionStates() }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Add this app in Input Monitoring / Accessibility using this path:")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Text(appModel.appBundlePath)
                                    .font(.footnote)
                                    .textSelection(.enabled)
                                    .lineLimit(nil)
                                Button("Copy path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(appModel.appBundlePath, forType: .string)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                HStack(spacing: 12) {
                    Button("Save") {
                        appModel.saveSettings(newAPIKeyIfProvided: apiKeyInput)
                        apiKeyInput = ""
                    }
                    .buttonStyle(.borderedProminent)

                    if let feedback = appModel.settingsFeedback {
                        Text(feedback)
                            .foregroundStyle(appModel.settingsFeedbackIsError ? .red : .green)
                    }

                    Spacer()

                    Button(appModel.isListeningEnabled ? "Disable hotkey" : "Enable hotkey") {
                        appModel.toggleListening()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appModel.isListeningEnabled ? .red : .green)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 640, minHeight: 520)
        .onAppear {
            appModel.refreshPermissionStates()
            appModel.refreshKeychainState()
        }
    }
}
