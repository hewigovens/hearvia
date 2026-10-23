import HearviaUI
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    var showOnboarding: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Appearance", icon: "circle.lefthalf.filled", color: .purple)
                                .fixedSize(horizontal: false, vertical: true)
                            Picker("Appearance", selection: $settings.appearance) {
                                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    } else {
                        Picker(selection: $settings.appearance) {
                            ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                        } label: {
                            Label("Appearance", icon: "circle.lefthalf.filled", color: .purple)
                        }
                    }
                }
                .listRowBackground(Color.hvSurface)

                Section("Subtitles") {
                    SubtitleSample(scale: settings.subtitleScale, originalLarge: settings.originalLarge, showsOriginal: settings.showsOriginal)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    HStack(spacing: 14) {
                        SettingsIcon("textformat.size", .orange)
                        Text("A").font(.footnote).foregroundStyle(Color.hvMuted)
                        Slider(value: $settings.subtitleScale, in: AppSettings.subtitleScaleRange, step: 0.05)
                            .accessibilityLabel("Subtitle text size")
                            .accessibilityValue("\(Int(settings.subtitleScale * 100)) percent")
                        Text("A").font(.title3).foregroundStyle(Color.hvMuted)
                    }
                    Picker(selection: $settings.originalLarge) {
                        Text("Translation").tag(false)
                        Text("Original speech").tag(true)
                    } label: { Label("Bigger line", icon: "arrow.up.arrow.down", color: .purple) }
                    Toggle(isOn: $settings.showsOriginal) {
                        Label(settings.originalLarge ? "Also show translation" : "Also show original speech", icon: "text.bubble", color: .teal)
                    }
                    Toggle(isOn: $settings.floatsWhenLeaving) { Label("Float when I leave Hearvia", icon: "pip", color: .indigo) }
                }
                .listRowBackground(Color.hvSurface)

                Section {
                    NavigationLink { TranslatorSettingsView(translator: model.translation) } label: {
                        LabeledContent { Text(model.translation.engine.title) } label: {
                            Label("Translators", icon: "character.bubble", color: .blue)
                        }
                    }
                    Picker(selection: $settings.autoStopMinutes) {
                        Text("Off").tag(0)
                        ForEach([15, 30, 60, 120], id: \.self) { Text("\($0) min").tag($0) }
                    } label: {
                        Label("Stop cloud sessions after", icon: "timer", color: .orange)
                    }
                }
                .listRowBackground(Color.hvSurface)

                Section {
                    Toggle(isOn: Bindable(model.translation).savesTranscripts) {
                        Label("Save transcripts", icon: "doc.text", color: .green)
                    }
                    Toggle(isOn: Bindable(model.translation.history).syncsWithICloud) {
                        Label("Sync with iCloud", icon: "icloud", color: .blue)
                    }
                    Button(role: .destructive) { model.translation.history.deleteAll() } label: {
                        Label("Delete All Transcripts", icon: "trash", color: .red)
                    }
                    .disabled(model.translation.history.transcripts.isEmpty)
                } header: { Text("Transcripts") } footer: {
                    Text(model.translation.history.storageNote(device: UIDevice.current.model))
                }
                .listRowBackground(Color.hvSurface)

                Section {
                    Button(action: showOnboarding) { Label("How Hearvia Works", icon: "questionmark", color: .gray) }
                        .foregroundStyle(Color.hvText)
                    #if DEBUG
                        NavigationLink { DeveloperView(model: model) } label: {
                            Label("Developer Tools", icon: "hammer.fill", color: .gray)
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
