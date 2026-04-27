import Foundation

/// Filter parameters for memory queries.
public struct MemoryFilter: Sendable {
    public var scope: MemoryScope?
    public var status: MemoryStatus?
    public var statuses: Set<MemoryStatus>?
    public var category: MemoryCategory?
    public var categories: Set<MemoryCategory>?
    public var workspaceId: UUID?
    public var projectId: UUID?
    public var moduleId: UUID?
    public var sessionId: UUID?
    public var tags: Set<String>?
    /// When true, any tag match satisfies the filter. When false, all tags must match.
    public var tagsMatchAll: Bool

    public init(
        scope: MemoryScope? = nil,
        status: MemoryStatus? = nil,
        statuses: Set<MemoryStatus>? = nil,
        category: MemoryCategory? = nil,
        categories: Set<MemoryCategory>? = nil,
        workspaceId: UUID? = nil,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        sessionId: UUID? = nil,
        tags: Set<String>? = nil,
        tagsMatchAll: Bool = false
    ) {
        self.scope = scope
        self.status = status
        self.statuses = statuses
        self.category = category
        self.categories = categories
        self.workspaceId = workspaceId
        self.projectId = projectId
        self.moduleId = moduleId
        self.sessionId = sessionId
        self.tags = tags
        self.tagsMatchAll = tagsMatchAll
    }
}

/// Persistent storage contract for Memory values.
public protocol MemoryStore: Sendable {
    func fetch(id: UUID) async throws -> Memory?
    func save(_ memory: Memory) async throws
    func delete(id: UUID) async throws
    func list() async throws -> [Memory]
    func query(_ filter: MemoryFilter) async throws -> [Memory]
}
