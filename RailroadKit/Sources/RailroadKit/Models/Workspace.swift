import Foundation

/// A top-level organisational container for projects.
///
/// In v1 there is typically a single local workspace, but the model
/// is designed to support multiple workspaces and future team/cloud sync.
public struct Workspace: Codable, Hashable, Identifiable, Sendable {

    public let id: UUID
    public var name: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
