import Foundation

/// Filter parameters for decision queries.
public struct DecisionFilter: Sendable {
    public var scope: MemoryScope?
    public var status: DecisionStatus?
    public var projectId: UUID?
    public var sessionId: UUID?

    public init(
        scope: MemoryScope? = nil,
        status: DecisionStatus? = nil,
        projectId: UUID? = nil,
        sessionId: UUID? = nil
    ) {
        self.scope = scope
        self.status = status
        self.projectId = projectId
        self.sessionId = sessionId
    }
}

/// Persistent storage contract for Decision values.
public protocol DecisionStore: Sendable {
    func fetch(id: UUID) async throws -> Decision?
    func save(_ decision: Decision) async throws
    func delete(id: UUID) async throws
    func list() async throws -> [Decision]
    func query(_ filter: DecisionFilter) async throws -> [Decision]
}
