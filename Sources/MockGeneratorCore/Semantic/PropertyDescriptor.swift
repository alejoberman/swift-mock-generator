import Foundation

public struct PropertyDescriptor: Equatable {
    public let name: String
    public let type: TypeDescriptor
    public let getter: AccessorDescriptor?
    public let setter: AccessorDescriptor?
    
    public init(name: String, type: TypeDescriptor, getter: AccessorDescriptor?, setter: AccessorDescriptor?) {
        self.name = name
        self.type = type
        self.getter = getter
        self.setter = setter
    }
}

public struct AccessorDescriptor: Equatable {
    public let isAsync: Bool
    public let isThrows: Bool
    
    public init(isAsync: Bool, isThrows: Bool) {
        self.isAsync = isAsync
        self.isThrows = isThrows
    }
}
