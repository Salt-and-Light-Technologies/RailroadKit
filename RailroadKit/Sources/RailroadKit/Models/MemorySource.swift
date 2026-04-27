import Foundation

/// Provenance metadata attached to every memory.
///
/// Embedded by value so the source record travels with the memory
/// through serialization without a separate lookup.
public struct MemorySource: Codable, Hashable, Sendable {
    /// What kind of system produced this memory.
    public var sourceType: MemorySourceType
    /// An opaque identifier for the specific source artifact (e.g. a file path hash, message ID).
    public var sourceId: String?
    /// A human-readable file or document path associated with the source.
    public var sourcePath: String?
    /// A human-readable title for the source (e.g. document name, session title).
    public var sourceTitle: String?
    /// The identity that created this memory (e.g. "user", an agent name, model identifier).
    public var createdBy: String?
    /// Confidence in this memory's accuracy at the time it was created (0.0–1.0).
    public var confidence: Double?
    /// When this source record was produced.
    public var createdAt: Date

    public init(
        sourceType: MemorySourceType,
        sourceId: String? = nil,
        sourcePath: String? = nil,
        sourceTitle: String? = nil,
        createdBy: String? = nil,
        confidence: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.sourcePath = sourcePath
        self.sourceTitle = sourceTitle
        self.createdBy = createdBy
        self.confidence = confidence
        self.createdAt = createdAt
    }
}
