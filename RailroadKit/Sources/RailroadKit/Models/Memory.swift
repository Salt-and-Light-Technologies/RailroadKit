import Foundation

/// A durable unit of knowledge: a fact, preference, constraint, decision
/// note, gotcha, warning, or task state.
///
/// Memories are value types. Services own mutation; the model carries no logic.
public struct Memory: Codable, Hashable, Identifiable, Sendable {

    // MARK: - Identity

    public let id: UUID
    /// Human-readable text content of the memory.
    public var content: String

    // MARK: - Classification

    public var scope: MemoryScope
    public var category: MemoryCategory
    public var status: MemoryStatus

    // MARK: - Relevance Signals

    /// How important this memory is for context generation (0.0–1.0).
    public var importance: Double
    /// How confident we are in the accuracy of this memory (0.0–1.0).
    public var confidence: Double
    /// Arbitrary labels for filtering and grouping.
    public var tags: [String]

    // MARK: - Scope References
    // All optional — a global memory will leave these nil.

    public var workspaceId: UUID?
    public var projectId: UUID?
    public var moduleId: UUID?
    public var sessionId: UUID?

    // MARK: - Provenance

    public var source: MemorySource

    // MARK: - Timestamps

    public let createdAt: Date
    public var updatedAt: Date
    /// Set by the retrieval service when this memory is included in a result.
    public var lastAccessedAt: Date?
    /// After this date the memory should be treated as expired. nil = never expires.
    public var expiresAt: Date?
    /// Set when status transitions to .archived.
    public var archivedAt: Date?

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        content: String,
        scope: MemoryScope,
        category: MemoryCategory,
        status: MemoryStatus = .suggested,
        importance: Double = 0.5,
        confidence: Double = 0.8,
        tags: [String] = [],
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        sessionId: UUID? = nil,
        source: MemorySource,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        expiresAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.scope = scope
        self.category = category
        self.status = status
        self.importance = importance
        self.confidence = confidence
        self.tags = tags
        self.workspaceId = workspaceId
        self.projectId = projectId
        self.moduleId = moduleId
        self.sessionId = sessionId
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
        self.expiresAt = expiresAt
        self.archivedAt = archivedAt
    }
}
