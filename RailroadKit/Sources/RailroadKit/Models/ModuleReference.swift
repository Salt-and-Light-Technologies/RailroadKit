import Foundation

/// A lightweight reference to a module within a project.
///
/// As with ProjectReference, RailroadKit does not parse module files.
/// This model provides stable module IDs for memory and session associations.
public struct ModuleReference: Codable, Hashable, Identifiable, Sendable {

    public let id: UUID
    public var name: String
    public var projectId: UUID
    /// The relative or absolute path to this module within the project.
    public var path: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        projectId: UUID,
        path: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.projectId = projectId
        self.path = path
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
