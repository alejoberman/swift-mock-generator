import Foundation

/// Runtime storage used by generated mock methods.
public final class MockMethodStorage<Invocation, ReturnValue>: @unchecked Sendable {

    private struct Stub {
        let matcher: MockInvocationMatcher
        let returnValue: ReturnValue?
        let throwingError: Error?
        let answer: ((MockInvocation) -> Any)?
    }

    public private(set) var invocations: [Invocation] = []
    private var invocationArguments: [[Any]] = []
    private var stubs: [Stub] = []

    /// Fallback value used when no matching stub has been configured.
    public var returnValue: ReturnValue!

    public var implementation: ((Invocation) -> ReturnValue)?
    public var throwingImplementation: ((Invocation) throws -> ReturnValue)?
    public var asyncImplementation: (@Sendable (Invocation) async -> ReturnValue)?
    public var asyncThrowingImplementation: (@Sendable (Invocation) async throws -> ReturnValue)?

    public init() {}

    public func record(_ invocation: Invocation, arguments: [Any] = []) {
        invocations.append(invocation)
        invocationArguments.append(arguments)
    }

    public var callCount: Int {
        invocations.count
    }

    public func matchingCallCount(_ matcher: MockInvocationMatcher) -> Int {
        invocationArguments.reduce(into: 0) { count, arguments in
            if matcher.matches(arguments) {
                count += 1
            }
        }
    }

    public func setReturnValue(_ value: Any, matching matcher: MockInvocationMatcher) {
        guard let typed = value as? ReturnValue else {
            fatalError("Configured return value has an incompatible type.")
        }
        stubs.append(Stub(matcher: matcher, returnValue: typed, throwingError: nil, answer: nil))
    }

    public func setThrowingError(_ error: Error, matching matcher: MockInvocationMatcher) {
        stubs.append(Stub(matcher: matcher, returnValue: nil, throwingError: error, answer: nil))
    }

    public func appendAnswer(_ answer: @escaping (MockInvocation) -> Any, matching matcher: MockInvocationMatcher) {
        stubs.append(Stub(matcher: matcher, returnValue: nil, throwingError: nil, answer: answer))
    }

    private func matchingStub(for arguments: [Any]) -> Stub? {
        stubs.reversed().first { $0.matcher.matches(arguments) }
    }

    private func answerValue(from stub: Stub, callArguments: [Any]) -> ReturnValue? {
        guard let answer = stub.answer else { return nil }
        guard let value = answer(MockInvocation(arguments: callArguments)) as? ReturnValue else {
            fatalError("Configured answer returned a value incompatible with the mocked method's return type.")
        }
        return value
    }
    
    public func invoke(_ invocation: Invocation, arguments: [Any] = [], callArguments: [Any]? = nil) -> ReturnValue {
        record(invocation, arguments: arguments)
        let answerArguments = callArguments ?? arguments

        if let implementation {
            return implementation(invocation)
        }

        if let stub = matchingStub(for: arguments) {
            if let error = stub.throwingError {
                fatalError("A throwing stub was configured for a non-throwing invocation: \(error).")
            }
            if let value = answerValue(from: stub, callArguments: answerArguments) {
                return value
            }
            if let value = stub.returnValue {
                return value
            }
        }
        
        if let returnValue = returnValue {
            return returnValue
        }

        return defaultReturnValue()
    }
    
    private func defaultReturnValue() -> ReturnValue {
        if ReturnValue.self == Void.self {
            return (() as Any) as! ReturnValue
        }

        fatalError(
            "No return value configured for mock invocation."
        )
    }

    public func invokeThrowing(_ invocation: Invocation, arguments: [Any] = [], callArguments: [Any]? = nil) throws -> ReturnValue {
        record(invocation, arguments: arguments)
        let answerArguments = callArguments ?? arguments

        if let implementation = implementation {
            return implementation(invocation)
        }

        if let stub = matchingStub(for: arguments) {
            if let error = stub.throwingError {
                throw error
            }
            if let value = answerValue(from: stub, callArguments: answerArguments) {
                return value
            }
            if let value = stub.returnValue {
                return value
            }
        }

        if let throwingImplementation = throwingImplementation {
            return try throwingImplementation(invocation)
        }

        if let returnValue = returnValue {
            return returnValue
        }

        return defaultReturnValue()
    }

    public func invokeAsync(_ invocation: Invocation, arguments: [Any] = [], callArguments: [Any]? = nil) async -> ReturnValue {
        record(invocation, arguments: arguments)
        let answerArguments = callArguments ?? arguments

        if let asyncImplementation {
            return await asyncImplementation(invocation)
        }

        if let stub = matchingStub(for: arguments) {
            if let error = stub.throwingError {
                fatalError("A throwing stub was configured for a non-throwing invocation: \(error).")
            }
            if let value = answerValue(from: stub, callArguments: answerArguments) {
                return value
            }
            if let value = stub.returnValue {
                return value
            }
        }

        if let implementation {
            return implementation(invocation)
        }

        return returnValue
    }

    public func invokeAsyncThrowing(_ invocation: Invocation, arguments: [Any] = [], callArguments: [Any]? = nil) async throws -> ReturnValue {
        record(invocation, arguments: arguments)
        let answerArguments = callArguments ?? arguments

        if let asyncThrowingImplementation {
            return try await asyncThrowingImplementation(invocation)
        }

        if let stub = matchingStub(for: arguments) {
            if let error = stub.throwingError {
                throw error
            }
            if let value = answerValue(from: stub, callArguments: answerArguments) {
                return value
            }
            if let value = stub.returnValue {
                return value
            }
        }

        if let asyncImplementation {
            return await asyncImplementation(invocation)
        }

        if let throwingImplementation {
            return try throwingImplementation(invocation)
        }

        if let implementation {
            return implementation(invocation)
        }

        return returnValue
    }
}
