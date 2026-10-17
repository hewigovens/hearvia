@testable import Hearvia
import XCTest

@MainActor
final class BackgroundTranslationTests: XCTestCase {
    func testRegistersConcreteSessionIdentifiersPermittedByTheApp() throws {
        let adapter = BackgroundTranslation(log: DiagnosticLog())
        for _ in 0 ..< 2 {
            let identifier = BackgroundTranslation.identifierPattern.replacingOccurrences(of: "*", with: UUID().uuidString)
            try adapter.register(identifier: identifier)
        }
    }
}
