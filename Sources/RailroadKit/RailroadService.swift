import Foundation

/// The top-level coordinator for RailroadKit.
///
/// RailroadService wires together all smaller services and provides a single
/// convenient entry point for application code. It does not implement business
/// logic directly — every method delegates immediately to the appropriate service.
///
/// Construct one instance per application and inject it where needed. Do not
/// use it as a singleton.
///
/// Example:
/// ```swift
/// let railroad = RailroadService()
/// let session = try await railroad.sessions.createSession(
///     title: "Refactor auth flow",
///     objective: "Extract auth logic into a dedicated AuthService"
/// )
/// let memory = try await railroad.memories.createSuggestedMemory(
///     content: "Auth tokens expire after 15 minutes",
///     scope: .project,
///     category: .projectFact,
///     projectId: myProjectId,
///     source: MemorySource(sourceType: .userEntered)
/// )
/// try await railroad.memories.approveMemory(id: memory.id)
/// ```
public final class RailroadService: Sendable {

    // MARK: - Services (public, composable)

    public let memories: MemoryService
    public let sessions: SessionService
    public let decisions: DecisionService
    public let pruner: MemoryPruner
    public let scorer: MemoryRelevanceScorer
    public let importExport: ImportExportService

    // MARK: - Stores (accessible for advanced usage)

    public let memoryStore: any MemoryStore
    public let sessionStore: any SessionStore
    public let decisionStore: any DecisionStore
    public let workspaceStore: any WorkspaceStore
    public let projectStore: any ProjectReferenceStore
    public let moduleStore: any ModuleReferenceStore

    // MARK: - Init

    /// Creates a RailroadService with injected stores.
    ///
    /// All stores default to in-memory implementations, which is suitable
    /// for development and testing. Replace with persistent implementations
    /// for production use.
    public init(
        memoryStore: any MemoryStore = InMemoryMemoryStore(),
        sessionStore: any SessionStore = InMemorySessionStore(),
        decisionStore: any DecisionStore = InMemoryDecisionStore(),
        workspaceStore: any WorkspaceStore = InMemoryWorkspaceStore(),
        projectStore: any ProjectReferenceStore = InMemoryProjectReferenceStore(),
        moduleStore: any ModuleReferenceStore = InMemoryModuleReferenceStore(),
        tokenEstimator: any TokenEstimating = SimpleTokenEstimator()
    ) {
        self.memoryStore = memoryStore
        self.sessionStore = sessionStore
        self.decisionStore = decisionStore
        self.workspaceStore = workspaceStore
        self.projectStore = projectStore
        self.moduleStore = moduleStore

        self.memories = MemoryService(store: memoryStore)
        self.sessions = SessionService(store: sessionStore)
        self.decisions = DecisionService(store: decisionStore)
        self.pruner = MemoryPruner(tokenEstimator: tokenEstimator)
        self.scorer = MemoryRelevanceScorer()
        self.importExport = ImportExportService(
            memoryStore: memoryStore,
            decisionStore: decisionStore,
            sessionStore: sessionStore
        )
    }

    // MARK: - Convenience: Pruned context for a session

    /// Returns a pruned set of approved memories relevant to the given session.
    ///
    /// This is the primary method ContextComposerKit will call when building
    /// a prompt pack for an active session.
    public func prunedMemories(
        for session: Session,
        config: MemoryPruningConfig = MemoryPruningConfig()
    ) async throws -> MemoryPruningResult {
        let allMemories = try await memoryStore.list()
        return pruner.prune(
            candidates: allMemories,
            config: config,
            activeProjectId: session.projectId,
            activeSessionId: session.id,
            activeModuleIds: Set(session.activeModuleIds)
        )
    }

    // MARK: - Convenience: Relevant memories for a query

    /// Scores and returns approved memories ranked by relevance to `query`.
    public func relevantMemories(
        for query: RelevanceQuery
    ) async throws -> [ScoredMemory] {
        let approved = try await memoryStore.query(MemoryFilter(status: .approved))
        return scorer.score(memories: approved, query: query)
    }
}
