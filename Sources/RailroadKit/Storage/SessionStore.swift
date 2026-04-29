import Foundation

/// Filter parameters for session queries.
public struct SessionFilter: Sendable {
    public var status: SessionStatus?
    public var workspaceId: UUID?
    public var projectId: UUID?

    public init(
        status: SessionStatus? = nil,
        workspaceId: UUID? = nil,
        projectId: UUID? = nil
    ) {
        self.status = status
        self.workspaceId = workspaceId
        self.projectId = projectId
    }
}

/// Persistent storage contract for Session values.
public protocol SessionStore: Sendable {
    func fetch(id: UUID) async throws -> Session?
    func save(_ session: Session) async throws
    func delete(id: UUID) async throws
    func list() async throws -> [Session]
    func query(_ filter: SessionFilter) async throws -> [Session]
}
