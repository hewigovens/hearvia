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
                    Toggle("Save transcripts", isOn: Bindable(model.translation).savesTranscripts)
                    Button("Delete All Transcripts", role: .destructive) { model.translation.history.deleteAll() }
                        .disabled(model.translation.history.transcripts.isEmpty)
                } header: { Text("Transcripts") } footer: {
                    Text("Kept on this iPhone only. Open one from the transcript button on the home screen to export or share it.")
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

                Section {
                    NavigationLink { TranslatorSettingsView(translator: model.translation) } label: {
                        LabeledContent { Text(model.translation.engine.title) } label: {
                            Label("Translators", systemImage: "character.bubble")
                        }
                    }
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
