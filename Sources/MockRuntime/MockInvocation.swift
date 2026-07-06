import Foundation

/// The arguments supplied to a mocked method invocation. This includes closure
/// parameters so configured answers can invoke completion handlers.
public struct MockInvocation: @unchecked Sendable {
    public let arguments: [Any]

    public init(arguments: [Any]) {
        self.arguments = arguments
    }

    public func argument<T>(at index: Int, as type: T.Type = T.self) -> T? {
        guard arguments.indices.contains(index) else { return nil }
        return arguments[index] as? T
    }
}

public struct MockInvocationKey: Hashable, @unchecked Sendable {
    public let object: ObjectIdentifier
    public let method: String

    public init(object: ObjectIdentifier, method: String) {
        self.object = object
        self.method = method
    }
}

public final class MockRuntimeRegistry: @unchecked Sendable {
    public static let shared = MockRuntimeRegistry()

    private let lock = NSLock()
    private var storages: [MockInvocationKey: AnyMockMethodStorage] = [:]
    private var capturing = false
    private var captured: MockInvocationKey?
    private var pendingPropertyCapture: MockInvocationKey?

    private init() {}

    public var isCapturing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return capturing
    }

    public func beginCapture() {
        lock.lock()
        defer { lock.unlock() }
        capturing = true
        captured = nil
    }

    @discardableResult
    public func registerConfiguration(
        owner: AnyObject,
        method: String,
        storage: AnyMockMethodStorage
    ) -> MockInvocationKey {
        lock.lock()
        defer { lock.unlock() }

        let key = MockInvocationKey(object: ObjectIdentifier(owner), method: method)
        storages[key] = storage
        pendingPropertyCapture = nil
        if capturing {
            captured = key
        }
        return key
    }

    @discardableResult
    public func record(
        owner: AnyObject,
        method: String,
        storage: AnyMockMethodStorage
    ) -> MockInvocationKey {
        lock.lock()
        defer { lock.unlock() }

        let key = MockInvocationKey(object: ObjectIdentifier(owner), method: method)
        storages[key] = storage
        return key
    }

    public func endCapture() -> MockInvocationKey {
        lock.lock()
        defer { lock.unlock() }

        capturing = false

        guard let captured else {
            fatalError("No mock invocation was captured. Use given(mock.method()) or verify(mock.method()).")
        }

        return captured
    }

    /// Registers a generated property access so `given(mock.property)` can
    /// associate the value expression with the property's storage.
    @discardableResult
    public func recordPropertyAccess(
        owner: AnyObject,
        method: String,
        storage: AnyMockMethodStorage
    ) -> MockInvocationKey {
        lock.lock()
        defer { lock.unlock() }

        let key = MockInvocationKey(object: ObjectIdentifier(owner), method: method)
        storages[key] = storage
        pendingPropertyCapture = key
        return key
    }

    /// Consumes the property access most recently registered by a generated getter.
    public func consumePropertyCapture() -> MockInvocationKey? {
        lock.lock()
        defer { lock.unlock() }
        defer { pendingPropertyCapture = nil }
        return pendingPropertyCapture
    }

    public func storage(for key: MockInvocationKey) -> AnyMockMethodStorage? {
        lock.lock()
        defer { lock.unlock() }
        return storages[key]
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        storages.removeAll()
        capturing = false
        captured = nil
        pendingPropertyCapture = nil
    }
}

public protocol AnyMockMethodStorage: AnyObject {
    func setReturnValue(_ value: Any)
    func setThrowingError(_ error: Error)
    func setReturnValue(_ value: Any, matching matcher: MockInvocationMatcher)
    func setThrowingError(_ error: Error, matching matcher: MockInvocationMatcher)
    func setAnswer(_ answer: @escaping (MockInvocation) -> Any, matching matcher: MockInvocationMatcher)
    func matchingCallCount(_ matcher: MockInvocationMatcher) -> Int
    func setDeferredReturnValue(_ provider: @escaping () -> Any)
}

extension MockMethodStorage: AnyMockMethodStorage {
    public func setAnswer(_ answer: @escaping (MockInvocation) -> Any, matching matcher: MockInvocationMatcher) {
        appendAnswer(answer, matching: matcher)
    }

    public func setReturnValue(_ value: Any) {
        guard let typed = value as? ReturnValue else {
            fatalError("Configured return value has an incompatible type.")
        }
        returnValue = typed
    }

    public func setThrowingError(_ error: Error) {
        throwingImplementation = { _ in throw error }
        asyncThrowingImplementation = { _ in throw error }
    }
    
    public func setDeferredReturnValue(_ provider: @escaping () -> Any) {
        implementation = { _ in
            guard let value = provider() as? ReturnValue else {
                fatalError("Deferred return value has an incompatible type.")
            }
            return value
        }
    }
}


public enum MockVerification {
    public static func reset() {
        MockRuntimeRegistry.shared.reset()
    }
}
