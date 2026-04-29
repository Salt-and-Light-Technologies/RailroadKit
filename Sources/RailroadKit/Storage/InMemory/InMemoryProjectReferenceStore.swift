import Foundation

/// Thread-safe in-memory implementation of ProjectReferenceStore.
public actor InMemoryProjectReferenceStore: ProjectReferenceStore {

    private var store: [UUID: ProjectReference] = [:]

    public init() {}

    public func fetch(id: UUID) async throws -> ProjectReference? {
        store[id]
    }

    public func save(_ project: ProjectReference) async throws {
        store[project.id] = project
    }

    public func delete(id: UUID) async throws {
        store.removeValue(forKey: id)
    }

    public func list() async throws -> [ProjectReference] {
        Array(store.values)
    }

    public func listForWorkspace(workspaceId: UUID) async throws -> [ProjectReference] {
        store.values.filter { $0.workspaceId == workspaceId }
    }
}
