import Foundation

/// The scope at which a memory applies.
///
/// String raw values provide stable JSON serialization that is
/// resilient to case reordering. CaseIterable allows pruning logic
/// to iterate scopes in priority order.
public enum MemoryScope: String, Codable, CaseIterable, Hashable, Sendable {
    case global
    case workspace
    case project
    case module
    case session
}
