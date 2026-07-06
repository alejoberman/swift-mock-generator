# Callback-based asynchronous methods

The generator preserves `@escaping` completion-handler parameters and records those closures in the invocation payload while excluding closure identity from argument matching.

For a protocol declaration such as:

```swift
protocol DataRepository {
    func retrieveData(
        id: String,
        completionHandler: @escaping ([String]?, Error?) -> Void
    )
}
```

configure the generated mock with `willAnswer`:

```swift
given(mock.retrieveData(id: "request-1", completionHandler: any()))
    .willAnswer { invocation in
        let completion: (([String]?, Error?) -> Void)? = invocation.argument(at: 1)
        completion?(["alpha", "beta"], nil)
        return ()
    }
```

To simulate an error response:

```swift
given(mock.retrieveData(id: "request-1", completionHandler: any()))
    .willAnswer { invocation in
        let completion: (([String]?, Error?) -> Void)? = invocation.argument(at: 1)
        completion?(nil, RepositoryError.unavailable)
        return ()
    }
```

The invocation argument indexes follow declaration order for capturable parameters. Ordinary argument matching ignores closure identity, so the `id` is matched while the callback is available to the answer. Non-escaping function parameters are not retained in the invocation payload.
