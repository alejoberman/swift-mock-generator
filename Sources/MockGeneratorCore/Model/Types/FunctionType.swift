import Foundation

public struct FunctionType: Equatable {
    public let parameters: [TypeDescriptor]
    public let returnType: TypeDescriptor
    public let isAsync: Bool
    public let isThrows: Bool
}
