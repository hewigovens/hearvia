import SwiftUI

extension AppModel {
    func followBackgroundTranslation() {
        _ = withObservationTracking {
            (translation.isActive, translation.engine)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.followBackgroundTranslation()
                await self.syncBackgroundTranslation()
            }
        }
    }

    func syncBackgroundTranslation() async {
        await backgroundTranslation.update(running: listening && translation.isActive && translation.engine == .gemma,
                                           foreground: UIApplication.shared.applicationState == .active,
                                           chunks: translation.stats.chunksSent)
    }
}
