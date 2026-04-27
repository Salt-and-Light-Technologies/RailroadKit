import Foundation

/// Thread-safe in-memory implementation of MemoryStore.
///
/// Intended for unit tests and development. Not persisted across process restarts.
public actor InMemoryMemoryStore: MemoryStore {

    private var store: [UUID: Memory] = [:]

    public init() {}

    public func fetch(id: UUID) async throws -> Memory? {
        store[id]
    }

    public func save(_ memory: Memory) async throws {
        store[memory.id] = memory
    }

    public func delete(id: UUID) async throws {
        store.removeValue(forKey: id)
    }

    public func list() async throws -> [Memory] {
        Array(store.values)
    }

    public func query(_ filter: MemoryFilter) async throws -> [Memory] {
        store.values.filter { memory in
            if let scope = filter.scope, memory.scope != scope { return false }
            if let status = filter.status, memory.status != status { return false }
            if let statuses = filter.statuses, !statuses.contains(memory.status) { return false }
            if let category = filter.category, memory.category != category { return false }
            if let categories = filter.categories, !categories.contains(memory.category) { return false }
            if let workspaceId = filter.workspaceId, memory.workspaceId != workspaceId { return false }
            if let projectId = filter.projectId, memory.projectId != projectId { return false }
            if let moduleId = filter.moduleId, memory.moduleId != moduleId { return false }
            if let sessionId = filter.sessionId, memory.sessionId != sessionId { return false }
            if let tags = filter.tags, !tags.isEmpty {
                let memoryTags = Set(memory.tags)
                if filter.tagsMatchAll {
                    if !tags.isSubset(of: memoryTags) { return false }
                } else {
                    if tags.isDisjoint(with: memoryTags) { return false }
                }
            }
            return true
        }
    }
}
