import Foundation

/// Persistent storage contract for ModuleReference values.
public protocol ModuleReferenceStore: Sendable {
    func fetch(id: UUID) async throws -> ModuleReference?
    func save(_ module: ModuleReference) async throws
    func delete(id: UUID) async throws
    func list() async throws -> [ModuleReference]
    func listForProject(projectId: UUID) async throws -> [ModuleReference]
}
