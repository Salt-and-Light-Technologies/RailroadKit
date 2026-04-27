import Foundation

// MARK: - Configuration

/// Controls which memories are eligible and how they are ranked and capped.
public struct MemoryPruningConfig: Sendable {

    /// Hard cap on the number of memories returned.
    public var maxMemoryCount: Int
    /// Optional approximate token budget across all selected memories.
    public var maxEstimatedTokens: Int?

    // MARK: Scope Gates

    public var includeGlobalMemories: Bool
    public var includeWorkspaceMemories: Bool
    public var includeProjectMemories: Bool
    public var includeModuleMemories: Bool
    public var includeSessionMemories: Bool

    // MARK: Status Gates

    /// Include suggested memories (default: false — requires explicit opt-in).
    public var includeSuggestedMemories: Bool
    public var includeStaleMemories: Bool
    public var includeArchivedMemories: Bool
    public var includeRejectedMemories: Bool

    // MARK: Quality Thresholds

    /// Memories below this confidence score are excluded (0.0–1.0).
    public var minimumConfidence: Double

    // MARK: Contextual Hints

    /// Scope preference order. Memories in earlier scopes are ranked higher.
    public var scopePriority: [MemoryScope]
    /// Optional categories to boost in relevance ranking.
    public var preferredCategories: Set<MemoryCategory>?
    /// Tags to match against. Memories sharing tags score higher.
    public var preferredTags: Set<String>?
    /// Only include memories whose tags intersect this set (hard filter).
    public var requiredTags: Set<String>?

    public init(
        maxMemoryCount: Int = 50,
        maxEstimatedTokens: Int? = nil,
        includeGlobalMemories: Bool = true,
        includeWorkspaceMemories: Bool = true,
        includeProjectMemories: Bool = true,
        includeModuleMemories: Bool = true,
        includeSessionMemories: Bool = true,
        includeSuggestedMemories: Bool = false,
        includeStaleMemories: Bool = false,
        includeArchivedMemories: Bool = false,
        includeRejectedMemories: Bool = false,
        minimumConfidence: Double = 0.0,
        scopePriority: [MemoryScope] = [.session, .module, .project, .workspace, .global],
        preferredCategories: Set<MemoryCategory>? = nil,
        preferredTags: Set<String>? = nil,
        requiredTags: Set<String>? = nil
    ) {
        self.maxMemoryCount = maxMemoryCount
        self.maxEstimatedTokens = maxEstimatedTokens
        self.includeGlobalMemories = includeGlobalMemories
        self.includeWorkspaceMemories = includeWorkspaceMemories
        self.includeProjectMemories = includeProjectMemories
        self.includeModuleMemories = includeModuleMemories
        self.includeSessionMemories = includeSessionMemories
        self.includeSuggestedMemories = includeSuggestedMemories
        self.includeStaleMemories = includeStaleMemories
        self.includeArchivedMemories = includeArchivedMemories
        self.includeRejectedMemories = includeRejectedMemories
        self.minimumConfidence = minimumConfidence
        self.scopePriority = scopePriority
        self.preferredCategories = preferredCategories
        self.preferredTags = preferredTags
        self.requiredTags = requiredTags
    }
}

// MARK: - Exclusion Reason

/// Documents why a specific memory was excluded from a pruning result.
public enum ExclusionReason: String, Codable, Sendable {
    case statusRejected
    case statusArchived
    case statusStale
    case statusSuggested
    case scopeExcluded
    case belowMinimumConfidence
    case expired
    case requiredTagsMissing
    case tokenBudgetExceeded
    case countBudgetExceeded
}

/// A memory excluded during pruning, with the reason it was dropped.
public struct ExcludedMemory: Sendable {
    public let memory: Memory
    public let reason: ExclusionReason

    public init(memory: Memory, reason: ExclusionReason) {
        self.memory = memory
        self.reason = reason
    }
}

// MARK: - Result

/// The output of a pruning pass.
public struct MemoryPruningResult: Sendable {
    /// Memories selected for inclusion in a context pack, ordered by relevance score.
    public let selected: [Memory]
    /// Memories that were evaluated but excluded, with reasons.
    public let excluded: [ExcludedMemory]
    /// Approximate token count across all selected memories.
    public let estimatedTokenCount: Int
    /// Non-fatal issues encountered during pruning (e.g. token budget nearly full).
    public let warnings: [String]

    public init(
        selected: [Memory],
        excluded: [ExcludedMemory],
        estimatedTokenCount: Int,
        warnings: [String]
    ) {
        self.selected = selected
        self.excluded = excluded
        self.estimatedTokenCount = estimatedTokenCount
        self.warnings = warnings
    }
}

// MARK: - Pruner

/// Selects a ranked, budget-constrained subset of memories for context generation.
///
/// The pruner is a pure function: it takes a candidate list and configuration,
/// and returns a result. It never touches a store directly — the caller is
/// responsible for fetching candidates.
public struct MemoryPruner: Sendable {

    private let tokenEstimator: any TokenEstimating

    public init(tokenEstimator: any TokenEstimating = SimpleTokenEstimator()) {
        self.tokenEstimator = tokenEstimator
    }

    /// Prunes `candidates` according to `config`.
    ///
    /// - Parameters:
    ///   - candidates: The full pool of memories to consider.
    ///   - config: Rules governing eligibility and ranking.
    ///   - now: The reference date for expiry checks (default: current date).
    ///   - activeProjectId: Boosts memories matching this project.
    ///   - activeSessionId: Boosts memories matching this session.
    ///   - activeModuleIds: Boosts memories matching any of these modules.
    public func prune(
        candidates: [Memory],
        config: MemoryPruningConfig,
        now: Date = Date(),
        activeProjectId: UUID? = nil,
        activeSessionId: UUID? = nil,
        activeModuleIds: Set<UUID> = []
    ) -> MemoryPruningResult {

        var excluded: [ExcludedMemory] = []
        var eligible: [Memory] = []

        // MARK: Pass 1 — Hard Eligibility Filters

        for memory in candidates {
            if let reason = hardExclusionReason(
                memory: memory,
                config: config,
                now: now
            ) {
                excluded.append(ExcludedMemory(memory: memory, reason: reason))
                continue
            }
            eligible.append(memory)
        }

        // MARK: Pass 2 — Soft Scoring + Ranking

        let scored = eligible
            .map { memory -> (Memory, Double) in
                let score = score(
                    memory: memory,
                    config: config,
                    now: now,
                    activeProjectId: activeProjectId,
                    activeSessionId: activeSessionId,
                    activeModuleIds: activeModuleIds
                )
                return (memory, score)
            }
            .sorted { $0.1 > $1.1 }

        // MARK: Pass 3 — Budget Enforcement

        var selected: [Memory] = []
        var tokenTotal = 0
        var warnings: [String] = []

        for (memory, _) in scored {
            if selected.count >= config.maxMemoryCount {
                excluded.append(ExcludedMemory(memory: memory, reason: .countBudgetExceeded))
                continue
            }
            if let maxTokens = config.maxEstimatedTokens {
                let tokens = tokenEstimator.estimateTokens(for: memory.content)
                if tokenTotal + tokens > maxTokens {
                    excluded.append(ExcludedMemory(memory: memory, reason: .tokenBudgetExceeded))
                    continue
                }
                tokenTotal += tokens
            } else {
                tokenTotal += tokenEstimator.estimateTokens(for: memory.content)
            }
            selected.append(memory)
        }

        if let maxTokens = config.maxEstimatedTokens,
           Double(tokenTotal) > Double(maxTokens) * 0.9 {
            warnings.append("Token budget is over 90% utilised (\(tokenTotal)/\(maxTokens)).")
        }

        return MemoryPruningResult(
            selected: selected,
            excluded: excluded,
            estimatedTokenCount: tokenTotal,
            warnings: warnings
        )
    }

    // MARK: - Private Helpers

    private func hardExclusionReason(
        memory: Memory,
        config: MemoryPruningConfig,
        now: Date
    ) -> ExclusionReason? {

        // Rejected is always excluded
        if memory.status == .rejected && !config.includeRejectedMemories {
            return .statusRejected
        }
        if memory.status == .archived && !config.includeArchivedMemories {
            return .statusArchived
        }
        if memory.status == .stale && !config.includeStaleMemories {
            return .statusStale
        }
        if memory.status == .suggested && !config.includeSuggestedMemories {
            return .statusSuggested
        }

        // Scope gates
        switch memory.scope {
        case .global:
            if !config.includeGlobalMemories { return .scopeExcluded }
        case .workspace:
            if !config.includeWorkspaceMemories { return .scopeExcluded }
        case .project:
            if !config.includeProjectMemories { return .scopeExcluded }
        case .module:
            if !config.includeModuleMemories { return .scopeExcluded }
        case .session:
            if !config.includeSessionMemories { return .scopeExcluded }
        }

        // Confidence threshold
        if memory.confidence < config.minimumConfidence {
            return .belowMinimumConfidence
        }

        // Expiry
        if let expiresAt = memory.expiresAt, now >= expiresAt {
            return .expired
        }

        // Required tags (hard filter)
        if let required = config.requiredTags, !required.isEmpty {
            if required.isDisjoint(with: Set(memory.tags)) {
                return .requiredTagsMissing
            }
        }

        return nil
    }

    private func score(
        memory: Memory,
        config: MemoryPruningConfig,
        now: Date,
        activeProjectId: UUID?,
        activeSessionId: UUID?,
        activeModuleIds: Set<UUID>
    ) -> Double {

        var score = 0.0

        // Base signals
        score += memory.importance * 3.0
        score += memory.confidence * 1.0

        // Scope priority (earlier in scopePriority list = higher weight)
        if let index = config.scopePriority.firstIndex(of: memory.scope) {
            let priorityWeight = Double(config.scopePriority.count - index)
            score += priorityWeight * 0.5
        }

        // Contextual relevance
        if let pid = activeProjectId, memory.projectId == pid {
            score += 2.0
        }
        if let sid = activeSessionId, memory.sessionId == sid {
            score += 2.5
        }
        if let mid = memory.moduleId, activeModuleIds.contains(mid) {
            score += 1.5
        }

        // Category boost
        if let preferred = config.preferredCategories,
           preferred.contains(memory.category) {
            score += 1.0
        }

        // Tag overlap boost
        if let preferred = config.preferredTags {
            let overlap = preferred.intersection(Set(memory.tags)).count
            score += Double(overlap) * 0.5
        }

        // Recency — decay over 30 days, floor at 0
        let daysSinceUpdate = now.timeIntervalSince(memory.updatedAt) / 86_400
        let recencyBoost = max(0.0, 1.0 - (daysSinceUpdate / 30.0))
        score += recencyBoost * 0.5

        // Last accessed recency
        if let lastAccessed = memory.lastAccessedAt {
            let daysSinceAccess = now.timeIntervalSince(lastAccessed) / 86_400
            let accessBoost = max(0.0, 1.0 - (daysSinceAccess / 14.0))
            score += accessBoost * 0.3
        }

        return score
    }
}
