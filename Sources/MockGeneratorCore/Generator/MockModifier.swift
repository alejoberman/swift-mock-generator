import Foundation

public enum MockModifier: String, Equatable {
    case `public`
    case `private`
    case `fileprivate`
    case `internal`
    case `open`
    case `final`
    case `static`
    case `override`
    case privateSet = "private(set)"
}
