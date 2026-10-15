import AVKit
import SwiftUI

final class SubtitlePreviewView: UIView {
    override static var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }
    var displayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer // swiftlint:disable:this force_cast
    }
}

struct SubtitlePreview: UIViewRepresentable {
    let pip: PiPController
    func makeUIView(context: Context) -> SubtitlePreviewView {
        let view = pip.previewView
        view.backgroundColor = .black
        view.accessibilityIdentifier = "subtitlePreview"
        pip.attach(view.displayLayer)
        return view
    }
    func updateUIView(_ uiView: SubtitlePreviewView, context: Context) {}
}
