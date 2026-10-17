import BackgroundTasks
import HearviaSession

@MainActor
enum BackgroundTranslation {
    static let identifierPattern = "dev.hewig.hearvia.gemma.*"
    static var isSupported: Bool {
        BGTaskScheduler.supportedResources.contains(.gpu)
    }

    static func make(log: DiagnosticLog) -> BackgroundGPUAccess {
        let access = BackgroundGPUAccess(supported: Self.isSupported, identifierPattern: Self.identifierPattern, submit: { identifier in
            let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Live translation", subtitle: "Listening with TranslateGemma")
            request.requiredResources = .gpu
            request.strategy = .fail
            try await BGTaskScheduler.shared.submitTaskRequest(request)
        }, cancel: { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: $0) }, log: log.event)
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifierPattern, using: .main) { [weak access] task in
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
        log.event("background_gpu_support", ["supported": "\(Self.isSupported)", "registered": "\(registered)"])
        return access
    }
}
