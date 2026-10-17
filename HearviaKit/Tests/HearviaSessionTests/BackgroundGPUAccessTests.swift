@testable import HearviaSession
import XCTest

@MainActor
final class BackgroundGPUAccessTests: XCTestCase {
    func testOnlyAGrantedTaskAllowsBackgroundGPUAndReportsProcessedAudio() async throws {
        var submitted: [String] = []
        var completions: [Bool] = []
        let background = BackgroundGPUAccess(supported: true, identifierPattern: "test.gpu.*", submit: { submitted.append($0) }, cancel: { _ in })
        await background.update(running: true, foreground: true, chunks: 0)
        XCTAssertFalse(background.isGranted)
        let progress = Progress()
        try background.accept(identifier: XCTUnwrap(submitted.first), progress: progress) { completions.append($0) }
        XCTAssertTrue(background.isGranted)
        await background.update(running: true, foreground: false, chunks: 7)
        XCTAssertEqual(progress.completedUnitCount, 7)
        XCTAssertEqual(progress.totalUnitCount, 8)
        background.stop()
        XCTAssertFalse(background.isGranted)
        XCTAssertEqual(completions, [true])
    }

    func testUnsupportedDevicesAndBackgroundStartsDoNotSubmit() async {
        var submissions = 0
        let unsupported = BackgroundGPUAccess(supported: false, identifierPattern: "test.gpu.*", submit: { _ in submissions += 1 }, cancel: { _ in })
        await unsupported.update(running: true, foreground: true, chunks: 0)
        let background = BackgroundGPUAccess(supported: true, identifierPattern: "test.gpu.*", submit: { _ in submissions += 1 }, cancel: { _ in })
        await background.update(running: true, foreground: false, chunks: 0)
        XCTAssertEqual(submissions, 0)
        XCTAssertFalse(unsupported.isGranted)
        XCTAssertFalse(background.isGranted)
    }

    func testExpirationRevokesGPUAndDoesNotRetryUntilTheUserReturns() async throws {
        var submitted: [String] = []
        var completions: [Bool] = []
        let background = BackgroundGPUAccess(supported: true, identifierPattern: "test.gpu.*", submit: { submitted.append($0) }, cancel: { _ in })
        await background.update(running: true, foreground: true, chunks: 0)
        let identifier = try XCTUnwrap(submitted.first)
        background.accept(identifier: identifier, progress: Progress()) { completions.append($0) }
        background.expire(identifier: identifier)
        XCTAssertFalse(background.isGranted)
        XCTAssertEqual(completions, [false])
        await background.update(running: true, foreground: false, chunks: 1)
        await background.update(running: true, foreground: true, chunks: 2)
        XCTAssertEqual(submitted.count, 1)
        background.resume()
        await background.update(running: true, foreground: true, chunks: 3)
        XCTAssertEqual(submitted.count, 2)
    }

    func testLateGrantAndExpirationCannotAffectANewerSession() async throws {
        var submitted: [String] = []
        var cancelled: [String] = []
        var staleCompletions: [Bool] = []
        let background = BackgroundGPUAccess(supported: true, identifierPattern: "test.gpu.*", submit: { submitted.append($0) }, cancel: { cancelled.append($0) })
        await background.update(running: true, foreground: true, chunks: 0)
        let old = try XCTUnwrap(submitted.first)
        background.stop()
        await background.update(running: true, foreground: true, chunks: 0)
        let current = try XCTUnwrap(submitted.last)
        background.accept(identifier: current, progress: Progress()) { _ in }
        background.accept(identifier: old, progress: Progress()) { staleCompletions.append($0) }
        background.expire(identifier: old)
        XCTAssertEqual(cancelled, [old])
        XCTAssertEqual(staleCompletions, [false])
        XCTAssertEqual(background.requestID, current)
        XCTAssertTrue(background.isGranted)
    }

    func testRejectedRequestKeepsForegroundTranslationAvailableWithoutRepeatedSubmissions() async {
        var submissions = 0
        let background = BackgroundGPUAccess(supported: true, identifierPattern: "test.gpu.*", submit: { _ in
            submissions += 1
            throw CocoaError(.userCancelled)
        }, cancel: { _ in })
        await background.update(running: true, foreground: true, chunks: 0)
        await background.update(running: true, foreground: true, chunks: 1)
        XCTAssertFalse(background.isGranted)
        XCTAssertNil(background.requestID)
        XCTAssertEqual(submissions, 1)
    }

    func testStoppingDuringSubmissionCancelsTheLateRequest() async throws {
        var submission: CheckedContinuation<Void, Never>?
        var cancelled: [String] = []
        let background = BackgroundGPUAccess(supported: true, identifierPattern: "test.gpu.*", submit: { _ in
            await withCheckedContinuation { submission = $0 }
        }, cancel: { cancelled.append($0) })
        let update = Task { await background.update(running: true, foreground: true, chunks: 0) }
        while submission == nil {
            await Task.yield()
        }
        let identifier = try XCTUnwrap(background.requestID)
        background.stop()
        submission?.resume()
        await update.value
        XCTAssertTrue(cancelled.contains(identifier))
        XCTAssertFalse(background.isGranted)
        XCTAssertNil(background.requestID)
    }
}
