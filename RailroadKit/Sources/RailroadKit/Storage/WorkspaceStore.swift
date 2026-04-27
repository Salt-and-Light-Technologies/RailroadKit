import Foundation

/// Persistent storage contract for Workspace values.
public protocol WorkspaceStore: Sendable {
    func fetch(id: UUID) async throws -> Workspace?
    func save(_ workspace: Workspace) async throws
    func delete(id: UUID) async throws
    func list() async throws -> [Workspace]
}
