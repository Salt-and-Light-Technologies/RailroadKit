import Testing
import Foundation
@testable import RailroadKit

@Suite("MemoryRelevanceScorer")
struct MemoryRelevanceScorerTests {

    let scorer = MemoryRelevanceScorer()
    let now = Date()

    // MARK: - Basic Scoring

    @Test("returns empty array for empty input")
    func emptyInput() {
        let result = scorer.score(memories: [], query: RelevanceQuery(), now: now)
        #expect(result.isEmpty)
    }

    @Test("suggested memories excluded by default")
    func suggestedExcluded() {
        let suggested = TestFixtures.suggestedMemory()
        let result = scorer.score(memories: [suggested], query: RelevanceQuery(), now: now)
        #expect(result.isEmpty)
    }

    // MARK: - Keyword Scoring

    @Test("keyword match boosts score")
    func keywordMatchBoostsScore() {
        let match = TestFixtures.approvedMemory(content: "Swift uses automatic reference counting")
        let noMatch = TestFixtures.approvedMemory(content: "Python uses garbage collection")
        let query = RelevanceQuery(keywords: ["swift", "arc"])
        let result = scorer.score(memories: [noMatch, match], query: query, now: now)
        #expect(result.first?.memory.content.contains("Swift") == true)
    }

    @Test("score reasons include keyword_content_overlap")
    func keywordReasonsPresent() {
        let memory = TestFixtures.approvedMemory(content: "MVVM architecture is required")
        let query = RelevanceQuery(keywords: ["mvvm"])
        let result = scorer.score(memories: [memory], query: query, now: now)
        let hasKwReason = result.first?.reasons.contains { $0.label.contains("keyword_content") } ?? false
        #expect(hasKwReason)
    }

    // MARK: - Project / Session / Module Match

    @Test("exact project match boosts score above non-matching memories")
    func projectMatchBoosted() {
        let pid = UUID()
        let projectMemory = TestFixtures.memory(content: "Project specific", projectId: pid)
        let globalMemory = TestFixtures.memory(content: "Unrelated", scope: .global, importance: 0.4)
        let query = RelevanceQuery(projectId: pid)
        let result = scorer.score(memories: [globalMemory, projectMemory], query: query, now: now)
        #expect(result.first?.memory.content == "Project specific")
    }

    @Test("session match produces session_match reason")
    func sessionMatchReasonPresent() {
        let sid = UUID()
        let mem = TestFixtures.memory(content: "In session", scope: .session, sessionId: sid)
        let query = RelevanceQuery(sessionId: sid)
        let result = scorer.score(memories: [mem], query: query, now: now)
        let hasSessionReason = result.first?.reasons.contains { $0.label == "session_match" } ?? false
        #expect(hasSessionReason)
    }

    // MARK: - Tag Scoring

    @Test("tag overlap boosts score")
    func tagOverlapBoosted() {
        let taggedMemory = TestFixtures.memory(content: "Tagged memory", tags: ["auth", "security"])
        let untagged = TestFixtures.memory(content: "Untagged memory")
        let query = RelevanceQuery(tags: ["auth"])
        let result = scorer.score(memories: [untagged, taggedMemory], query: query, now: now)
        #expect(result.first?.memory.content == "Tagged memory")
    }

    // MARK: - Importance

    @Test("higher importance produces higher total score")
    func importanceInfluencesScore() {
        let low = TestFixtures.approvedMemory(content: "Low imp", importance: 0.1)
        let high = TestFixtures.approvedMemory(content: "High imp", importance: 0.9)
        let result = scorer.score(memories: [low, high], query: RelevanceQuery(), now: now)
        #expect(result.first?.memory.content == "High imp")
    }

    // MARK: - includeNonApproved

    @Test("includeNonApproved includes suggested memories")
    func includeNonApproved() {
        let suggested = TestFixtures.suggestedMemory()
        let result = scorer.score(memories: [suggested], query: RelevanceQuery(), now: now, includeNonApproved: true)
        #expect(result.count == 1)
    }
}
