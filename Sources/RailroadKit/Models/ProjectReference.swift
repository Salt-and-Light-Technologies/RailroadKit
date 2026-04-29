import Foundation

/// A lightweight reference to a project tracked by RailroadKit.
///
/// RailroadKit does not scan or parse project files — that is RosettaKit's
/// responsibility. This model exists so memories and sessions can be
/// associated with a stable project ID.
public struct ProjectReference: Codable, Hashable, Identifiable, Sendable {

    public let id: UUID
    public var name: String
    /// The absolute path to the project root on the local filesystem.
    public var rootPath: String?
    public var workspaceId: UUID?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        rootPath: String? = nil,
        workspaceId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.workspaceId = workspaceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
