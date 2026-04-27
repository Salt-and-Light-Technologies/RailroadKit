import Foundation

// MARK: - Query

/// The context used to score memory relevance.
public struct RelevanceQuery: Sendable {
    /// Keywords to match against memory content and tags.
    public var keywords: [String]
    public var projectId: UUID?
    public var sessionId: UUID?
    public var moduleIds: Set<UUID>
    public var tags: Set<String>
    /// Categories to prioritise (soft boost, not a hard filter).
    public var preferredCategories: Set<MemoryCategory>

    public init(
        keywords: [String] = [],
        projectId: UUID? = nil,
        sessionId: UUID? = nil,
        moduleIds: Set<UUID> = [],
        tags: Set<String> = [],
        preferredCategories: Set<MemoryCategory> = []
    ) {
        self.keywords = keywords
        self.projectId = projectId
        self.sessionId = sessionId
        self.moduleIds = moduleIds
        self.tags = tags
        self.preferredCategories = preferredCategories
    }
}

// MARK: - Score Reason

/// A single contribution to a memory's total relevance score.
public struct ScoreReason: Sendable, CustomStringConvertible {
    public let label: String
    public let weight: Double

    public init(label: String, weight: Double) {
        self.label = label
        self.weight = weight
    }

    public var description: String { "\(label): +\(String(format: "%.2f", weight))" }
}

// MARK: - Scored Memory

/// A memory together with its total relevance score and breakdown.
public struct ScoredMemory: Sendable {
    public let memory: Memory
    public let totalScore: Double
    public let reasons: [ScoreReason]

    public init(memory: Memory, totalScore: Double, reasons: [ScoreReason]) {
        self.memory = memory
        self.totalScore = totalScore
        self.reasons = reasons
    }
}

// MARK: - Scorer

/// Scores a pool of memories against a RelevanceQuery using deterministic,
/// explainable signals. No embeddings are used in v1.
///
/// Scoring factors:
/// - Keyword overlap with content and tags
/// - Tag overlap with query tags
/// - Exact project / session / module match
/// - Category preference
/// - Importance and confidence
/// - Recency (updatedAt and lastAccessedAt)
public struct MemoryRelevanceScorer: Sendable {

    public init() {}

    /// Returns memories sorted by relevance score, highest first.
    ///
    /// Only approved memories are considered by default. Pass
    /// `includeNonApproved: true` to score all memories provided.
    public func score(
        memories: [Memory],
        query: RelevanceQuery,
        now: Date = Date(),
        includeNonApproved: Bool = false
    ) -> [ScoredMemory] {

        let candidates = includeNonApproved
            ? memories
            : memories.filter { $0.status == .approved }

        let lowercasedKeywords = query.keywords.map { $0.lowercased() }

        return candidates
            .map { memory in
                let (score, reasons) = computeScore(
                    memory: memory,
                    query: query,
                    lowercasedKeywords: lowercasedKeywords,
                    now: now
                )
                return ScoredMemory(memory: memory, totalScore: score, reasons: reasons)
            }
            .sorted { $0.totalScore > $1.totalScore }
    }

    // MARK: - Private

    private func computeScore(
        memory: Memory,
        query: RelevanceQuery,
        lowercasedKeywords: [String],
        now: Date
    ) -> (Double, [ScoreReason]) {

        var reasons: [ScoreReason] = []
        var total = 0.0

        // --- Importance (base signal, always present) ---
        let importanceWeight = memory.importance * 2.0
        reasons.append(ScoreReason(label: "importance", weight: importanceWeight))
        total += importanceWeight

        // --- Confidence ---
        let confidenceWeight = memory.confidence * 0.5
        reasons.append(ScoreReason(label: "confidence", weight: confidenceWeight))
        total += confidenceWeight

        // --- Keyword overlap (content) ---
        if !lowercasedKeywords.isEmpty {
            let contentLower = memory.content.lowercased()
            let matchCount = lowercasedKeywords.filter { contentLower.contains($0) }.count
            if matchCount > 0 {
                let kwWeight = Double(matchCount) / Double(lowercasedKeywords.count) * 3.0
                reasons.append(ScoreReason(label: "keyword_content_overlap(\(matchCount))", weight: kwWeight))
                total += kwWeight
            }
        }

        // --- Keyword overlap (tags) ---
        if !lowercasedKeywords.isEmpty {
            let tagSet = Set(memory.tags.map { $0.lowercased() })
            let matchCount = lowercasedKeywords.filter { tagSet.contains($0) }.count
            if matchCount > 0 {
                let tagKwWeight = Double(matchCount) * 0.5
                reasons.append(ScoreReason(label: "keyword_tag_overlap(\(matchCount))", weight: tagKwWeight))
                total += tagKwWeight
            }
        }

        // --- Tag overlap with query tags ---
        if !query.tags.isEmpty {
            let memoryTags = Set(memory.tags)
            let overlap = query.tags.intersection(memoryTags).count
            if overlap > 0 {
                let tagWeight = Double(overlap) * 1.0
                reasons.append(ScoreReason(label: "tag_overlap(\(overlap))", weight: tagWeight))
                total += tagWeight
            }
        }

        // --- Exact project match ---
        if let qp = query.projectId, memory.projectId == qp {
            reasons.append(ScoreReason(label: "project_match", weight: 2.0))
            total += 2.0
        }

        // --- Exact session match ---
        if let qs = query.sessionId, memory.sessionId == qs {
            reasons.append(ScoreReason(label: "session_match", weight: 2.5))
            total += 2.5
        }

        // --- Module match ---
        if let mid = memory.moduleId, query.moduleIds.contains(mid) {
            reasons.append(ScoreReason(label: "module_match", weight: 1.5))
            total += 1.5
        }

        // --- Category preference ---
        if query.preferredCategories.contains(memory.category) {
            reasons.append(ScoreReason(label: "preferred_category", weight: 1.0))
            total += 1.0
        }

        // --- Recency (updatedAt, 30-day decay) ---
        let daysSinceUpdate = now.timeIntervalSince(memory.updatedAt) / 86_400
        let recency = max(0.0, 1.0 - (daysSinceUpdate / 30.0)) * 0.8
        if recency > 0 {
            reasons.append(ScoreReason(label: "recency", weight: recency))
            total += recency
        }

        // --- Last-accessed recency (14-day decay) ---
        if let lastAccessed = memory.lastAccessedAt {
            let daysSinceAccess = now.timeIntervalSince(lastAccessed) / 86_400
            let accessRecency = max(0.0, 1.0 - (daysSinceAccess / 14.0)) * 0.5
            if accessRecency > 0 {
                reasons.append(ScoreReason(label: "access_recency", weight: accessRecency))
                total += accessRecency
            }
        }

        return (total, reasons)
    }
}
