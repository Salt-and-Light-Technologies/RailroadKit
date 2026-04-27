import Foundation
@testable import RailroadKit

/// Shared factory helpers for unit tests.
enum TestFixtures {

    static let projectId = UUID()
    static let sessionId = UUID()
    static let moduleId = UUID()
    static let workspaceId = UUID()

    static var userEnteredSource: MemorySource {
        MemorySource(sourceType: .userEntered, createdBy: "test")
    }

    static var llmSource: MemorySource {
        MemorySource(sourceType: .llmSuggested, confidence: 0.85, createdAt: Date())
    }

    static func memory(
        content: String = "Test memory",
        scope: MemoryScope = .project,
        category: MemoryCategory = .projectFact,
        status: MemoryStatus = .approved,
        importance: Double = 0.5,
        confidence: Double = 0.9,
        tags: [String] = [],
        projectId: UUID? = nil,
        sessionId: UUID? = nil,
        moduleId: UUID? = nil,
        source: MemorySource? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> Memory {
        Memory(
            content: content,
            scope: scope,
            category: category,
            status: status,
            importance: importance,
            confidence: confidence,
            tags: tags,
            projectId: projectId,
            moduleId: moduleId,
            sessionId: sessionId,
            source: source ?? userEnteredSource,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func suggestedMemory(content: String = "Suggested memory") -> Memory {
        memory(content: content, status: .suggested, source: llmSource)
    }

    static func approvedMemory(content: String = "Approved memory", importance: Double = 0.5) -> Memory {
        memory(content: content, status: .approved, importance: importance)
    }

    static func rejectedMemory(content: String = "Rejected memory") -> Memory {
        memory(content: content, status: .rejected)
    }

    static func archivedMemory(content: String = "Archived memory") -> Memory {
        var m = memory(content: content, status: .archived)
        m.archivedAt = Date()
        return m
    }

    static func staleMemory(content: String = "Stale memory") -> Memory {
        memory(content: content, status: .stale)
    }
}
