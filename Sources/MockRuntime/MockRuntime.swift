import Foundation

public enum MockRuntime {
    @discardableResult
    public static func recordInvocation<Invocation, ReturnValue>(
        owner: AnyObject,
        method: String,
        storage: MockMethodStorage<Invocation, ReturnValue>
    ) -> MockInvocationKey {
        MockRuntimeRegistry.shared.record(owner: owner, method: method, storage: storage)
    }

    @discardableResult
    public static func recordPropertyAccess<Value>(
        owner: AnyObject,
        method: String,
        storage: MockPropertyStorage<Value>
    ) -> MockInvocationKey {
        MockRuntimeRegistry.shared.recordPropertyAccess(
            owner: owner,
            method: method,
            storage: storage
        )
    }

    public static func invocation<Invocation, ReturnValue>(
        owner: AnyObject,
        method: String,
        storage: MockMethodStorage<Invocation, ReturnValue>,
        arguments: [Any]
    ) -> Mockable<ReturnValue> {
        let key = MockRuntimeRegistry.shared.registerConfiguration(
            owner: owner,
            method: method,
            storage: storage
        )
        let matcher = MockInvocationMatcher(arguments: arguments.map { argument in
            if let matcher = argument as? MockArgumentMatcher {
                return matcher
            }
            return MockArgumentMatcher.equals(argument)
        })
        return Mockable(key: key, matcher: matcher)
    }

    public static func invocation<Invocation, ReturnValue>(
        owner: AnyObject,
        method: String,
        storage: MockMethodStorage<Invocation, ReturnValue>
    ) -> Mockable<ReturnValue> {
        invocation(owner: owner, method: method, storage: storage, arguments: [])
    }
}
