import Foundation

public indirect enum SwiftExpression: Equatable {
    case identifier(String)
    case member(base: SwiftExpression, name: String)
    case call(SwiftCallExpression)
    case assignment(left: SwiftExpression, right: SwiftExpression)
    case literal(SwiftLiteral)
    case closure(SwiftClosureExpression)
    case raw(String)
}

extension SwiftExpression {
    static func id(_ name: String) -> Self { .identifier(name) }

    static func member(_ base: Self, _ name: String) -> Self {
        .member(base: base, name: name)
    }

    static func call(_ callee: Self, _ arguments: SwiftArgument...) -> Self {
        .call(SwiftCallExpression(callee: callee, arguments: arguments))
    }
}
