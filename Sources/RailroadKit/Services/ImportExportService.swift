import Foundation

// MARK: - Export Envelope

/// A versioned, self-contained snapshot of RailroadKit data for
/// portability, debugging, and backup.
public struct RailroadExport: Codable, Sendable {
    public let exportFormatVersion: String
    public let exportedAt: Date
    public let memories: [Memory]
    public let decisions: [Decision]
    public let sessions: [Session]

    public init(
        exportFormatVersion: String = "1.0",
        exportedAt: Date = Date(),
        memories: [Memory],
        decisions: [Decision],
        sessions: [Session]
    ) {
        self.exportFormatVersion = exportFormatVersion
        self.exportedAt = exportedAt
        self.memories = memories
        self.decisions = decisions
        self.sessions = sessions
    }
}

// MARK: - Merge Policy

/// Controls how imported records are reconciled with existing records
/// that share the same ID.
public enum MergePolicy: Sendable {
    /// Keep the existing record; discard the incoming one.
    case keepExisting
    /// Replace the existing record with the incoming one.
    case overwriteExisting
    /// Import the record under a new UUID, preserving both.
    case createCopy
    /// Silently skip any record whose ID already exists.
    case skipDuplicates
}

// MARK: - Import Result

/// Summary of an import operation.
public struct ImportResult: Sendable {
    public let memoriesImported: Int
    public let decisionsImported: Int
    public let sessionsImported: Int
    public let skippedMemoryIds: [UUID]
    public let skippedDecisionIds: [UUID]
    public let skippedSessionIds: [UUID]
    public let copiedMemoryIds: [UUID]       // new IDs created when policy == .createCopy
    public let copiedDecisionIds: [UUID]
    public let copiedSessionIds: [UUID]
    public let warnings: [String]

    public init(
        memoriesImported: Int = 0,
        decisionsImported: Int = 0,
        sessionsImported: Int = 0,
        skippedMemoryIds: [UUID] = [],
        skippedDecisionIds: [UUID] = [],
        skippedSessionIds: [UUID] = [],
        copiedMemoryIds: [UUID] = [],
        copiedDecisionIds: [UUID] = [],
        copiedSessionIds: [UUID] = [],
        warnings: [String] = []
    ) {
        self.memoriesImported = memoriesImported
        self.decisionsImported = decisionsImported
        self.sessionsImported = sessionsImported
        self.skippedMemoryIds = skippedMemoryIds
        self.skippedDecisionIds = skippedDecisionIds
        self.skippedSessionIds = skippedSessionIds
        self.copiedMemoryIds = copiedMemoryIds
        self.copiedDecisionIds = copiedDecisionIds
        self.copiedSessionIds = copiedSessionIds
        self.warnings = warnings
    }
}

// MARK: - Errors

public enum ImportExportError: Error, Sendable {
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case unsupportedFormatVersion(String)
}

// MARK: - Service

/// Provides JSON-based import and export for all RailroadKit records.
public final class ImportExportService: Sendable {

    private let memoryStore: any MemoryStore
    private let decisionStore: any DecisionStore
    private let sessionStore: any SessionStore

    public init(
        memoryStore: any MemoryStore,
        decisionStore: any DecisionStore,
        sessionStore: any SessionStore
    ) {
        self.memoryStore = memoryStore
        self.decisionStore = decisionStore
        self.sessionStore = sessionStore
    }

    // Encoder and decoder are created per-call to avoid storing reference
    // types that would require @unchecked Sendable under Swift 6.
    private func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    // MARK: - Export

    /// Exports all memories, decisions, and sessions to JSON data.
    public func exportAll() async throws -> Data {
        let memories = try await memoryStore.list()
        let decisions = try await decisionStore.list()
        let sessions = try await sessionStore.list()
        return try encode(RailroadExport(memories: memories, decisions: decisions, sessions: sessions))
    }

    /// Exports memories (and their associated decisions/sessions) for a specific project.
    public func exportForProject(projectId: UUID) async throws -> Data {
        let memFilter = MemoryFilter(projectId: projectId)
        let memories = try await memoryStore.query(memFilter)
        let decisions = try await decisionStore.query(DecisionFilter(projectId: projectId))
        let sessions = try await sessionStore.query(SessionFilter(projectId: projectId))
        return try encode(RailroadExport(memories: memories, decisions: decisions, sessions: sessions))
    }

    /// Exports a single session with its associated memories and decisions.
    public func exportSession(id: UUID) async throws -> Data {
        guard let session = try await sessionStore.fetch(id: id) else {
            return try encode(RailroadExport(memories: [], decisions: [], sessions: []))
        }
        let memories = try await withThrowingTaskGroup(of: Memory?.self) { group in
            for mid in session.memoryIds {
                group.addTask { try await self.memoryStore.fetch(id: mid) }
            }
            var result: [Memory] = []
            for try await memory in group {
                if let m = memory { result.append(m) }
            }
            return result
        }
        let decisions = try await withThrowingTaskGroup(of: Decision?.self) { group in
            for did in session.decisionIds {
                group.addTask { try await self.decisionStore.fetch(id: did) }
            }
            var result: [Decision] = []
            for try await decision in group {
                if let d = decision { result.append(d) }
            }
            return result
        }
        return try encode(RailroadExport(memories: memories, decisions: decisions, sessions: [session]))
    }

    // MARK: - Import

    /// Imports records from JSON data using the specified merge policy.
    @discardableResult
    public func importData(_ data: Data, mergePolicy: MergePolicy) async throws -> ImportResult {
        let export: RailroadExport
        do {
            export = try makeDecoder().decode(RailroadExport.self, from: data)
        } catch {
            throw ImportExportError.decodingFailed(underlying: error)
        }

        guard export.exportFormatVersion == "1.0" else {
            throw ImportExportError.unsupportedFormatVersion(export.exportFormatVersion)
        }

        var memoriesImported = 0
        var decisionsImported = 0
        var sessionsImported = 0
        var skippedMemoryIds: [UUID] = []
        var skippedDecisionIds: [UUID] = []
        var skippedSessionIds: [UUID] = []
        var copiedMemoryIds: [UUID] = []
        var copiedDecisionIds: [UUID] = []
        var copiedSessionIds: [UUID] = []

        // Memories
        for memory in export.memories {
            let existing = try await memoryStore.fetch(id: memory.id)
            switch mergePolicy {
            case .keepExisting:
                if existing != nil { skippedMemoryIds.append(memory.id); continue }
                try await memoryStore.save(memory); memoriesImported += 1
            case .overwriteExisting:
                try await memoryStore.save(memory); memoriesImported += 1
            case .skipDuplicates:
                if existing != nil { skippedMemoryIds.append(memory.id); continue }
                try await memoryStore.save(memory); memoriesImported += 1
            case .createCopy:
                if existing != nil {
                    var copy = memory
                    let newId = UUID()
                    copy = Memory(
                        id: newId, content: copy.content, scope: copy.scope,
                        category: copy.category, status: copy.status,
                        importance: copy.importance, confidence: copy.confidence,
                        tags: copy.tags, workspaceId: copy.workspaceId,
                        projectId: copy.projectId, moduleId: copy.moduleId,
                        sessionId: copy.sessionId, source: copy.source,
                        createdAt: copy.createdAt, updatedAt: copy.updatedAt,
                        lastAccessedAt: copy.lastAccessedAt, expiresAt: copy.expiresAt,
                        archivedAt: copy.archivedAt
                    )
                    try await memoryStore.save(copy)
                    copiedMemoryIds.append(newId)
                    memoriesImported += 1
                } else {
                    try await memoryStore.save(memory); memoriesImported += 1
                }
            }
        }

        // Decisions
        for decision in export.decisions {
            let existing = try await decisionStore.fetch(id: decision.id)
            switch mergePolicy {
            case .keepExisting, .skipDuplicates:
                if existing != nil { skippedDecisionIds.append(decision.id); continue }
                try await decisionStore.save(decision); decisionsImported += 1
            case .overwriteExisting:
                try await decisionStore.save(decision); decisionsImported += 1
            case .createCopy:
                if existing != nil {
                    let newId = UUID()
                    let copy = Decision(
                        id: newId, title: decision.title, content: decision.content,
                        rationale: decision.rationale, scope: decision.scope,
                        status: decision.status, workspaceId: decision.workspaceId,
                        projectId: decision.projectId, moduleId: decision.moduleId,
                        sessionId: decision.sessionId,
                        relatedMemoryIds: decision.relatedMemoryIds,
                        createdAt: decision.createdAt, updatedAt: decision.updatedAt
                    )
                    try await decisionStore.save(copy)
                    copiedDecisionIds.append(newId)
                    decisionsImported += 1
                } else {
                    try await decisionStore.save(decision); decisionsImported += 1
                }
            }
        }

        // Sessions
        for session in export.sessions {
            let existing = try await sessionStore.fetch(id: session.id)
            switch mergePolicy {
            case .keepExisting, .skipDuplicates:
                if existing != nil { skippedSessionIds.append(session.id); continue }
                try await sessionStore.save(session); sessionsImported += 1
            case .overwriteExisting:
                try await sessionStore.save(session); sessionsImported += 1
            case .createCopy:
                if existing != nil {
                    let newId = UUID()
                    let copy = Session(
                        id: newId, title: session.title, objective: session.objective,
                        workspaceId: session.workspaceId, projectId: session.projectId,
                        activeModuleIds: session.activeModuleIds, status: session.status,
                        memoryIds: session.memoryIds, decisionIds: session.decisionIds,
                        notes: session.notes,
                        lastGeneratedContextPackId: session.lastGeneratedContextPackId,
                        createdAt: session.createdAt, updatedAt: session.updatedAt
                    )
                    try await sessionStore.save(copy)
                    copiedSessionIds.append(newId)
                    sessionsImported += 1
                } else {
                    try await sessionStore.save(session); sessionsImported += 1
                }
            }
        }

        return ImportResult(
            memoriesImported: memoriesImported,
            decisionsImported: decisionsImported,
            sessionsImported: sessionsImported,
            skippedMemoryIds: skippedMemoryIds,
            skippedDecisionIds: skippedDecisionIds,
            skippedSessionIds: skippedSessionIds,
            copiedMemoryIds: copiedMemoryIds,
            copiedDecisionIds: copiedDecisionIds,
            copiedSessionIds: copiedSessionIds
        )
    }

    // MARK: - Helpers

    private func encode(_ export: RailroadExport) throws -> Data {
        do {
            return try makeEncoder().encode(export)
        } catch {
            throw ImportExportError.encodingFailed(underlying: error)
        }
    }
}
