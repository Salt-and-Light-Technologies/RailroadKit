import Foundation

/// The lifecycle status of a decision.
public enum DecisionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    /// Under consideration; not yet finalised.
    case proposed
    /// Accepted and in effect.
    case accepted
    /// Explicitly discarded.
    case rejected
    /// Replaced by a newer decision.
    case superseded
}
