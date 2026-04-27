import Foundation

/// The lifecycle status of a memory.
///
/// Only `.approved` memories are eligible for normal context generation.
/// Callers must explicitly opt in to retrieve memories in other states.
public enum MemoryStatus: String, Codable, CaseIterable, Hashable, Sendable {
    /// Created but not yet reviewed by the user.
    case suggested
    /// Reviewed and accepted; eligible for context generation.
    case approved
    /// Reviewed and explicitly discarded.
    case rejected
    /// Moved to cold storage; excluded from normal retrieval.
    case archived
    /// Previously approved but now believed to be outdated.
    case stale
}
