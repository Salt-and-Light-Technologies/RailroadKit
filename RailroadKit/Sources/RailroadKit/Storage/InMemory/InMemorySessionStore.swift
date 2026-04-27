import Foundation

/// Thread-safe in-memory implementation of SessionStore.
public actor InMemorySessionStore: SessionStore {

    private var store: [UUID: Session] = [:]

    public init() {}

    public func fetch(id: UUID) async throws -> Session? {
        store[id]
    }

    public func save(_ session: Session) async throws {
        store[session.id] = session
    }

    public func delete(id: UUID) async throws {
        store.removeValue(forKey: id)
    }

    public func list() async throws -> [Session] {
        Array(store.values)
    }

    public func query(_ filter: SessionFilter) async throws -> [Session] {
        store.values.filter { session in
            if let status = filter.status, session.status != status { return false }
            if let workspaceId = filter.workspaceId, session.workspaceId != workspaceId { return false }
            if let projectId = filter.projectId, session.projectId != projectId { return false }
            return true
        }
    }
}
