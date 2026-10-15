import HearviaUI
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    var showOnboarding: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-…", text: Bindable(model.translation).apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("OpenAI Realtime") } footer: {
                    Text("Only used by the OpenAI Realtime translator. Kept in this iPhone's Keychain.")
                }
                .listRowBackground(Color.hvSurface)

                Section {
                    OnDeviceModelsView(source: model.translation.sourceLanguage, target: model.translation.targetLanguage)
                } header: { Text("On-device models") } footer: {
                    Text("For the languages chosen on the home screen. Downloaded once, then work offline.")
                }
                .listRowBackground(Color.hvSurface)

                Section("Appearance") {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowBackground(Color.hvSurface)

                Section("Subtitles") {
                    HStack(spacing: 14) {
                        Text("A").font(.footnote).foregroundStyle(Color.hvMuted)
                        Slider(value: $settings.subtitleScale, in: AppSettings.subtitleScaleRange, step: 0.05)
                            .accessibilityLabel("Subtitle text size")
                        Text("A").font(.title3).foregroundStyle(Color.hvMuted)
                    }
                    Toggle("Show original speech", isOn: $settings.showsOriginal)
                    Toggle("Float when I leave Hearvia", isOn: $settings.floatsWhenLeaving)
                }
                .listRowBackground(Color.hvSurface)

                Section {
                    Button("How Hearvia works", action: showOnboarding)
                    #if DEBUG
                        NavigationLink { DeveloperView(model: model) } label: {
                            Label("Developer tools", systemImage: "wrench.and.screwdriver")
                        }
                        .accessibilityIdentifier("developerTools")
                    #endif
                } footer: {
                    Text("Hearvia \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.hvSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.hvGround)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(.hvAccent)
        .preferredColorScheme(settings.appearance.colorScheme)
    }
}
