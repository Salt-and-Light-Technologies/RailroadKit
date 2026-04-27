import Foundation

/// Thread-safe in-memory implementation of ModuleReferenceStore.
public actor InMemoryModuleReferenceStore: ModuleReferenceStore {

    private var store: [UUID: ModuleReference] = [:]

    public init() {}

    public func fetch(id: UUID) async throws -> ModuleReference? {
        store[id]
    }

    public func save(_ module: ModuleReference) async throws {
        store[module.id] = module
    }

    public func delete(id: UUID) async throws {
        store.removeValue(forKey: id)
    }

    public func list() async throws -> [ModuleReference] {
        Array(store.values)
    }

    public func listForProject(projectId: UUID) async throws -> [ModuleReference] {
        store.values.filter { $0.projectId == projectId }
    }
}
