#if DEBUG
    import HearviaCore
    import HearviaUI
    import SwiftUI

    struct DeveloperView: View {
        @Bindable var model: AppModel
        @State private var recordMicrophone = false

        var body: some View {
            ScrollViewReader { proxy in
                Form {
                    controlsSection
                    translationSection
                    pipSection.id("pip")
                    captureSection
                    Section("Microphone input (home screen source)") {
                        Text(model.micRunning ? String(format: "Running · peak %.3f", model.levels.last ?? 0) : model.micStarting ? "Starting" : "Off")
                            .monospacedDigit()
                        if !model.micError.isEmpty {
                            Text(model.micError).foregroundStyle(.red)
                        }
                        Text("AVAudioEngine input, no voice processing, play & record + mix with others.").font(.caption)
                    }
                    Section("System playback PCM") { DiagnosticsPanel(stats: model.audio.system) }
                    Section("Microphone PCM — separate output") {
                        Text(model.capture.microphoneEnabled ? "Enabled by system picker" : "Off")
                        DiagnosticsPanel(stats: model.audio.microphone)
                    }
                    sessionSection
                    recordingSection
                    evidenceSection
                }
                .onChange(of: model.pip.restoreRequested) { _, requested in
                    if requested {
                        proxy.scrollTo("pip", anchor: .top)
                        Task { @MainActor in
                            await Task.yield()
                            model.pip.finishRestore()
                        }
                    }
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
        }

        private var controlsSection: some View {
            Section("Capture & PiP controls") {
                HStack {
                    Button("Start Capture") { model.capture.start() }.accessibilityIdentifier("captureStart")
                        .disabled(model.capture.running || model.capture.pending || model.capture.stopping)
                    Button("Stop Capture") { Task { await model.capture.stop() } }.accessibilityIdentifier("captureStop")
                        .disabled(!model.capture.running && !model.capture.pending)
                }.buttonStyle(.bordered)
                Button("Record Next 15 Seconds") { model.capture.probe.armRecording(microphone: recordMicrophone) }
                    .accessibilityIdentifier("recordStart").disabled(!model.capture.running)
                HStack {
                    Button("Start PiP", systemImage: "pip.enter") { model.pip.start() }
                        .accessibilityIdentifier("pipStart").disabled(model.pip.active || model.pip.pending)
                    Button("Stop PiP", systemImage: "pip.exit") { model.pip.stop() }
                        .accessibilityIdentifier("pipStop").disabled(!model.pip.active)
                }.buttonStyle(.bordered)
                Button(model.session.tonePlaying ? "Stop 1 kHz Tone" : "Play 1 kHz Tone") {
                    if model.session.tonePlaying {
                        model.session.stopTone()
                    } else {
                        Task { await model.session.startTone() }
                    }
                }.accessibilityIdentifier("toneToggle").disabled(model.session.toneStarting)
            }
        }

        private var translationSection: some View {
            Section("Live translation · \(model.translation.engine.title)") {
                Toggle("Translate while capturing", isOn: $model.translationEnabled)
                Picker("Target language", selection: Binding(get: { model.translation.targetLanguage },
                                                             set: { language in Task { await model.translation.setTargetLanguage(language) } })) {
                    ForEach(OnDeviceLanguages.shared.subtitleChoices(for: model.translation.engine, including: model.translation.targetLanguage),
                            id: \.self) { Text(LanguageName.of($0)).tag($0) }
                }
                SecureField("OpenAI API key", text: Bindable(model.translation).openAIKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HStack {
                    Button("Connect") { Task { await model.translation.start() } }
                        .disabled(model.translation.isActive || !model.listening)
                    Button("Disconnect") { Task { await model.translation.stop() } }.disabled(!model.translation.isActive)
                }.buttonStyle(.bordered)
                Text("\(model.translation.status.label) · sent \(model.translation.stats.chunksSent) × 200 ms · \(model.translation.stats.deltas) deltas · \(model.translation.stats.reconnects) reconnects")
                    .font(.caption).accessibilityIdentifier("translationState")
                if !model.translation.source.isEmpty {
                    Text(model.translation.source.suffix(200)).font(.caption).foregroundStyle(.secondary)
                }
                if !model.translation.translation.isEmpty {
                    Text(model.translation.translation.suffix(200))
                }
                if !model.translation.error.isEmpty {
                    Text(model.translation.error).foregroundStyle(.red)
                }
                Text("Starts with capture or mic input. Engine and languages are chosen on the home screen. The app plays no translated audio: own-audio exclusion is unreliable on iOS 27.0.1.").font(.caption)
            }
        }

        private var pipSection: some View {
            Section("Dynamic subtitle PiP") {
                Text("\(model.pip.state) · possible \(model.pip.possible ? "yes" : "no") · frames \(model.pip.frames)")
                    .accessibilityIdentifier("pipState")
                Text("PiP render size: \(model.pip.renderSize)")
                Toggle("Show system RMS in PiP instead of translation", isOn: $model.diagnosticsInPiP)
                Toggle("Show status line in PiP", isOn: $model.statusLineInPiP)
                if !model.pip.error.isEmpty {
                    Text(model.pip.error).foregroundStyle(.red)
                }
            }
        }

        private var captureSection: some View {
            Section("Full-display capture") {
                Text(model.capture.state).accessibilityIdentifier("captureState")
                Toggle("Offer microphone in system picker", isOn: Binding(get: { model.capture.offerMicrophone }, set: { model.capture.offerMicrophone = $0 }))
                    .disabled(model.capture.running || model.capture.pending || model.capture.stopping)
                Toggle("Exclude this app’s playback audio", isOn: Binding(get: { model.capture.excludeOwnAudio }, set: { model.capture.excludeOwnAudio = $0 }))
                    .accessibilityIdentifier("excludeOwnAudio")
                    .disabled(model.capture.running || model.capture.pending || model.capture.stopping)
                Text("Stop capture before changing exclusion; iOS requires a fresh stream.").font(.caption)
                Text("Choose full display in the system consent sheet. Microphone audio never enters the system metrics.").font(.caption)
                if !model.capture.error.isEmpty {
                    Text(model.capture.error).foregroundStyle(.red).accessibilityIdentifier("captureError")
                }
            }
        }

        private var sessionSection: some View {
            Section("Audio isolation / route experiment") {
                Picker("Session mode", selection: Binding(get: { model.session.mode }, set: { model.session.mode = $0 })) {
                    ForEach(SessionMode.allCases) { Text($0.rawValue).tag($0) }
                }
                HStack {
                    Button("Activate Session") { Task { try? await model.session.activate() } }
                    Button("Deactivate Session") { Task { await model.session.deactivate() } }
                }.buttonStyle(.bordered)
                Text(model.session.tonePlaying ? "1 kHz test tone playing" : "Test tone off")
                Text("Session: \(model.session.status)\nRoute: \(model.session.route)").font(.caption)
                Text("Capture alone uses no session activation. PiP/tone activate the selected mode. Microphone selects play & record. Exclusive mode may interrupt the source; record what you hear.").font(.caption)
                if !model.session.error.isEmpty {
                    Text(model.session.error).foregroundStyle(.red)
                }
            }
        }

        private var recordingSection: some View {
            Section("Optional 15-second PCM export") {
                Toggle("Record microphone instead of system", isOn: $recordMicrophone)
                Button("Finish Partial Recording") { model.capture.probe.finishRecording() }
                Text(model.audio.recordingState)
                if let url = model.audio.recordingURL, !model.audio.recordingState.hasPrefix("Recording") {
                    ShareLink("Share CAF", item: url)
                }
            }
        }

        private var evidenceSection: some View {
            Section("Observations and logs") {
                TextField("Source app / clip", text: $model.observationSource)
                    .accessibilityIdentifier("sourceLabel")
                TextField("What was audible? Any interruption?", text: $model.observationNote, axis: .vertical)
                Button("Log Observation") { model.logObservation() }
                ShareLink("Share JSONL Evidence", item: model.log.url)
                Text("Non-zero PCM is a signal check. Confirm the source by listening to the exported CAF. A callback is not a successful capture.").font(.caption)
            }
        }
    }
#endif
