import Foundation

/// Errors thrown by MemoryService operations.
public enum MemoryServiceError: Error, Sendable {
    case memoryNotFound(UUID)
    case invalidStatusTransition(from: MemoryStatus, to: MemoryStatus)
    case invalidImportance(Double)
    case invalidConfidence(Double)
}

/// Manages the full lifecycle of Memory values.
///
/// This service owns all state transitions (suggested → approved,
/// approved → archived, etc.) and enforces the rule that suggested
/// memories are never silently promoted to approved status.
///
/// It does not fetch memories for context packs — that is MemoryPruner's
/// and MemoryRelevanceScorer's responsibility.
public final class MemoryService: Sendable {

    private let store: any MemoryStore

    public init(store: any MemoryStore) {
        self.store = store
    }

    // MARK: - Creation

    /// Creates a new memory with `.suggested` status.
    ///
    /// Suggested memories are not returned by default retrieval paths
    /// until explicitly approved.
    @discardableResult
    public func createSuggestedMemory(
        content: String,
        scope: MemoryScope,
        category: MemoryCategory,
        importance: Double = 0.5,
        confidence: Double = 0.8,
        tags: [String] = [],
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        sessionId: UUID? = nil,
        source: MemorySource
    ) async throws -> Memory {
        try validateImportance(importance)
        try validateConfidence(confidence)
        let memory = Memory(
            content: content,
            scope: scope,
            category: category,
            status: .suggested,
            importance: importance,
            confidence: confidence,
            tags: tags,
            workspaceId: workspaceId,
            projectId: projectId,
            moduleId: moduleId,
            sessionId: sessionId,
            source: source
        )
        try await store.save(memory)
        return memory
    }

    /// Creates a new memory with `.approved` status for direct user entry.
    @discardableResult
    public func createApprovedMemory(
        content: String,
        scope: MemoryScope,
        category: MemoryCategory,
        importance: Double = 0.5,
        confidence: Double = 0.9,
        tags: [String] = [],
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        sessionId: UUID? = nil,
        source: MemorySource
    ) async throws -> Memory {
        try validateImportance(importance)
        try validateConfidence(confidence)
        let memory = Memory(
            content: content,
            scope: scope,
            category: category,
            status: .approved,
            importance: importance,
            confidence: confidence,
            tags: tags,
            workspaceId: workspaceId,
            projectId: projectId,
            moduleId: moduleId,
            sessionId: sessionId,
            source: source
        )
        try await store.save(memory)
        return memory
    }

    // MARK: - Approval Workflow

    /// Transitions a suggested (or stale) memory to approved.
    @discardableResult
    public func approveMemory(id: UUID) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        guard memory.status == .suggested || memory.status == .stale else {
            throw MemoryServiceError.invalidStatusTransition(from: memory.status, to: .approved)
        }
        memory.status = .approved
        memory.updatedAt = Date()
        try await store.save(memory)
        return memory
    }

    /// Transitions a memory to rejected status.
    @discardableResult
    public func rejectMemory(id: UUID) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        guard memory.status == .suggested || memory.status == .stale else {
            throw MemoryServiceError.invalidStatusTransition(from: memory.status, to: .rejected)
        }
        memory.status = .rejected
        memory.updatedAt = Date()
        try await store.save(memory)
        return memory
    }

    /// Transitions a memory to archived status and stamps archivedAt.
    @discardableResult
    public func archiveMemory(id: UUID) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        let now = Date()
        memory.status = .archived
        memory.archivedAt = now
        memory.updatedAt = now
        try await store.save(memory)
        return memory
    }

    /// Marks a previously approved memory as stale (likely outdated).
    @discardableResult
    public func markMemoryStale(id: UUID) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        guard memory.status == .approved else {
            throw MemoryServiceError.invalidStatusTransition(from: memory.status, to: .stale)
        }
        memory.status = .stale
        memory.updatedAt = Date()
        try await store.save(memory)
        return memory
    }

    // MARK: - Updates

    /// Applies a partial update to a memory.
    ///
    /// Fields left nil are unchanged.
    @discardableResult
    public func updateMemory(
        id: UUID,
        content: String? = nil,
        category: MemoryCategory? = nil,
        importance: Double? = nil,
        confidence: Double? = nil,
        tags: [String]? = nil,
        expiresAt: Date?? = nil  // Double-optional: nil = don't touch, .some(nil) = clear
    ) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        if let content { memory.content = content }
        if let category { memory.category = category }
        if let importance {
            try validateImportance(importance)
            memory.importance = importance
        }
        if let confidence {
            try validateConfidence(confidence)
            memory.confidence = confidence
        }
        if let tags { memory.tags = tags }
        if let expiresAt { memory.expiresAt = expiresAt }
        memory.updatedAt = Date()
        try await store.save(memory)
        return memory
    }

    /// Moves a memory to a broader or different scope.
    @discardableResult
    public func promoteMemoryToScope(id: UUID, scope: MemoryScope) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        memory.scope = scope
        memory.updatedAt = Date()
        try await store.save(memory)
        return memory
    }

    /// Changes the category of a memory.
    @discardableResult
    public func changeMemoryCategory(id: UUID, category: MemoryCategory) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        memory.category = category
        memory.updatedAt = Date()
        try await store.save(memory)
        return memory
    }

    // MARK: - Retrieval

    public func fetchMemory(id: UUID) async throws -> Memory? {
        try await store.fetch(id: id)
    }

    /// Returns all approved memories, optionally filtered.
    public func approvedMemories(filter: MemoryFilter? = nil) async throws -> [Memory] {
        var f = filter ?? MemoryFilter()
        f.status = .approved
        return try await store.query(f)
    }

    /// Returns all suggested (pending review) memories.
    public func suggestedMemories(filter: MemoryFilter? = nil) async throws -> [Memory] {
        var f = filter ?? MemoryFilter()
        f.status = .suggested
        return try await store.query(f)
    }

    /// Returns all stale memories.
    public func staleMemories(filter: MemoryFilter? = nil) async throws -> [Memory] {
        var f = filter ?? MemoryFilter()
        f.status = .stale
        return try await store.query(f)
    }

    /// Records that a memory was accessed, updating lastAccessedAt.
    @discardableResult
    public func touchMemory(id: UUID) async throws -> Memory {
        var memory = try await requireMemory(id: id)
        memory.lastAccessedAt = Date()
        try await store.save(memory)
        return memory
    }

    // MARK: - Deletion

    public func deleteMemory(id: UUID) async throws {
        try await store.delete(id: id)
    }

    // MARK: - Helpers

    private func requireMemory(id: UUID) async throws -> Memory {
        guard let memory = try await store.fetch(id: id) else {
            throw MemoryServiceError.memoryNotFound(id)
        }
        return memory
    }

    private func validateImportance(_ value: Double) throws {
        guard (0.0...1.0).contains(value) else {
            throw MemoryServiceError.invalidImportance(value)
        }
    }

    private func validateConfidence(_ value: Double) throws {
        guard (0.0...1.0).contains(value) else {
            throw MemoryServiceError.invalidConfidence(value)
        }
    }
}
