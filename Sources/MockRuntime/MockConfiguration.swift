import Foundation

/// A representation of a mock method or property invocation used during stubbing and verification.
///
/// `Mockable` acts as a lazy reference carrying the invocation key and argument matchers
/// needed to configure or verify mock behavior.
public struct Mockable<ReturnValue>: @unchecked Sendable {
    fileprivate let key: MockInvocationKey
    fileprivate let matcher: MockInvocationMatcher

    init(key: MockInvocationKey, matcher: MockInvocationMatcher) {
        self.key = key
        self.matcher = matcher
    }
}

/// A stubbing handle used to define the behavior of a mocked method or property when called.
public struct MockStub<ReturnValue>: @unchecked Sendable {
    private let key: MockInvocationKey
    private let matcher: MockInvocationMatcher

    init(key: MockInvocationKey, matcher: MockInvocationMatcher) {
        self.key = key
        self.matcher = matcher
    }

    /// Configures the mock to return a static value when the corresponding method or property is called.
    ///
    /// - Parameter value: The value to return.
    /// - Returns: The same `MockStub` instance for fluent chaining.
    @discardableResult
    public func willReturn(_ value: ReturnValue) -> Self {
        guard let storage = MockRuntimeRegistry.shared.storage(for: key) else {
            fatalError("Mock storage was not registered for \(key.method).")
        }
        storage.setReturnValue(value, matching: matcher)
        return self
    }
    
    /// Configures the mock to evaluate a provider closure and return its result at call time.
    ///
    /// Use this method when the `ReturnValue` needs to be dynamically generated or evaluated
    /// when the mock method is actually invoked, rather than at configuration time.
    ///
    /// - Parameter provider: A closure that evaluates and returns the `ReturnValue`.
    /// - Returns: The same `MockStub` instance for fluent chaining.
    @discardableResult
    public func willReturn(_ provider: @escaping () -> ReturnValue) -> Self {
        guard let storage = MockRuntimeRegistry.shared.storage(for: key) else {
            fatalError("Mock storage was not registered for \(key.method).")
        }
        storage.setDeferredReturnValue {
            provider()
        }
        return self
    }
    
    /// Configures the mock to return a value after a specified delay.
    /// Use this method to provide the `ReturnValue` delayed by `after` seconds.
    ///
    /// - Parameters:
    ///   - value: The value to return.
    ///   - after: The time delay in seconds before returning the value (defaults to `0.5`).
    /// - Returns: The same `MockStub` instance for fluent chaining.
    @discardableResult
    public func willReturnAfter(_ value: ReturnValue, after: Double = 0.5) async -> Self {
        try? await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
        guard let storage = MockRuntimeRegistry.shared.storage(for: key) else {
            fatalError("Mock storage was not registered for \(key.method).")
        }
        storage.setReturnValue(value, matching: matcher)
        return self
    }

    /// Configures a custom answer for the mock.
    ///
    /// The answer closure receives all actual arguments, including completion-handler closures,
    /// in declaration order via a `MockInvocation` object.
    ///
    /// - Parameter answer: A closure taking a `MockInvocation` and producing a `ReturnValue`.
    /// - Returns: The same `MockStub` instance for fluent chaining.
    @discardableResult
    public func willAnswer(_ answer: @escaping (MockInvocation) -> ReturnValue) -> Self {
        guard let storage = MockRuntimeRegistry.shared.storage(for: key) else {
            fatalError("Mock storage was not registered for \(key.method).")
        }
        storage.setAnswer({ invocation in answer(invocation) }, matching: matcher)
        return self
    }

    /// Configures the mock to throw an error when called.
    ///
    /// - Parameter error: The error to throw.
    /// - Returns: The same `MockStub` instance for fluent chaining.
    @discardableResult
    public func willThrow(_ error: Error) -> Self {
        guard let storage = MockRuntimeRegistry.shared.storage(for: key) else {
            fatalError("Mock storage was not registered for \(key.method).")
        }
        storage.setThrowingError(error, matching: matcher)
        return self
    }
}

/// Begins stubbing configuration for a given mock method invocation.
///
/// Example:
/// ```swift
/// given(mock.fetchData(for: .id)).willReturn(sampleData)
/// ```
///
/// - Parameter invocation: The `Mockable` invocation reference produced by the mock object.
/// - Returns: A `MockStub` configured to define behavior.
public func given<ReturnValue>(_ invocation: Mockable<ReturnValue>) -> MockStub<ReturnValue> {
    MockStub(key: invocation.key, matcher: invocation.matcher)
}

/// Configures a generated mock property using `given(mock.property)`.
///
/// The generated getter registers its storage immediately before returning.
///
/// - Parameter propertyValue: The captured property value placeholder.
/// - Returns: A `MockStub` configured to define property behavior.
public func given<ReturnValue>(_ propertyValue: ReturnValue) -> MockStub<ReturnValue> {
    guard let key = MockRuntimeRegistry.shared.consumePropertyCapture() else {
        fatalError("given(value) requires a generated mock property access, e.g. given(mock.property).")
    }
    return MockStub(key: key, matcher: MockInvocationMatcher(arguments: []))
}

/// A handle for verifying call counts and invocation patterns on a mock method or property.
public struct MockVerificationHandle: @unchecked Sendable {
    private let key: MockInvocationKey
    private let matcher: MockInvocationMatcher

    init(key: MockInvocationKey, matcher: MockInvocationMatcher) {
        self.key = key
        self.matcher = matcher
    }

    private func actualCount() -> Int {
        guard let storage = MockRuntimeRegistry.shared.storage(for: key) else {
            return 0
        }
        return storage.matchingCallCount(matcher)
    }

    /// Verifies that the mock was called an exact number of times.
    ///
    /// - Parameter expected: The expected number of invocations.
    /// - Returns: A `Verification` failure object if the count does not match, or `nil` on success.
    @discardableResult
    public func times(_ expected: Int) -> Verification? {
        let actual = actualCount()
        guard actual == expected else {
            return Verification(message: "Expected \(key.method) with matching arguments to be called \(expected) time(s), but it was called \(actual) time(s).")
        }
        return nil
    }

    /// Verifies that the mock was called exactly once.
    ///
    /// Equivalent to:
    ///
    /// ```swift
    /// given(mock.fetchData(for: .id)).times(1)
    /// ```
    ///
    /// - Returns: A `Verification` failure object if not called once, or `nil` on success.
    @discardableResult
    public func wasCalled() -> Verification? {
        times(1)
    }

    /// Verifies that the mock was never called.
    ///
    /// Equivalent to:
    ///
    /// ```swift
    /// given(mock.fetchData(for: .id)).times(0)
    /// ```
    ///
    /// - Returns: A `Verification` failure object if called at least once, or `nil` on success.
    @discardableResult
    public func never() -> Verification? {
        times(0)
    }

    /// Verifies that the mock was called at least a specified number of times.
    ///
    /// - Parameter expected: The minimum expected number of invocations.
    /// - Returns: A `Verification` failure object if the actual count is less than expected, or `nil` on success.
    @discardableResult
    public func atLeast(_ expected: Int) -> Verification? {
        let actual = actualCount()
        guard actual >= expected else {
            return Verification(message: "Expected \(key.method) with matching arguments to be called at least \(expected) time(s), but it was called \(actual) time(s).")
        }
        return nil
    }
}

/// Represents a verification failure containing a descriptive error message.
public struct Verification: Error {
    public let message: String
}

/// Begins verification for a given mock method invocation.
///
/// Example:
/// ```swift
/// verify(mock.save()).wasCalled()
/// ```
///
/// - Parameter invocation: The `Mockable` invocation reference produced by the mock object.
/// - Returns: A `MockVerificationHandle` used to assert call counts.
public func verify<ReturnValue>(_ invocation: Mockable<ReturnValue>) -> MockVerificationHandle {
    return MockVerificationHandle(key: invocation.key, matcher: invocation.matcher)
}
