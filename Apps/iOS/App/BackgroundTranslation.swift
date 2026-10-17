import BackgroundTasks
import Foundation
import HearviaSession

@MainActor
final class BackgroundTranslation {
    static let identifierPattern = "dev.hewig.hearvia.gemma.*"
    static var isSupported: Bool {
        BGTaskScheduler.supportedResources.contains(.gpu)
    }
    private weak var access: BackgroundGPUAccess?
    private let log: DiagnosticLog

    init(log: DiagnosticLog) {
        self.log = log
    }

    static func make(log: DiagnosticLog) -> BackgroundGPUAccess {
        let adapter = BackgroundTranslation(log: log)
        let access = BackgroundGPUAccess(supported: Self.isSupported, identifierPattern: Self.identifierPattern, submit: adapter.submit,
                                         cancel: { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: $0) }, log: log.event)
        adapter.access = access
        log.event("background_gpu_support", ["supported": "\(Self.isSupported)"])
        return access
    }

    func register(identifier: String) throws {
        let access = access
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { [weak access] task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            MainActor.assumeIsolated {
                guard let access else { task.setTaskCompleted(success: false)
                    return
                }
                task.expirationHandler = { [weak access, identifier = task.identifier] in
                    Task { @MainActor in access?.expire(identifier: identifier) }
                }
                access.accept(identifier: task.identifier, progress: task.progress) { task.setTaskCompleted(success: $0) }
            }
        }
        log.event("background_gpu_registration", ["identifier": identifier, "registered": "\(registered)"])
        guard registered else {
            throw NSError(domain: "Hearvia.BackgroundTranslation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "iOS couldn't start background translation."])
        }
    }

    private func submit(identifier: String) async throws {
        try register(identifier: identifier)
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Live translation", subtitle: "Listening with TranslateGemma")
        request.requiredResources = .gpu
        request.strategy = .fail
        try await BGTaskScheduler.shared.submitTaskRequest(request)
    }
}
