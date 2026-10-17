import HearviaUI
import SwiftUI

struct ControlPanel: View {
    let model: AppModel
    let inMenuBar: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ListenHero(model: model)
            if model.capturing {
                Text("\(model.source.label) · \(model.translator.languagePair) · \(model.translator.engine.shortTitle)")
                    .font(.caption).foregroundStyle(Color.hvMuted).lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                ControlTiles(model: model)
                    .transition(.offset(y: -30).combined(with: .opacity))
            }
            EngineStatusLine(translator: model.translator)
            ForEach([model.captureError, model.translator.error].filter { !$0.isEmpty }, id: \.self) { error in
                Text(error).font(.caption).foregroundStyle(.red)
            }
            OverlayOptions()
            Divider()
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, inMenuBar ? 14 : -26) // The window hides its title bar; the header sits beside the traffic lights.
        .padding(.bottom, 14)
        .frame(width: 480) // Tile values like "All system audio" fit on one line.
        .fixedSize(horizontal: false, vertical: true)
        .animation(.spring(duration: 0.5, bounce: 0.15), value: model.capturing)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .tint(.hvAccent)
        .onAppear { model.refreshProcesses() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HearviaIcon(size: 22)
            Text("Hearvia").font(.system(size: 15, weight: .bold))
            Spacer()
            SettingsLink { Image(systemName: "gearshape").font(.system(size: 14)).foregroundStyle(Color.hvMuted) }
                .buttonStyle(.borderless)
                .focusable(false) // Otherwise it takes the window's first focus ring; ⌘, still opens Settings.
                .help("Settings")
                .accessibilityLabel("Settings")
        }
        .frame(height: 28)
        .padding(.leading, inMenuBar ? 0 : 62)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Transcripts") { show("transcript") }
            if inMenuBar {
                Button("Open Window") { show("main") }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .foregroundStyle(Color.hvMuted)
    }

    private func show(_ window: String) {
        openWindow(id: window)
        NSApp.activate()
    }
}
