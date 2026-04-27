import Foundation

/// Thread-safe in-memory implementation of DecisionStore.
public actor InMemoryDecisionStore: DecisionStore {

    private var store: [UUID: Decision] = [:]

    public init() {}

    public func fetch(id: UUID) async throws -> Decision? {
        store[id]
    }

    public func save(_ decision: Decision) async throws {
        store[decision.id] = decision
    }

    public func delete(id: UUID) async throws {
        store.removeValue(forKey: id)
    }

    public func list() async throws -> [Decision] {
        Array(store.values)
    }

    public func query(_ filter: DecisionFilter) async throws -> [Decision] {
        store.values.filter { decision in
            if let scope = filter.scope, decision.scope != scope { return false }
            if let status = filter.status, decision.status != status { return false }
            if let projectId = filter.projectId, decision.projectId != projectId { return false }
            if let sessionId = filter.sessionId, decision.sessionId != sessionId { return false }
            return true
        }
    }
}
