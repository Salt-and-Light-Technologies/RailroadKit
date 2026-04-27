import Testing
import Foundation
@testable import RailroadKit

@Suite("ImportExportService")
struct ImportExportServiceTests {

    func makeService() -> (ImportExportService, InMemoryMemoryStore, InMemoryDecisionStore, InMemorySessionStore) {
        let ms = InMemoryMemoryStore()
        let ds = InMemoryDecisionStore()
        let ss = InMemorySessionStore()
        let svc = ImportExportService(memoryStore: ms, decisionStore: ds, sessionStore: ss)
        return (svc, ms, ds, ss)
    }

    // MARK: - Round-trip

    @Test("export then import with overwrite restores all memories")
    func roundTripMemories() async throws {
        let (svc, ms, _, _) = makeService()

        let m1 = TestFixtures.approvedMemory(content: "Memory one")
        let m2 = TestFixtures.approvedMemory(content: "Memory two")
        try await ms.save(m1)
        try await ms.save(m2)

        let data = try await svc.exportAll()

        // Fresh stores
        let (svc2, ms2, _, _) = makeService()
        let _ = try await svc2.importData(data, mergePolicy: .overwriteExisting)

        let imported = try await ms2.list()
        #expect(imported.count == 2)
        let contents = Set(imported.map { $0.content })
        #expect(contents.contains("Memory one"))
        #expect(contents.contains("Memory two"))
    }

    @Test("decisions round-trip correctly")
    func roundTripDecisions() async throws {
        let (svc, _, ds, _) = makeService()
        let d = Decision(title: "Use MVVM", content: "We will use MVVM", scope: .project)
        try await ds.save(d)

        let data = try await svc.exportAll()

        let (svc2, _, ds2, _) = makeService()
        try await svc2.importData(data, mergePolicy: .overwriteExisting)
        let imported = try await ds2.list()
        #expect(imported.count == 1)
        #expect(imported.first?.title == "Use MVVM")
    }

    @Test("session round-trip preserves objective")
    func roundTripSessions() async throws {
        let (svc, _, _, ss) = makeService()
        let session = Session(title: "My session", objective: "Do the thing")
        try await ss.save(session)

        let data = try await svc.exportAll()

        let (svc2, _, _, ss2) = makeService()
        try await svc2.importData(data, mergePolicy: .overwriteExisting)
        let imported = try await ss2.list()
        #expect(imported.first?.objective == "Do the thing")
    }

    // MARK: - Merge Policies

    @Test("keepExisting does not overwrite existing memory")
    func keepExistingPolicy() async throws {
        let (svc, ms, _, _) = makeService()
        let original = TestFixtures.approvedMemory(content: "Original")
        try await ms.save(original)
        let data = try await svc.exportAll()

        // Modify store content, then import with keepExisting
        var updated = original
        updated.content = "Modified"
        try await ms.save(updated)

        try await svc.importData(data, mergePolicy: .keepExisting)
        let fetched = try await ms.fetch(id: original.id)
        #expect(fetched?.content == "Modified")  // keepExisting preserves the in-store version
    }

    @Test("overwriteExisting replaces existing memory")
    func overwriteExistingPolicy() async throws {
        let (svc, ms, _, _) = makeService()
        let original = TestFixtures.approvedMemory(content: "Original")
        try await ms.save(original)
        let data = try await svc.exportAll()  // export has "Original"

        // Change stored version after export
        var modified = original
        modified.content = "Modified after export"
        try await ms.save(modified)

        // Re-import the export (which has "Original") with overwrite
        try await svc.importData(data, mergePolicy: .overwriteExisting)
        let fetched = try await ms.fetch(id: original.id)
        #expect(fetched?.content == "Original")  // overwrite restores export value
    }

    @Test("skipDuplicates skips existing IDs")
    func skipDuplicatesPolicy() async throws {
        let (svc, ms, _, _) = makeService()
        let memory = TestFixtures.approvedMemory(content: "Existing")
        try await ms.save(memory)
        let data = try await svc.exportAll()

        let result = try await svc.importData(data, mergePolicy: .skipDuplicates)
        #expect(result.skippedMemoryIds.contains(memory.id))
        #expect(result.memoriesImported == 0)
    }

    @Test("createCopy imports with a new UUID")
    func createCopyPolicy() async throws {
        let (svc, ms, _, _) = makeService()
        let memory = TestFixtures.approvedMemory(content: "Will be copied")
        try await ms.save(memory)
        let data = try await svc.exportAll()

        let result = try await svc.importData(data, mergePolicy: .createCopy)
        #expect(result.copiedMemoryIds.count == 1)
        let newId = result.copiedMemoryIds.first!
        #expect(newId != memory.id)
        let copy = try await ms.fetch(id: newId)
        #expect(copy?.content == "Will be copied")
    }

    // MARK: - Project Export

    @Test("exportForProject only includes memories for that project")
    func exportForProject() async throws {
        let (svc, ms, _, _) = makeService()
        let pid = UUID()
        let inProject = TestFixtures.memory(content: "In project", projectId: pid)
        let outProject = TestFixtures.memory(content: "Out of project")
        try await ms.save(inProject)
        try await ms.save(outProject)

        let data = try await svc.exportForProject(projectId: pid)
        let export = try JSONDecoder.iso8601Decoder.decode(RailroadExport.self, from: data)
        #expect(export.memories.count == 1)
        #expect(export.memories.first?.projectId == pid)
    }

    // MARK: - Unsupported Format Version

    @Test("importing unsupported format version throws")
    func unsupportedFormatVersion() async throws {
        let badJSON = """
        {"exportFormatVersion":"9.9","exportedAt":"2025-01-01T00:00:00Z","memories":[],"decisions":[],"sessions":[]}
        """.data(using: .utf8)!
        let (svc, _, _, _) = makeService()
        await #expect(throws: ImportExportError.self) {
            try await svc.importData(badJSON, mergePolicy: .overwriteExisting)
        }
    }
}

// MARK: - Decoder Helper

private extension JSONDecoder {
    static var iso8601Decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
