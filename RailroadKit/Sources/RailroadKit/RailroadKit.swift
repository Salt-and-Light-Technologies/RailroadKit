/// RailroadKit — Structured long-running memory, task/session state,
/// decisions, constraints, and memory pruning for Swift applications.
///
/// ## Quick Start
///
/// ```swift
/// import RailroadKit
///
/// // Create a service (all in-memory by default)
/// let railroad = RailroadService()
///
/// // Start a session
/// let session = try await railroad.sessions.createSession(
///     title: "Implement auth module",
///     objective: "Extract authentication into a standalone AuthService"
/// )
///
/// // Suggest a memory (e.g. from an LLM extraction)
/// let memory = try await railroad.memories.createSuggestedMemory(
///     content: "JWT tokens expire in 15 minutes; do not increase this.",
///     scope: .project,
///     category: .constraint,
///     projectId: myProject.id,
///     source: MemorySource(sourceType: .llmSuggested, createdBy: "claude-3-7-sonnet")
/// )
///
/// // User reviews and approves
/// try await railroad.memories.approveMemory(id: memory.id)
///
/// // Prune memories for a context pack
/// let result = try await railroad.prunedMemories(for: session)
/// print("Selected \(result.selected.count) memories (~\(result.estimatedTokenCount) tokens)")
/// ```
///
/// ## Module Structure
///
/// - **Models** (`Memory`, `Decision`, `Session`, `Workspace`, `ProjectReference`, `ModuleReference`)
/// - **Storage** (`MemoryStore`, `SessionStore`, `DecisionStore`, `WorkspaceStore`,
///   `ProjectReferenceStore`, `ModuleReferenceStore` + in-memory implementations)
/// - **Services** (`MemoryService`, `SessionService`, `DecisionService`,
///   `MemoryPruner`, `MemoryRelevanceScorer`, `ImportExportService`)
/// - **Tokenization** (`TokenEstimating`, `SimpleTokenEstimator`)
/// - **Facade** (`RailroadService`)
// This module re-exports nothing automatically.
// Each source file imports Foundation directly.
