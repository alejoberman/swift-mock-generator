import Foundation

/// Selects only protocols whose generated mock type is referenced by test sources.
public struct UsedProtocolFilter {
    public init() {}

    public func filter(_ protocols: [ProtocolDescriptor],
                       referencedMockTypeNames: Set<String>) -> [ProtocolDescriptor] {
        protocols.filter { referencedMockTypeNames.contains("Mock\($0.name)") }
    }
}
