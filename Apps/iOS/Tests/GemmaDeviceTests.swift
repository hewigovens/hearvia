import BackgroundTasks
@testable import Hearvia
import HearviaGemma
import HearviaSession
import os
import UIKit
import XCTest

/// TranslateGemma inside the app's process on a real iPhone, where the memory limit applies. Skipped until the model
/// is in the app's container (Settings → Translators, or copy it over as agents/run-debug.md describes).
final class GemmaDeviceTests: XCTestCase {
    @MainActor
    func testTranslatesSentencesWhileBackgroundedWithGPUGrant() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HEARVIA_TEST_BACKGROUND_GEMMA"] == "1", "Opt-in device probe; switch to another app after gemma_background_ready")
        print("gemma_background_gpu_supported=\(BackgroundTranslation.isSupported)")
        try XCTSkipUnless(BackgroundTranslation.isSupported, "This device doesn't support background GPU tasks")
        try XCTSkipUnless(TranslateGemma.isDownloaded, "TranslateGemma isn't on this device")
        let receiver = BackgroundTaskReceiver()
        let background = BackgroundGPUAccess(supported: true, identifierPattern: BackgroundTranslation.identifierPattern, submit: { identifier in
            let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
                MainActor.assumeIsolated { receiver.accept(task) }
            }
            guard registered else { throw CocoaError(.featureUnsupported) }
            let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "TranslateGemma test", subtitle: "Checking background translation")
            request.requiredResources = .gpu
            request.strategy = .fail
            try await BGTaskScheduler.shared.submitTaskRequest(request)
        }, cancel: { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: $0) })
        receiver.background = background
        defer { background.stop() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while UIApplication.shared.applicationState != .active, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        await background.update(running: true, foreground: true, chunks: 0)
        while !background.isGranted, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(background.isGranted, "iOS didn't grant background GPU access")
        guard background.isGranted else { return }
        let translator = try await GemmaTranslator.load(canUseBackgroundGPU: { background.isGranted })
        _ = try await translator.translate("Hello.", from: "en", to: "zh")
        print("gemma_background_ready")
        let backgroundDeadline = ContinuousClock.now.advanced(by: .seconds(60))
        while UIApplication.shared.applicationState != .background, ContinuousClock.now < backgroundDeadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(UIApplication.shared.applicationState, .background, "Switch to another app after gemma_background_ready")
        guard UIApplication.shared.applicationState == .background else { return }
        let start = ContinuousClock.now
        var translations = 0
        repeat {
            let output = try await translator.translate("Researchers followed 200 volunteers for six months.", from: "en", to: "zh")
            XCTAssertFalse(output.isEmpty)
            XCTAssertEqual(UIApplication.shared.applicationState, .background)
            translations += 1
            await background.update(running: true, foreground: false, chunks: translations)
            print("gemma_background_sentence count=\(translations) elapsed=\(start.duration(to: .now)) output=\(output)")
            try await Task.sleep(for: .seconds(3))
        } while start.duration(to: .now) < .seconds(65)
        XCTAssertTrue(background.isGranted)
        print("gemma_background_complete count=\(translations) elapsed=\(start.duration(to: .now))")
    }

    func testTranslatesSentencesWithinTheMemoryLimit() async throws {
        try XCTSkipUnless(TranslateGemma.isDownloaded, "TranslateGemma isn't on this device")
        print("gemma_memory free_before_load_mb=\(os_proc_available_memory() >> 20)")
        var start = ContinuousClock.now
        let translator = try await GemmaTranslator.load()
        print("gemma_load seconds=\(start.duration(to: .now)) free_after_load_mb=\(os_proc_available_memory() >> 20)")
        _ = try await translator.translate("Hello.", from: "en", to: "zh")
        for sentence in ["Researchers followed 200 volunteers for six months.",
                         "Turning off screens an hour before bed also helped, but the effect was smaller than expected.",
                         "So for the next quarter we'll focus on onboarding, and the pricing page goes out next week."] {
            start = ContinuousClock.now
            let translation = try await translator.translate(sentence, from: "en", to: "zh")
            print("gemma_sentence seconds=\(start.duration(to: .now)) free_mb=\(os_proc_available_memory() >> 20) \(translation)")
            XCTAssertFalse(translation.isEmpty)
        }
    }
}

@MainActor
private final class BackgroundTaskReceiver {
    weak var background: BackgroundGPUAccess?

    func accept(_ task: BGTask) {
        guard let background, let task = task as? BGContinuedProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }
        task.expirationHandler = { [weak background, identifier = task.identifier] in
            Task { @MainActor in background?.expire(identifier: identifier) }
        }
        background.accept(identifier: task.identifier, progress: task.progress) { task.setTaskCompleted(success: $0) }
    }
}
