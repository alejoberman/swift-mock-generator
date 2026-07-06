import Foundation

public struct MethodDescriptor: Equatable {

    public let name: String
    public let parameters: [ParameterDescriptor]
    public let returnType: TypeDescriptor?
    public let isAsync: Bool
    public let isThrows: Bool
    public let isRethrows: Bool
    
    public init(name: String,
                parameters: [ParameterDescriptor],
                returnType: TypeDescriptor?,
                isAsync: Bool,
                isThrows: Bool,
                isRethrows: Bool) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrows = isThrows
        self.isRethrows = isRethrows
    }
}
