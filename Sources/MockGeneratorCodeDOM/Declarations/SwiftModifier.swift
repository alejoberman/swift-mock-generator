import Foundation

public enum SwiftModifier: String, Equatable {
    case `public`
    case `package`
    case `private`
    case `fileprivate`
    case `internal`
    case `open`
    case `final`
    case `static`
    case `override`
    case `lazy`
    case `weak`
    case `mutating`
    case `unowned`
    case privateSet = "private(set)"
}
