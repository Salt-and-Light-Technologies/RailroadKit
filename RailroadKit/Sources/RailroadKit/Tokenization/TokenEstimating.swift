import Foundation

/// Provides approximate token counts for text strings.
///
/// A default implementation (SimpleTokenEstimator) is provided.
/// Applications that require provider-specific tokenization can inject
/// a custom conformer — for example, one backed by tiktoken via a
/// bridging layer — without changing any RailroadKit internals.
public protocol TokenEstimating: Sendable {
    func estimateTokens(for text: String) -> Int
}
