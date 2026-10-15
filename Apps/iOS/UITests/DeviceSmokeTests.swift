import XCTest

/// Narrow on-device evidence. This does not auto-approve screen capture or claim external PCM success.
final class DeviceSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor
    func testAStandaloneSafari() throws {
        guard ProcessInfo.processInfo.environment["HEARVIA_RUN_SAFARI"] == "1" else { throw XCTSkip("Requires prepared local Safari test video") }
        let app = XCUIApplication()
        app.launchEnvironment["HEARVIA_EXPERIMENT"] = "A Safari capture only; no audio-session activation"
        app.launch()
        try startCapture(app)
        reveal(app.buttons["recordStart"], in: app, up: false)
        app.buttons["recordStart"].tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        let play = safari.buttons["Play test video"]
        let playing = safari.buttons["Playing test video"]
        XCTAssertTrue(playing.exists || play.waitForExistence(timeout: 8), safari.debugDescription)
        if play.exists { play.tap() } else { playing.tap() }
        sleep(3)
        attach("A-Safari-start", XCUIScreen.main.screenshot())
        sleep(30); sleep(30); sleep(5)
        attach("A-Safari-end", XCUIScreen.main.screenshot())
        app.activate()
        reveal(app.buttons["captureStop"], in: app, up: false)
        app.buttons["captureStop"].tap()
    }

    @MainActor
    func testPiPOrientationAndRestore() throws {
        let app = XCUIApplication()
        app.launchEnvironment["HEARVIA_EXPERIMENT"] = "B PiP orientation and restore"
        app.launch()
        try startPiP(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(4)
        attach("B-landscape", XCUIScreen.main.screenshot())
        XCUIDevice.shared.orientation = .portrait
        sleep(4)
        attach("B-portrait", XCUIScreen.main.screenshot())
        app.buttons["pipStop"].tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["pipState"].label.contains("PiP stopped"))
    }

    @MainActor
    func testInspectPodcasts() {
        guard ProcessInfo.processInfo.environment["HEARVIA_RUN_SAFARI"] == "1" else { return }
        let app = XCUIApplication(bundleIdentifier: "com.apple.podcasts")
        app.activate()
        sleep(3)
        print("PODCASTS_TREE\n" + app.debugDescription)
        attach("podcasts-inspection", app.screenshot())
    }

    @MainActor
    func testInspectPodcastEpisodes() throws {
        guard ProcessInfo.processInfo.environment["HEARVIA_RUN_SAFARI"] == "1" else { throw XCTSkip("Opt-in source inspection") }
        let app = XCUIApplication(bundleIdentifier: "com.apple.podcasts")
        app.activate()
        app.staticTexts["Latest Episodes"].tap()
        sleep(3)
        print("PODCAST_EPISODES_TREE\n" + app.debugDescription)
        attach("podcast-episodes", app.screenshot())
    }

    @MainActor
    func testAPodcastsAndMixActivation() throws {
        guard ProcessInfo.processInfo.environment["HEARVIA_RUN_SAFARI"] == "1" else { throw XCTSkip("Opt-in prepared Podcasts source") }
        let app = XCUIApplication()
        app.launchEnvironment["HEARVIA_EXPERIMENT"] = "A Podcasts + playback-mix activation"
        app.launch()
        try startCapture(app)
        reveal(app.buttons["recordStart"], in: app, up: false)
        app.buttons["recordStart"].tap()
        let podcasts = XCUIApplication(bundleIdentifier: "com.apple.podcasts")
        podcasts.activate()
        let play = podcasts.buttons.matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "podcasts.shelfItemSubComponent.playControls", "Play")).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 8), "Prepare Podcasts Latest Episodes with a playable episode")
        play.tap()
        let pause = podcasts.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pause")).firstMatch
        sleep(3)
        print("PODCAST_PLAYBACK_CONTROLS " + podcasts.buttons.allElementsBoundByIndex.map { String($0.label.prefix(80)) + " [" + $0.identifier + "]" }.joined(separator: " | "))
        attach("Podcasts-source-start", XCUIScreen.main.screenshot())
        sleep(30); sleep(30); sleep(5)
        attach("Podcasts-source-end", XCUIScreen.main.screenshot())
        app.activate()
        reveal(app.buttons["recordStart"], in: app, up: false)
        app.buttons["recordStart"].tap()
        let activate = app.buttons["Activate Session"]
        reveal(activate, in: app)
        activate.tap()
        sleep(20)
        attach("Podcasts-mix-active", XCUIScreen.main.screenshot())
        reveal(app.buttons["captureStop"], in: app, up: false)
        app.buttons["captureStop"].tap()
        podcasts.activate()
        if pause.exists && pause.isHittable { pause.tap() }
        // Source audibility and session compatibility are decided from PCM/logs, not this UI predicate.
    }
    @MainActor
    func testD1OwnToneIncludedWithSafari() throws { try ownTone(exclude: false) }

    @MainActor
    func testD2OwnToneExcludedWithSafari() throws { try ownTone(exclude: true) }

    @MainActor private func ownTone(exclude: Bool) throws {
        guard ProcessInfo.processInfo.environment["HEARVIA_RUN_SAFARI"] == "1" else { throw XCTSkip("Requires prepared local Safari test video") }
        let app = XCUIApplication()
        app.launchEnvironment["HEARVIA_EXPERIMENT"] = exclude ? "D2 excluded tone + Safari" : "D1 included tone + Safari"
        app.launch()
        if !exclude {
            let toggle = app.switches["excludeOwnAudio"]
            reveal(toggle, in: app)
            toggle.tap()
            if toggle.value as? String != "0" {
                // SwiftUI exposes the whole labeled row as the switch. Tap its visible knob.
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
            XCTAssertEqual(toggle.value as? String, "0", "The unexcluded run must actually turn exclusion off")
        }
        reveal(app.buttons["captureStart"], in: app, up: false)
        try startCapture(app)
        let tone = app.buttons["toneToggle"]
        reveal(tone, in: app, up: false)
        tone.tap()
        sleep(2)
        let record = app.buttons["recordStart"]
        reveal(record, in: app, up: false)
        record.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        let play = safari.buttons["Play test video"]
        let playing = safari.buttons["Playing test video"]
        XCTAssertTrue(playing.exists || play.waitForExistence(timeout: 3), safari.debugDescription)
        if play.exists { play.tap() } else { playing.tap() }
        sleep(20)
        attach(exclude ? "D2-Safari" : "D1-Safari", XCUIScreen.main.screenshot())
        app.activate()
        reveal(app.buttons["toneToggle"], in: app, up: false)
        app.buttons["toneToggle"].tap()
        reveal(app.buttons["captureStop"], in: app, up: false)
        print("TONE_END\n" + app.debugDescription)
        app.buttons["captureStop"].tap()
    }

    @MainActor
    func testC1CaptureThenPiPWithSafari() throws { try combined(pipFirst: false) }

    @MainActor
    func testC2PiPThenCaptureWithSafari() throws { try combined(pipFirst: true) }

    @MainActor
    private func combined(pipFirst: Bool) throws {
        // Opt-in: prepare Safari with TestMedia/index.html before running these tests.
        guard ProcessInfo.processInfo.environment["HEARVIA_RUN_SAFARI"] == "1" else { throw XCTSkip("Requires prepared local Safari test video") }
        let app = XCUIApplication()
        app.launchEnvironment["HEARVIA_EXPERIMENT"] = pipFirst ? "C2 PiP-capture-Safari" : "C1 capture-PiP-Safari"
        app.launch()
        if pipFirst { try startPiP(app) }
        try startCapture(app)
        if !pipFirst { try startPiP(app) }
        let record = app.buttons["recordStart"]
        reveal(record, in: app, up: false)
        record.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        let play = safari.buttons["Play test video"]
        let playing = safari.buttons["Playing test video"]
        XCTAssertTrue(playing.exists || play.waitForExistence(timeout: 8), safari.debugDescription)
        if play.exists { play.tap() } else { playing.tap() }
        sleep(3)
        attach(pipFirst ? "C2-start" : "C1-start", XCUIScreen.main.screenshot())
        sleep(30); sleep(30); sleep(5)
        attach(pipFirst ? "C2-end" : "C1-end", XCUIScreen.main.screenshot())
        app.activate()
        reveal(app.buttons["captureStop"], in: app, up: false)
        print("COMBINED_END\n" + app.debugDescription)
        XCTAssertTrue(app.buttons["captureStop"].isEnabled)
        XCTAssertTrue(app.staticTexts["pipState"].label.contains("PiP active"))
        app.buttons["captureStop"].tap()
        app.buttons["pipStop"].tap()
    }

    @MainActor private func startCapture(_ app: XCUIApplication) throws {
        let start = app.buttons["captureStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        reveal(start, in: app)
        start.tap()
        let share = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Share Entire Screen"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        sleep(5)
        // iOS leaves the authorized sharing card open. Its observed bounds are centered,
        // with empty space below; dismiss it without pressing Stop Sharing.
        XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.82)).tap()
        sleep(1)
        print("CAPTURE_STARTED\n" + app.debugDescription)
        reveal(app.staticTexts["captureState"], in: app)
        XCTAssertTrue(app.staticTexts["captureState"].label.contains("Capturing"), app.staticTexts["captureState"].label)
    }

    @MainActor private func startPiP(_ app: XCUIApplication) throws {
        reveal(app.buttons["pipStart"], in: app, up: false)
        app.buttons["pipStart"].tap()
        sleep(5)
        XCTAssertTrue(app.staticTexts["pipState"].label.contains("PiP active"), app.staticTexts["pipState"].label)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, up: Bool = true) {
        for _ in 0..<12 {
            if element.isHittable { return }
            var scrollUp = up
            if element.exists {
                let bounds = element.frame
                if bounds.width > 0 && bounds.height > 0 && bounds.minY.isFinite { scrollUp = bounds.midY > app.frame.midY }
            }
            if scrollUp { app.swipeUp() } else { app.swipeDown() }
        }
    }

    @MainActor
    func testInspectSafari() {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        sleep(3)
        print("SAFARI_TREE\n" + safari.debugDescription)
        attach("safari-inspection", safari.screenshot())
    }

    @MainActor
    func testInspectCaptureConsent() throws {
        let app = XCUIApplication()
        app.launch()
        let button = app.buttons["captureStart"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        if !button.isHittable { app.swipeUp() }
        button.tap()
        sleep(4)
        print("CAPTURE_APP_TREE\n" + app.debugDescription)
        print("CAPTURE_SYSTEM_TREE\n" + XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)
        attach("capture-consent", XCUIScreen.main.screenshot())
    }

    @MainActor
    func testDynamicInlineAndPiP() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["pipStart"].waitForExistence(timeout: 15))
        sleep(3)
        let before = app.staticTexts["pipState"].label
        sleep(3)
        let after = app.staticTexts["pipState"].label
        XCTAssertNotEqual(before, after, "Dynamic frame count must advance")
        attach("inline-subtitles", app.screenshot())
        app.buttons["pipStart"].tap()
        sleep(5)
        attach("pip-start", XCUIScreen.main.screenshot())
        XCTAssertTrue(app.staticTexts["pipState"].label.contains("PiP active"), app.staticTexts["pipState"].label)
        XCUIDevice.shared.press(.home)
        sleep(5)
        attach("pip-over-home", XCUIScreen.main.screenshot())
        app.activate()
        sleep(2)
        app.buttons["pipStop"].tap()
    }

    @MainActor private func attach(_ name: String, _ screenshot: XCUIScreenshot) {
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}
