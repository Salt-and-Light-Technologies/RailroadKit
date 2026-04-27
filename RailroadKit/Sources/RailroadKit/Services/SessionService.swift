import Foundation

/// Errors thrown by SessionService operations.
public enum SessionServiceError: Error, Sendable {
    case sessionNotFound(UUID)
    case invalidStatusTransition(from: SessionStatus, to: SessionStatus)
}

/// Manages Session lifecycle and the association of memories/decisions with sessions.
public final class SessionService: Sendable {

    private let store: any SessionStore

    public init(store: any SessionStore) {
        self.store = store
    }

    // MARK: - Creation

    @discardableResult
    public func createSession(
        title: String,
        objective: String,
        workspaceId: UUID? = nil,
        projectId: UUID? = nil
    ) async throws -> Session {
        let session = Session(
            title: title,
            objective: objective,
            workspaceId: workspaceId,
            projectId: projectId
        )
        try await store.save(session)
        return session
    }

    // MARK: - Status Transitions

    @discardableResult
    public func pauseSession(id: UUID) async throws -> Session {
        var session = try await requireSession(id: id)
        guard session.status == .active else {
            throw SessionServiceError.invalidStatusTransition(from: session.status, to: .paused)
        }
        session.status = .paused
        session.updatedAt = Date()
        try await store.save(session)
        return session
    }

    @discardableResult
    public func resumeSession(id: UUID) async throws -> Session {
        var session = try await requireSession(id: id)
        guard session.status == .paused else {
            throw SessionServiceError.invalidStatusTransition(from: session.status, to: .active)
        }
        session.status = .active
        session.updatedAt = Date()
        try await store.save(session)
        return session
    }

    @discardableResult
    public func completeSession(id: UUID) async throws -> Session {
        var session = try await requireSession(id: id)
        guard session.status == .active || session.status == .paused else {
            throw SessionServiceError.invalidStatusTransition(from: session.status, to: .completed)
        }
        session.status = .completed
        session.updatedAt = Date()
        try await store.save(session)
        return session
    }

    @discardableResult
    public func archiveSession(id: UUID) async throws -> Session {
        var session = try await requireSession(id: id)
        session.status = .archived
        session.updatedAt = Date()
        try await store.save(session)
        return session
    }

    // MARK: - Association

    /// Links a memory ID to a session.
    @discardableResult
    public func addMemory(id memoryId: UUID, toSession sessionId: UUID) async throws -> Session {
        var session = try await requireSession(id: sessionId)
        if !session.memoryIds.contains(memoryId) {
            session.memoryIds.append(memoryId)
            session.updatedAt = Date()
            try await store.save(session)
        }
        return session
    }

    /// Removes a memory ID from a session.
    @discardableResult
    public func removeMemory(id memoryId: UUID, fromSession sessionId: UUID) async throws -> Session {
        var session = try await requireSession(id: sessionId)
        session.memoryIds.removeAll { $0 == memoryId }
        session.updatedAt = Date()
        try await store.save(session)
        return session
    }

    /// Links a decision ID to a session.
    @discardableResult
    public func addDecision(id decisionId: UUID, toSession sessionId: UUID) async throws -> Session {
        var session = try await requireSession(id: sessionId)
        if !session.decisionIds.contains(decisionId) {
            session.decisionIds.append(decisionId)
            session.updatedAt = Date()
            try await store.save(session)
        }
        return session
    }

    // MARK: - Notes

    @discardableResult
    public func updateNotes(_ notes: String, forSession sessionId: UUID) async throws -> Session {
        var session = try await requireSession(id: sessionId)
        session.notes = notes
        session.updatedAt = Date()
        try await store.save(session)
        return session
    }

    // MARK: - Retrieval

    public func fetchSession(id: UUID) async throws -> Session? {
        try await store.fetch(id: id)
    }

    public func activeSessions(projectId: UUID? = nil) async throws -> [Session] {
        let filter = SessionFilter(status: .active, projectId: projectId)
        return try await store.query(filter)
    }

    public func allSessions(filter: SessionFilter? = nil) async throws -> [Session] {
        if let filter {
            return try await store.query(filter)
        }
        return try await store.list()
    }

    // MARK: - Deletion

    public func deleteSession(id: UUID) async throws {
        try await store.delete(id: id)
    }

    // MARK: - Helpers

    private func requireSession(id: UUID) async throws -> Session {
        guard let session = try await store.fetch(id: id) else {
            throw SessionServiceError.sessionNotFound(id)
        }
        return session
    }
}
