import Foundation

public enum MemberDescriptor: Equatable {
    case method(MethodDescriptor)
    case property(PropertyDescriptor)
}
