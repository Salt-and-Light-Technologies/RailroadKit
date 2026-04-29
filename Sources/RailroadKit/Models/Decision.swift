import Foundation

/// Records a deliberate choice made during a task or project.
///
/// Decisions are distinct from memories — they represent a commitment
/// with a title, rationale, and explicit status lifecycle.
public struct Decision: Codable, Hashable, Identifiable, Sendable {

    // MARK: - Identity

    public let id: UUID
    public var title: String
    public var content: String
    /// Why this decision was made.
    public var rationale: String?

    // MARK: - Classification

    public var scope: MemoryScope
    public var status: DecisionStatus

    // MARK: - Scope References

    public var workspaceId: UUID?
    public var projectId: UUID?
    public var moduleId: UUID?
    public var sessionId: UUID?

    // MARK: - Relationships

    /// IDs of memories that provide supporting context for this decision.
    public var relatedMemoryIds: [UUID]

    // MARK: - Timestamps

    public let createdAt: Date
    public var updatedAt: Date

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        rationale: String? = nil,
        scope: MemoryScope,
        status: DecisionStatus = .proposed,
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        sessionId: UUID? = nil,
        relatedMemoryIds: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.rationale = rationale
        self.scope = scope
        self.status = status
        self.workspaceId = workspaceId
        self.projectId = projectId
        self.moduleId = moduleId
        self.sessionId = sessionId
        self.relatedMemoryIds = relatedMemoryIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
