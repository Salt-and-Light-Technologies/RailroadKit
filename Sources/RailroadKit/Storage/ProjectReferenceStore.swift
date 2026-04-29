import Foundation

/// Persistent storage contract for ProjectReference values.
public protocol ProjectReferenceStore: Sendable {
    func fetch(id: UUID) async throws -> ProjectReference?
    func save(_ project: ProjectReference) async throws
    func delete(id: UUID) async throws
    func list() async throws -> [ProjectReference]
    func listForWorkspace(workspaceId: UUID) async throws -> [ProjectReference]
}
