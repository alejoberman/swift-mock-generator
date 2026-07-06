import XCTest
@testable import MockRuntime

extension XCTestCase {
    func verification(_ verification: Verification?, file: StaticString = #filePath, line: UInt = #line) {
        if let verification {
            XCTFail(verification.message, file: file, line: line)
        }
    }
}

final class MockRuntimeTests: XCTestCase {

    private final class Owner {}

    override func setUp() {
        super.setUp()
        MockVerification.reset()
    }

    func testExactArgumentMatcherSelectsMatchingStub() {
        let storage = MockMethodStorage<Int, String>()
        storage.returnValue = "default"

        storage.setReturnValue(
            "forty-two",
            matching: MockInvocationMatcher(arguments: [.equals(42)])
        )
        storage.setReturnValue(
            "seven",
            matching: MockInvocationMatcher(arguments: [.equals(7)])
        )

        XCTAssertEqual(storage.invoke(42, arguments: [42]), "forty-two")
        XCTAssertEqual(storage.invoke(7, arguments: [7]), "seven")
        XCTAssertEqual(storage.invoke(1, arguments: [1]), "default")
    }

    func testAnyArgumentMatcherMatchesAnyValue() {
        let storage = MockMethodStorage<Int, String>()

        storage.setReturnValue(
            "matched",
            matching: MockInvocationMatcher(arguments: [.any()])
        )

        XCTAssertEqual(storage.invoke(1, arguments: [1]), "matched")
        XCTAssertEqual(storage.invoke(999, arguments: [999]), "matched")
    }

    func testPredicateArgumentMatcher() {
        let storage = MockMethodStorage<Int, String>()

        storage.setReturnValue(
            "even",
            matching: MockInvocationMatcher(arguments: [
                .whereValue { ($0 as? Int).map { $0.isMultiple(of: 2) } ?? false }
            ])
        )

        XCTAssertEqual(storage.invoke(2, arguments: [2]), "even")
        XCTAssertEqual(storage.invoke(4, arguments: [4]), "even")
        XCTAssertNil(storage.returnValue)
    }

    func testGivenAndVerifyUseArgumentMatchers() {
        let owner = Owner()
        let storage = MockMethodStorage<Int, String>()

        given(
            MockRuntime.invocation(
                owner: owner,
                method: "load",
                storage: storage,
                arguments: [42]
            )
        ).willReturn("answer")

        XCTAssertEqual(storage.invoke(42, arguments: [42]), "answer")

        verification(verify(
            MockRuntime.invocation(
                owner: owner,
                method: "load",
                storage: storage,
                arguments: [42]
            )
        ).times(1))

        verification(verify(
            MockRuntime.invocation(
                owner: owner,
                method: "load",
                storage: storage,
                arguments: [7]
            )
        ).never())
    }

    func testLastMatchingStubWins() {
        let storage = MockMethodStorage<Int, String>()

        storage.setReturnValue(
            "any",
            matching: MockInvocationMatcher(arguments: [.any()])
        )
        storage.setReturnValue(
            "forty-two",
            matching: MockInvocationMatcher(arguments: [.equals(42)])
        )

        XCTAssertEqual(storage.invoke(42, arguments: [42]), "forty-two")
        XCTAssertEqual(storage.invoke(7, arguments: [7]), "any")
    }
    func testGlobalAnyMatcher() {
        let matcher = any()

        XCTAssertTrue(matcher.matches(1))
        XCTAssertTrue(matcher.matches("value"))
        XCTAssertTrue(matcher.matches(NSNull()))
    }

}
