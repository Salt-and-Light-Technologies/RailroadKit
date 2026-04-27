import Foundation

/// Errors thrown by DecisionService operations.
public enum DecisionServiceError: Error, Sendable {
    case decisionNotFound(UUID)
    case invalidStatusTransition(from: DecisionStatus, to: DecisionStatus)
}

/// Manages the lifecycle of Decision values.
public final class DecisionService: Sendable {

    private let store: any DecisionStore

    public init(store: any DecisionStore) {
        self.store = store
    }

    // MARK: - Creation

    @discardableResult
    public func createDecision(
        title: String,
        content: String,
        rationale: String? = nil,
        scope: MemoryScope,
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        sessionId: UUID? = nil,
        relatedMemoryIds: [UUID] = []
    ) async throws -> Decision {
        let decision = Decision(
            title: title,
            content: content,
            rationale: rationale,
            scope: scope,
            status: .proposed,
            workspaceId: workspaceId,
            projectId: projectId,
            moduleId: moduleId,
            sessionId: sessionId,
            relatedMemoryIds: relatedMemoryIds
        )
        try await store.save(decision)
        return decision
    }

    // MARK: - Status Transitions

    @discardableResult
    public func acceptDecision(id: UUID) async throws -> Decision {
        var decision = try await requireDecision(id: id)
        guard decision.status == .proposed else {
            throw DecisionServiceError.invalidStatusTransition(from: decision.status, to: .accepted)
        }
        decision.status = .accepted
        decision.updatedAt = Date()
        try await store.save(decision)
        return decision
    }

    @discardableResult
    public func rejectDecision(id: UUID) async throws -> Decision {
        var decision = try await requireDecision(id: id)
        guard decision.status == .proposed else {
            throw DecisionServiceError.invalidStatusTransition(from: decision.status, to: .rejected)
        }
        decision.status = .rejected
        decision.updatedAt = Date()
        try await store.save(decision)
        return decision
    }

    /// Marks a decision as superseded, optionally linking the replacement.
    @discardableResult
    public func supersede(id: UUID) async throws -> Decision {
        var decision = try await requireDecision(id: id)
        guard decision.status == .accepted || decision.status == .proposed else {
            throw DecisionServiceError.invalidStatusTransition(from: decision.status, to: .superseded)
        }
        decision.status = .superseded
        decision.updatedAt = Date()
        try await store.save(decision)
        return decision
    }

    // MARK: - Updates

    @discardableResult
    public func updateDecision(
        id: UUID,
        title: String? = nil,
        content: String? = nil,
        rationale: String? = nil,
        relatedMemoryIds: [UUID]? = nil
    ) async throws -> Decision {
        var decision = try await requireDecision(id: id)
        if let title { decision.title = title }
        if let content { decision.content = content }
        if let rationale { decision.rationale = rationale }
        if let relatedMemoryIds { decision.relatedMemoryIds = relatedMemoryIds }
        decision.updatedAt = Date()
        try await store.save(decision)
        return decision
    }

    // MARK: - Retrieval

    public func fetchDecision(id: UUID) async throws -> Decision? {
        try await store.fetch(id: id)
    }

    public func acceptedDecisions(projectId: UUID? = nil, sessionId: UUID? = nil) async throws -> [Decision] {
        let filter = DecisionFilter(status: .accepted, projectId: projectId, sessionId: sessionId)
        return try await store.query(filter)
    }

    public func allDecisions(filter: DecisionFilter? = nil) async throws -> [Decision] {
        if let filter {
            return try await store.query(filter)
        }
        return try await store.list()
    }

    // MARK: - Deletion

    public func deleteDecision(id: UUID) async throws {
        try await store.delete(id: id)
    }

    // MARK: - Helpers

    private func requireDecision(id: UUID) async throws -> Decision {
        guard let decision = try await store.fetch(id: id) else {
            throw DecisionServiceError.decisionNotFound(id)
        }
        return decision
    }
}
