import Foundation

public enum SwiftMember: Equatable {
    //nested structs (LoadInvocation)
    case nestedType(SwiftDeclaration)
    
    //stored variables (loadStorage)
    case variable(SwiftVariable)
    
    //computed properties
    case property(SwiftProperty)
    
    //methods
    case method(SwiftMethod)
}
