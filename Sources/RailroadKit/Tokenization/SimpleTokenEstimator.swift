import Foundation

/// A lightweight token estimator using the ~4 characters-per-token heuristic.
///
/// This approximation is accurate to within roughly 10–15% for English prose
/// and code. It is intentionally simple — RailroadKit does not attempt to
/// replicate provider-specific tokenization algorithms.
///
/// For budget decisions, callers should treat these estimates as lower bounds
/// and apply a safety margin (e.g. multiply by 1.1) when needed.
public struct SimpleTokenEstimator: TokenEstimating {

    /// Characters per token. Adjust if your corpus skews heavily toward
    /// non-ASCII content (code-heavy contexts often run closer to 3).
    public let charactersPerToken: Double

    public init(charactersPerToken: Double = 4.0) {
        self.charactersPerToken = charactersPerToken
    }

    public func estimateTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, Int((Double(text.count) / charactersPerToken).rounded(.up)))
    }
}
