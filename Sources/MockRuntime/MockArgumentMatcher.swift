import Foundation

/// Type-erased matcher used by generated mocks to compare invocation arguments.
///
/// The matcher is intentionally type-erased because generated methods may have
/// completely unrelated argument types. The generated code supplies the
/// arguments as `Any` values while the matcher retains the expected value or
/// predicate.
public struct MockArgumentMatcher: @unchecked Sendable {
    private let predicate: (Any) -> Bool

    public init(_ predicate: @escaping (Any) -> Bool) {
        self.predicate = predicate
    }

    public func matches(_ actual: Any) -> Bool {
        predicate(actual)
    }

    /// Matches every argument.
    public static func any() -> Self {
        Self { _ in true }
    }

    /// Matches an argument using the runtime's best available value equality.
    public static func equals<T>(_ expected: T) -> Self {
        Self { actual in
            MockArgumentMatcher.valuesEqual(expected, actual)
        }
    }

    /// Creates a matcher from an arbitrary predicate.
    public static func whereValue(_ predicate: @escaping (Any) -> Bool) -> Self {
        Self(predicate)
    }

    private static func valuesEqual(_ expected: Any, _ actual: Any) -> Bool {
        if let expected = expected as? AnyHashable,
           let actual = actual as? AnyHashable {
            return expected == actual
        }

        if let expectedObject = expected as? NSObject,
           let actualObject = actual as? NSObject {
            return expectedObject === actualObject || expectedObject.isEqual(actualObject)
        }

        // Swift does not expose a general `Any == Any` operation. For value
        // types which do not conform to Equatable we use their reflected value
        // representation as a deterministic fallback rather than silently
        // treating all values as equal.
        return String(reflecting: expected) == String(reflecting: actual)
    }
}

public struct MockInvocationMatcher: @unchecked Sendable {
    public let arguments: [MockArgumentMatcher]

    public init(arguments: [MockArgumentMatcher]) {
        self.arguments = arguments
    }

    public func matches(_ actual: [Any]) -> Bool {
        guard arguments.count == actual.count else { return false }
        return zip(arguments, actual).allSatisfy { matcher, value in
            matcher.matches(value)
        }
    }
}

/// Matches any value when used in a generated mock configuration call.
public func any() -> MockArgumentMatcher {
    .any()
}

/// Matches a value using the runtime's equality semantics.
public func equal<T>(_ expected: T) -> MockArgumentMatcher {
    .equals(expected)
}

/// Matches a value using a custom predicate.
public func matching(_ predicate: @escaping (Any) -> Bool) -> MockArgumentMatcher {
    .whereValue(predicate)
}
