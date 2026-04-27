import Foundation

/// The lifecycle status of a session.
public enum SessionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case paused
    case completed
    case archived
}

/// Represents one active task or conversation thread.
///
/// A session ties together a set of memories, decisions, and a stated
/// objective. It is the primary unit of task continuity in RailroadKit.
public struct Session: Codable, Hashable, Identifiable, Sendable {

    // MARK: - Identity

    public let id: UUID
    public var title: String
    /// The stated goal for this session.
    public var objective: String

    // MARK: - Scope References

    public var workspaceId: UUID?
    public var projectId: UUID?
    /// Module IDs that are currently in focus for this session.
    public var activeModuleIds: [UUID]

    // MARK: - Status

    public var status: SessionStatus

    // MARK: - Linked Records

    /// IDs of memories that belong to this session.
    public var memoryIds: [UUID]
    /// IDs of decisions made in this session.
    public var decisionIds: [UUID]
    /// Free-form session notes (not stored as memories).
    public var notes: String

    // MARK: - Context Pack Tracking

    /// The ID of the most recently generated context pack for this session.
    /// Populated by ContextComposerKit, not by RailroadKit itself.
    public var lastGeneratedContextPackId: String?

    // MARK: - Timestamps

    public let createdAt: Date
    public var updatedAt: Date

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        title: String,
        objective: String,
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        activeModuleIds: [UUID] = [],
        status: SessionStatus = .active,
        memoryIds: [UUID] = [],
        decisionIds: [UUID] = [],
        notes: String = "",
        lastGeneratedContextPackId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.objective = objective
        self.workspaceId = workspaceId
        self.projectId = projectId
        self.activeModuleIds = activeModuleIds
        self.status = status
        self.memoryIds = memoryIds
        self.decisionIds = decisionIds
        self.notes = notes
        self.lastGeneratedContextPackId = lastGeneratedContextPackId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
