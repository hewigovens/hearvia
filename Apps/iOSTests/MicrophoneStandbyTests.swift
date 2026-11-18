import Foundation
@testable import Hearvia
import XCTest

@MainActor
final class MicrophoneStandbyTests: XCTestCase {
    func testStandbyRequiresForegroundMicrophoneOptIn() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let settings = AppSettings(defaults: defaults)
        let model = AppModel(settings: settings)
        settings.hasCompletedOnboarding = true
        model.sceneChanged(.active)
        settings.input = .microphone
        XCTAssertNil(model.standbyLanguage)
        settings.warmMicrophone = true
        XCTAssertNotNil(model.standbyLanguage)
        model.sceneChanged(.inactive)
        XCTAssertNil(model.standbyLanguage)
        model.sceneChanged(.background)
        XCTAssertNil(model.standbyLanguage)
        model.sceneChanged(.active)
        XCTAssertNotNil(model.standbyLanguage)
        model.session.systemInterrupted = true
        XCTAssertNil(model.standbyLanguage)
        model.session.systemInterrupted = false
        settings.input = .otherApps
        XCTAssertNil(model.standbyLanguage)
    }
}
