import Testing
import Foundation
@testable import RailroadKit

@Suite("MemoryPruner")
struct MemoryPrunerTests {

    let pruner = MemoryPruner()
    let now = Date()

    // MARK: - Status Exclusion

    @Test("suggested memories are excluded by default")
    func suggestedExcludedByDefault() {
        let memories = [TestFixtures.suggestedMemory()]
        let result = pruner.prune(candidates: memories, config: MemoryPruningConfig(), now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .statusSuggested)
    }

    @Test("suggested memories included when opted in")
    func suggestedIncludedWhenOptedIn() {
        let memories = [TestFixtures.suggestedMemory()]
        var config = MemoryPruningConfig()
        config.includeSuggestedMemories = true
        let result = pruner.prune(candidates: memories, config: config, now: now)
        #expect(result.selected.count == 1)
    }

    @Test("rejected memories are always excluded")
    func rejectedAlwaysExcluded() {
        let memories = [TestFixtures.rejectedMemory()]
        var config = MemoryPruningConfig()
        config.includeRejectedMemories = false
        let result = pruner.prune(candidates: memories, config: config, now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .statusRejected)
    }

    @Test("archived memories excluded by default")
    func archivedExcludedByDefault() {
        let memories = [TestFixtures.archivedMemory()]
        let result = pruner.prune(candidates: memories, config: MemoryPruningConfig(), now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .statusArchived)
    }

    @Test("stale memories excluded by default")
    func staleExcludedByDefault() {
        let memories = [TestFixtures.staleMemory()]
        let result = pruner.prune(candidates: memories, config: MemoryPruningConfig(), now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .statusStale)
    }

    @Test("approved memories are included by default")
    func approvedIncluded() {
        let memories = [TestFixtures.approvedMemory()]
        let result = pruner.prune(candidates: memories, config: MemoryPruningConfig(), now: now)
        #expect(result.selected.count == 1)
    }

    // MARK: - Importance Ranking

    @Test("high-importance memories outrank low-importance memories")
    func importanceRanking() {
        let low = TestFixtures.approvedMemory(content: "Low", importance: 0.1)
        let high = TestFixtures.approvedMemory(content: "High", importance: 0.9)
        let result = pruner.prune(candidates: [low, high], config: MemoryPruningConfig(), now: now)
        #expect(result.selected.first?.content == "High")
    }

    // MARK: - Project Relevance

    @Test("project-specific memories outrank unrelated-project memories")
    func projectRelevanceRanking() {
        let myProject = UUID()
        let otherProject = UUID()
        let relevant = TestFixtures.memory(content: "Relevant", projectId: myProject)
        let irrelevant = TestFixtures.memory(content: "Irrelevant", projectId: otherProject)
        let result = pruner.prune(
            candidates: [irrelevant, relevant],
            config: MemoryPruningConfig(),
            now: now,
            activeProjectId: myProject
        )
        #expect(result.selected.first?.content == "Relevant")
    }

    // MARK: - Session Memories

    @Test("session memories are included for the active session")
    func sessionMemoriesIncluded() {
        let sid = UUID()
        let sessionMemory = TestFixtures.memory(content: "Session", scope: .session, sessionId: sid)
        let result = pruner.prune(
            candidates: [sessionMemory],
            config: MemoryPruningConfig(),
            now: now,
            activeSessionId: sid
        )
        #expect(result.selected.count == 1)
    }

    // MARK: - Count Budget

    @Test("maxMemoryCount is respected")
    func maxMemoryCount() {
        let memories = (0..<10).map { i in
            TestFixtures.approvedMemory(content: "Memory \(i)")
        }
        var config = MemoryPruningConfig()
        config.maxMemoryCount = 3
        let result = pruner.prune(candidates: memories, config: config, now: now)
        #expect(result.selected.count == 3)
        #expect(result.excluded.filter { $0.reason == .countBudgetExceeded }.count == 7)
    }

    // MARK: - Token Budget

    @Test("token budget trimming works approximately")
    func tokenBudgetTrimming() {
        // Each memory has ~40 chars of content → ~10 tokens each
        let memories = (0..<10).map { i in
            TestFixtures.approvedMemory(content: "This is memory number \(i) with some text.")
        }
        var config = MemoryPruningConfig()
        config.maxMemoryCount = 100
        config.maxEstimatedTokens = 25  // allows ~2-3 memories
        let result = pruner.prune(candidates: memories, config: config, now: now)
        #expect(result.selected.count < memories.count)
        #expect(result.estimatedTokenCount <= 25)
    }

    // MARK: - Confidence

    @Test("memories below minimumConfidence are excluded")
    func minimumConfidence() {
        let lowConf = TestFixtures.memory(content: "Low confidence", confidence: 0.3)
        var config = MemoryPruningConfig()
        config.minimumConfidence = 0.5
        let result = pruner.prune(candidates: [lowConf], config: config, now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .belowMinimumConfidence)
    }

    // MARK: - Expiry

    @Test("expired memories are excluded")
    func expiredMemoriesExcluded() {
        var expired = TestFixtures.approvedMemory(content: "Expired")
        expired.expiresAt = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let result = pruner.prune(candidates: [expired], config: MemoryPruningConfig(), now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .expired)
    }

    // MARK: - Scope Gate

    @Test("global memories excluded when includeGlobalMemories is false")
    func globalScopeGate() {
        let globalMemory = TestFixtures.memory(content: "Global", scope: .global)
        var config = MemoryPruningConfig()
        config.includeGlobalMemories = false
        let result = pruner.prune(candidates: [globalMemory], config: config, now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .scopeExcluded)
    }

    // MARK: - Required Tags

    @Test("memories missing required tags are excluded")
    func requiredTagsFilter() {
        let noTags = TestFixtures.approvedMemory(content: "No tags")
        var config = MemoryPruningConfig()
        config.requiredTags = ["swift"]
        let result = pruner.prune(candidates: [noTags], config: config, now: now)
        #expect(result.selected.isEmpty)
        #expect(result.excluded.first?.reason == .requiredTagsMissing)
    }
}
