import Foundation

/// Runtime storage used by generated mock properties.
///
/// Keeping the unset state separate from a stored value is important for
/// optional properties: an explicitly configured `nil` is a valid stub value.
public final class MockPropertyStorage<Value>: @unchecked Sendable {
    private enum State {
        case unset
        case value(Value)
    }

    private var state: State = .unset
    public private(set) var getCount = 0
    public private(set) var setCount = 0

    public init() {}

    public func get(_ originalValue: Value? = nil) -> Value {
        getCount += 1
        switch state {
        case .value(let value):
            return value
        case .unset:
            if let optionalType = Value.self as? _MockOptionalType.Type {
                return optionalType.nilValue as! Value
            }
            if let originalValue {
                return originalValue
            }
            fatalError("No return value configured for mock property. If the property has non optional value you must provides an initial value during mock declaration into property name with 'Stub' suffix.")
        }
    }

    public func set(_ value: Value) {
        setCount += 1
        state = .value(value)
    }

    private func configure(_ value: Value) {
        state = .value(value)
    }
}

private protocol _MockOptionalType {
    static var nilValue: Any { get }
}

extension Optional: _MockOptionalType {
    fileprivate static var nilValue: Any { Self.none as Any }
}

extension MockPropertyStorage: AnyMockMethodStorage {
    
    public func setReturnValue(_ value: Any) {
        guard let typedValue = value as? Value else {
            fatalError("Configured property value has an incompatible type.")
        }
        configure(typedValue)
    }

    public func setThrowingError(_ error: Error) {
        fatalError("Throwing stubs are not supported for properties.")
    }

    public func setReturnValue(_ value: Any, matching matcher: MockInvocationMatcher) {
        guard matcher.arguments.isEmpty else {
            fatalError("Property stubs do not support argument matchers.")
        }
        setReturnValue(value)
    }

    public func setThrowingError(_ error: Error, matching matcher: MockInvocationMatcher) {
        setThrowingError(error)
    }

    public func setAnswer(_ answer: @escaping (MockInvocation) -> Any, matching matcher: MockInvocationMatcher) {
        fatalError("Custom answers are not supported for properties.")
    }

    public func matchingCallCount(_ matcher: MockInvocationMatcher) -> Int {
        guard matcher.arguments.isEmpty else { return 0 }
        return getCount
    }
    
    public func setDeferredReturnValue(_ provider: @escaping () -> Any) {
        let value = provider()
        guard let typedValue = value as? Value else {
            fatalError("Deferred return value has an incompatible type for mock property.")
        }
        configure(typedValue)
    }
}
