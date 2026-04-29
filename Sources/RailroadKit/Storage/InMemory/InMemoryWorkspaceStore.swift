import Foundation

/// Thread-safe in-memory implementation of WorkspaceStore.
public actor InMemoryWorkspaceStore: WorkspaceStore {

    private var store: [UUID: Workspace] = [:]

    public init() {}

    public func fetch(id: UUID) async throws -> Workspace? {
        store[id]
    }

    public func save(_ workspace: Workspace) async throws {
        store[workspace.id] = workspace
    }

    public func delete(id: UUID) async throws {
        store.removeValue(forKey: id)
    }

    public func list() async throws -> [Workspace] {
        Array(store.values)
    }
}
