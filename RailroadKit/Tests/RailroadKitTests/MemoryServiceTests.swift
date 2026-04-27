import Testing
import Foundation
@testable import RailroadKit

@Suite("MemoryService")
struct MemoryServiceTests {

    // MARK: - Helpers

    func makeService() -> MemoryService {
        MemoryService(store: InMemoryMemoryStore())
    }

    // MARK: - Suggested Memory Creation

    @Test("createSuggestedMemory sets status to .suggested")
    func createSuggestedMemory_setsStatusSuggested() async throws {
        let svc = makeService()
        let memory = try await svc.createSuggestedMemory(
            content: "Swift uses ARC",
            scope: .project,
            category: .projectFact,
            source: TestFixtures.llmSource
        )
        #expect(memory.status == .suggested)
    }

    @Test("createSuggestedMemory does not appear in approvedMemories")
    func suggestedMemory_notInApproved() async throws {
        let svc = makeService()
        try await svc.createSuggestedMemory(
            content: "Suggested",
            scope: .project,
            category: .note,
            source: TestFixtures.llmSource
        )
        let approved = try await svc.approvedMemories()
        #expect(approved.isEmpty)
    }

    // MARK: - Approval Workflow

    @Test("approveMemory transitions suggested → approved")
    func approveMemory_transitionsSuggestedToApproved() async throws {
        let svc = makeService()
        let memory = try await svc.createSuggestedMemory(
            content: "Use MVVM",
            scope: .project,
            category: .architectureFact,
            source: TestFixtures.llmSource
        )
        let approved = try await svc.approveMemory(id: memory.id)
        #expect(approved.status == .approved)
    }

    @Test("approveMemory updates updatedAt")
    func approveMemory_updatesTimestamp() async throws {
        let svc = makeService()
        let before = Date()
        let memory = try await svc.createSuggestedMemory(
            content: "Test",
            scope: .global,
            category: .note,
            source: TestFixtures.llmSource
        )
        let approved = try await svc.approveMemory(id: memory.id)
        #expect(approved.updatedAt >= before)
    }

    @Test("approving an already-approved memory throws")
    func approvingApprovedMemory_throws() async throws {
        let svc = makeService()
        let memory = try await svc.createApprovedMemory(
            content: "Already approved",
            scope: .global,
            category: .note,
            source: TestFixtures.userEnteredSource
        )
        await #expect(throws: MemoryServiceError.self) {
            try await svc.approveMemory(id: memory.id)
        }
    }

    // MARK: - Rejection

    @Test("rejectMemory transitions suggested → rejected")
    func rejectMemory_transitionsSuggestedToRejected() async throws {
        let svc = makeService()
        let memory = try await svc.createSuggestedMemory(
            content: "Bad memory",
            scope: .session,
            category: .note,
            source: TestFixtures.llmSource
        )
        let rejected = try await svc.rejectMemory(id: memory.id)
        #expect(rejected.status == .rejected)
    }

    @Test("rejected memory is excluded from approvedMemories")
    func rejectedMemory_excludedFromApproved() async throws {
        let svc = makeService()
        let memory = try await svc.createSuggestedMemory(
            content: "Will be rejected",
            scope: .project,
            category: .note,
            source: TestFixtures.llmSource
        )
        try await svc.rejectMemory(id: memory.id)
        let approved = try await svc.approvedMemories()
        #expect(approved.isEmpty)
    }

    // MARK: - Archive

    @Test("archiveMemory stamps archivedAt")
    func archiveMemory_stampsArchivedAt() async throws {
        let svc = makeService()
        let before = Date()
        let memory = try await svc.createApprovedMemory(
            content: "Old fact",
            scope: .project,
            category: .projectFact,
            source: TestFixtures.userEnteredSource
        )
        let archived = try await svc.archiveMemory(id: memory.id)
        #expect(archived.status == .archived)
        #expect((archived.archivedAt ?? Date.distantPast) >= before)
    }

    // MARK: - Stale

    @Test("markMemoryStale transitions approved → stale")
    func markMemoryStale_transitionsApprovedToStale() async throws {
        let svc = makeService()
        let memory = try await svc.createApprovedMemory(
            content: "May be outdated",
            scope: .project,
            category: .architectureFact,
            source: TestFixtures.userEnteredSource
        )
        let stale = try await svc.markMemoryStale(id: memory.id)
        #expect(stale.status == .stale)
    }

    // MARK: - Update

    @Test("updateMemory changes content")
    func updateMemory_changesContent() async throws {
        let svc = makeService()
        let memory = try await svc.createApprovedMemory(
            content: "Original",
            scope: .global,
            category: .userPreference,
            source: TestFixtures.userEnteredSource
        )
        let updated = try await svc.updateMemory(id: memory.id, content: "Updated")
        #expect(updated.content == "Updated")
    }

    @Test("promoteMemoryToScope changes scope")
    func promoteMemoryToScope_changesScope() async throws {
        let svc = makeService()
        let memory = try await svc.createApprovedMemory(
            content: "Session note",
            scope: .session,
            category: .taskState,
            sessionId: TestFixtures.sessionId,
            source: TestFixtures.userEnteredSource
        )
        let promoted = try await svc.promoteMemoryToScope(id: memory.id, scope: .project)
        #expect(promoted.scope == .project)
    }

    // MARK: - Touch

    @Test("touchMemory updates lastAccessedAt")
    func touchMemory_updatesLastAccessedAt() async throws {
        let svc = makeService()
        let before = Date()
        let memory = try await svc.createApprovedMemory(
            content: "Touch test",
            scope: .project,
            category: .note,
            source: TestFixtures.userEnteredSource
        )
        let touched = try await svc.touchMemory(id: memory.id)
        #expect((touched.lastAccessedAt ?? Date.distantPast) >= before)
    }

    // MARK: - Not Found

    @Test("operations on unknown ID throw memoryNotFound")
    func unknownId_throwsNotFound() async throws {
        let svc = makeService()
        let fakeId = UUID()
        await #expect(throws: MemoryServiceError.self) {
            try await svc.approveMemory(id: fakeId)
        }
    }
}
