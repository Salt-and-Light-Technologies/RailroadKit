import Foundation

/// Identifies where a memory originated.
public enum MemorySourceType: String, Codable, CaseIterable, Hashable, Sendable {
    /// Typed in directly by the developer.
    case userEntered
    /// Suggested by an LLM response.
    case llmSuggested
    /// Loaded from an external file or system.
    case imported
    /// Derived from a ROSETTA.md document (populated by RosettaKit).
    case rosettaDocument
    /// Derived from a .rosetta/modules/*.md file (populated by RosettaKit).
    case rosettaModule
    /// Extracted from a generated context pack.
    case contextPack
    /// Created programmatically by the application.
    case appGenerated
    /// Provenance is unknown.
    case unknown
}
