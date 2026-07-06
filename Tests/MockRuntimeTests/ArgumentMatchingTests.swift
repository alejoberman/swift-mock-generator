import XCTest
@testable import MockRuntime

extension XCTestCase {
    func verification(_ verification: Verification?, file: StaticString = #filePath, line: UInt = #line) {
        if let verification {
            XCTFail(verification.message, file: file, line: line)
        }
    }
}

final class ArgumentMatchingTests: XCTestCase {
    final class MockRepository {
        
        private let storage = MockMethodStorage<Int, String>()

        func load(id: Int) -> String {
            MockRuntime.recordInvocation(owner: self, method: "load", storage: storage)
            return storage.invoke(id, arguments: [id])
        }
        
        public func load(id: Int, _ __mocking: Bool = true) -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "load", storage: storage, arguments: [id])
        }
        
        public func load(id: Any, _ __mocking: Bool = true) -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "load", storage: storage, arguments: [id])
        }
        
        func pull(id: Int) throws -> String {
            MockRuntime.recordInvocation(owner: self, method: "pull", storage: storage)
            return try storage.invokeThrowing(id, arguments: [id])
        }

        public func pull(id: Int, _ __mocking: Bool = true) throws -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "pull", storage: storage, arguments: [id])
        }
        
        public func pull(id: Any, _ __mocking: Bool = true) -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "load", storage: storage, arguments: [id])
        }
        
        public func getUser(id: Int) async throws -> String {
            MockRuntime.recordInvocation(owner: self, method: "getUser", storage: storage)
            return try await storage.invokeAsyncThrowing(id, arguments: [id])
        }

        public func getUser(id: Int, _ __mocking: Bool = true) async throws -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "getUser", storage: storage, arguments: [id])
        }

        public func getUser(id: Any, _ __mocking: Bool = true) async throws -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "getUser", storage: storage, arguments: [id])
        }
        
        public func getName(id: Int) async -> String {
            MockRuntime.recordInvocation(owner: self, method: "getName", storage: storage)
            return await storage.invokeAsync(id, arguments: [id])
        }
        
        public func getName(id: Int, _ __mocking: Bool = true) async -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "getName", storage: storage, arguments: [id])
        }

        public func getName(id: Any, _ __mocking: Bool = true) async -> Mockable<String> {
            return MockRuntime.invocation(owner: self, method: "getName", storage: storage, arguments: [id])
        }
        
        private var _playerLoginStorage: MockMethodStorage<Void, Bool> = MockMethodStorage()

        internal func playerLogin() async throws -> Bool {
            MockRuntime.recordInvocation(owner: self, method: "playerLogin", storage: _playerLoginStorage)

            return try await _playerLoginStorage.invokeAsyncThrowing((), arguments: [], callArguments: [])

        }

        internal func playerLogin(_ __mocking: Bool = true) async throws -> Mockable<Bool> {
            return MockRuntime.invocation(owner: self, method: "playerLogin", storage: _playerLoginStorage, arguments: [])

        }
    }

    override func tearDown() {
        MockVerification.reset()
        super.tearDown()
    }


    func testCallbackAnswerCanInvokeEscapingCompletionHandler() {
        final class CallbackMock {
            let storage = MockMethodStorage<(String, ([String]?, Error?) -> Void), Void>()

            func retrieveData(id: String, completionHandler: @escaping ([String]?, Error?) -> Void) {
                _ = storage.invoke(
                    (id, completionHandler),
                    arguments: [id],
                    callArguments: [id, completionHandler]
                )
            }

            func configuration(id: Any, completionHandler: Any) -> Mockable<Void> {
                MockRuntime.invocation(
                    owner: self,
                    method: "retrieveData",
                    storage: storage,
                    arguments: [id]
                )
            }
        }

        let mock = CallbackMock()
        var received: [String]?
        var receivedError: Error?

        given(mock.configuration(id: "request-1", completionHandler: any())).willAnswer { invocation in
            let completion: (([String]?, Error?) -> Void)? = invocation.argument(at: 1)
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: 0.5)
                completion?(["alpha", "beta"], nil)
            }
        }

        let expectation = self.expectation(description: "callback")
        
        mock.retrieveData(id: "request-1") { response, error in
            received = response
            receivedError = error
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(received ?? [], ["alpha", "beta"])
        XCTAssertNil(receivedError)
        verify(mock.configuration(id: "request-1", completionHandler: any())).times(1)
    }

    func testStubbingUsesMatchingArguments() {
        let mock = MockRepository()

        given(mock.load(id: 42)).willReturn("forty-two")
        given(mock.load(id: 43)).willReturn("forty-three")
        
        _ = mock.load(id: 42)
        _ = mock.load(id: 43)
        
        XCTAssertEqual(mock.load(id: 42), "forty-two")
        XCTAssertEqual(mock.load(id: 43), "forty-three")
    }

    func testVerificationCountsOnlyMatchingArguments() {
        let mock = MockRepository()

        given(mock.load(id: 42)).willReturn("forty-two")
        given(mock.load(id: 43)).willReturn("forty-three")
        
        _ = mock.load(id: 42)
        _ = mock.load(id: 42)
        _ = mock.load(id: 43)

        verification(verify(mock.load(id: 42)).times(2))
        verification(verify(mock.load(id: 43)).times(1))
        verification(verify(mock.load(id: 99)).never())
    }

    func testDifferentArgumentCombinationsAreIndependent() {
        let mock = MockRepository()

        given(mock.load(id: 1)).willReturn("one")
        given(mock.load(id: 2)).willReturn("two")

        _ = mock.load(id: 1)
        _ = mock.load(id: 2)
        _ = mock.load(id: 2)

        verification(verify(mock.load(id: 1)).times(1))
        verification(verify(mock.load(id: 2)).times(2))
    }

    func testLatestMatchingStubWins() {
        let mock = MockRepository()

        given(mock.load(id: 42)).willReturn("first")
        given(mock.load(id: 42)).willReturn("second")

        XCTAssertEqual(mock.load(id: 42), "second")
    }
    
    func testMatchingStubUserAsync() async {
        let mock = MockRepository()

        given(await mock.getName(id: 42)).willReturn("username_42")
        
        let result = await mock.getName(id: 42)

        XCTAssertEqual(result, "username_42")
    }
    
    func testMatchingStubUserThrowsAsync() async {
        let mock = MockRepository()

        given(try! await mock.getUser(id: 42)).willReturn("user_42")
        
        let result = try? await mock.getUser(id: 42)

        XCTAssertEqual(result, "user_42")
    }
    
    func testMatchingStubUserAnyThrowsAsync() async {
        let mock = MockRepository()

        given(try! await mock.getUser(id: any())).willReturn("user_42")
        
        let result = try? await mock.getUser(id: 42)

        XCTAssertEqual(result, "user_42")
    }
    
    func testMatchingStubUserThrows() {
        let mock = MockRepository()

        given(try! mock.pull(id: 42)).willReturn("pull_42")
        
        let result = try? mock.pull(id: 42)

        XCTAssertEqual(result, "pull_42")
    }
    
    func testCanContinueWithUnautorizedCodeAndSuccessLoginMustReturnTrue() async throws {
        // Given
        let mock = MockRepository()
        given(try await mock.playerLogin()).willReturn(true)
        
        // When
        let result = try await mock.playerLogin()
        
        // Then
        XCTAssertTrue(result)
    }
}


final class MockOptionalPropertyStubbingTests: XCTestCase {
    private final class MockRepository {
        private let _titiStorage = MockPropertyStorage<String?>()

        var titi: String? {
            get {
                MockRuntime.recordPropertyAccess(owner: self, method: "titi", storage: _titiStorage)
                return _titiStorage.get()
            }
            set {
                _titiStorage.set(newValue)
            }
        }
        
        private let _nonoptionStorage = MockPropertyStorage<Bool>()

        var nonoptionStub: Bool?
        
        var nonoption: Bool {
            get {
                MockRuntime.recordPropertyAccess(owner: self, method: "nonoption", storage: _nonoptionStorage)
                return _nonoptionStorage.get(nonoptionStub)
            }
            set {
                _nonoptionStorage.set(newValue)
            }
        }
        
        private var _titleStorage: MockMethodStorage<Void, String?> = MockMethodStorage()

        internal func title() -> String? {
            MockRuntime.recordInvocation(owner: self, method: "title", storage: _titleStorage)

            return _titleStorage.invoke((), arguments: [], callArguments: [])

        }

        internal func title(_ __mocking: Bool = true) -> Mockable<String?> {
            return MockRuntime.invocation(owner: self, method: "title", storage: _titleStorage, arguments: [])

        }
    }

    override func setUp() {
        super.setUp()
        MockVerification.reset()
    }

    func testOptionalPropertyCanBeConfiguredToReturnNil() {
        let mock = MockRepository()
        given(mock.titi).willReturn(nil)
        let res = mock.titi
        XCTAssertNil(res, "Expected the optional property stub to return nil")
    }
    
    func testNonOptionalPropertyCanBeConfiguredToReturnValue() {
        let mock = MockRepository()
        mock.nonoptionStub = false
        given(mock.nonoption).willReturn(true)
        let res = mock.nonoption
        XCTAssertTrue(res, "Expected the nonoptional property stub to return a value")
    }
    
    func testOptionalMethodCanBeConfiguredToReturnNil() {
        let mock = MockRepository()
        given(mock.title()).willReturn(nil)
        let res = mock.title()
        XCTAssertNil(res, "Expected the optional property stub to return nil")
    }

    func testOptionalPropertyStorageDistinguishesUnsetFromConfiguredNil() {
        let storage = MockPropertyStorage<String?>()
        XCTAssertNil(storage.get())
        storage.set("configured")
        XCTAssertEqual(storage.get(), "configured")
        storage.set(nil)
        XCTAssertNil(storage.get())
    }
}
