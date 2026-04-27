import Foundation

/// Classifies the nature of a memory's content.
///
/// Constraints are modelled as a category here rather than a separate
/// type, which lets the unified approval, pruning, and retrieval
/// pipeline handle them without duplication.
public enum MemoryCategory: String, Codable, CaseIterable, Hashable, Sendable {
    /// A personal or developer workflow preference.
    case userPreference
    /// A factual statement about a project (e.g. "this project uses Vapor").
    case projectFact
    /// An architectural fact (e.g. "we use MVVM throughout").
    case architectureFact
    /// A naming, formatting, or coding convention.
    case convention
    /// A hard rule that must be respected (e.g. "do not alter the public API").
    case constraint
    /// A deliberate choice that was made (prefer Decision for first-class tracking).
    case decision
    /// A known pitfall, footgun, or non-obvious behaviour.
    case gotcha
    /// Ephemeral task state (e.g. "currently working on the login screen").
    case taskState
    /// A warning about a fragile area or risk.
    case warning
    /// A general note that doesn't fit another category.
    case note
    /// An open question that has not yet been answered.
    case unresolvedQuestion
}
