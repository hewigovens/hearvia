import Foundation

extension CloudEngine {
    func consume(_ chunk: Data) async {
        guard running else { return }
        chunksReceived += 1
        let silent = silence.isSilent(chunk)
        silentChunks = silent ? silentChunks + 1 : 0
        if paused {
            remember(chunk, limit: timing.preRollChunks)
            if !silent {
                resume()
            }
            return
        }
        guard let socket, socketReady else {
            remember(chunk, limit: timing.connectingChunks)
            if socket == nil, silentChunks >= timing.silenceChunks {
                pause() // Silent while waiting to reconnect: wait for sound instead.
            }
            return
        }
        let pending = backlog + [chunk]
        backlog = []
        for data in pending {
            do {
                try await socket.append(data)
                chunksSent += 1
                continuation.yield(.audioConsumed)
            } catch {
                break // The close event triggers a reconnect.
            }
        }
        if silentChunks >= timing.silenceChunks {
            pause()
        } else {
            rotateIfDue()
        }
    }

    func remember(_ chunk: Data, limit: Int) {
        backlog.append(chunk)
        if backlog.count > limit {
            backlog.removeFirst(backlog.count - limit)
        }
    }

    func pause() {
        guard running, !paused else { return }
        paused = true
        reconnectTask?.cancel()
        reconnectTask = nil
        backlog = Array(backlog.suffix(timing.preRollChunks))
        if let socket {
            self.socket = nil
            socketReady = false
            expiresAt = nil
            retire(socket)
        }
        continuation.yield(.status(.paused))
        continuation.yield(.log("translation_paused", ["silent_chunks": "\(silentChunks)", "received": "\(chunksReceived)", "sent": "\(chunksSent)"]))
    }

    func resume() {
        paused = false
        continuation.yield(.log("translation_resumed", ["preroll_chunks": "\(backlog.count)"]))
        Task { await connect() }
    }

    /// Replaces the socket before the session expires: early at a silent moment, or at the deadline regardless.
    func rotateIfDue() {
        guard let expiresAt else { return }
        let left = expiresAt.timeIntervalSince(timing.now())
        guard left <= timing.rotationDeadline || (left <= timing.rotationLead && silentChunks >= timing.pauseChunks) else { return }
        rotate(reason: "expiry")
    }
}
