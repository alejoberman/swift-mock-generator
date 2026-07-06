import XCTest
import MockGeneratorCore
import MockGeneratorCodeDOM
import MockGeneratorEmitter

final class GenerationPipelineTests: XCTestCase {

    private func parser() -> SwiftSyntaxProtocolParser {
        let typeParser = TypeParser()
        let parameterParser = ParameterParser(typeParser: typeParser)
        let methodParser = MethodParser(
            typeParser: typeParser,
            parameterParser: parameterParser
        )
        let propertyParser = PropertyParser(typeParser: typeParser)
        let visitor = ProtocolVisitor(
            methodParser: methodParser,
            propertyParser: propertyParser
        )
        return SwiftSyntaxProtocolParser(protocolVisitor: visitor)
    }

    private func generate(_ source: String) throws -> String {
        let descriptors = try parser().parse(source: source)
        XCTAssertEqual(descriptors.count, 1)

        let descriptor = try XCTUnwrap(descriptors.first)
        let transformer = MockTransformer()
        let mockDescriptor = transformer.generate(from: descriptor)
        let model = transformer.makeModel(from: mockDescriptor)
        let file = MockToSwiftTransformer().transform(model)

        return SwiftEmitter().emit(file)
    }

    func testCompletePipelineGeneratesBasicMock() throws {
        let source = """
        import Foundation
        
        protocol Repository {
            func load(id: UUID) -> User
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("import Foundation"))
        XCTAssertTrue(output.contains("import MockRuntime"))
        XCTAssertTrue(output.contains("final class MockRepository: Repository"))
        XCTAssertTrue(output.contains("private var _loadStorage: MockMethodStorage<UUID, User> = MockMethodStorage()"))
        XCTAssertTrue(output.contains("func load(id: UUID) -> User"))
        XCTAssertTrue(output.contains("func load(id: Any"))
        XCTAssertTrue(output.contains("MockRuntime.invocation(owner: self"))
        XCTAssertTrue(output.contains("return _loadStorage.invoke(id, arguments: [id], callArguments: [id])"))
    }

    func testCompletePipelinePreservesSourceImports() throws {
        let source = """
        import Foundation
        import SwiftUI

        protocol Repository {
            func load(id: UUID) -> User
        }

        struct User {}
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("import Foundation"))
        XCTAssertTrue(output.contains("import SwiftUI"))
        XCTAssertTrue(output.contains("import MockRuntime"))
    }

    func testCompletePipelineDoesNotAddUnusedFoundationImport() throws {
        let source = """
        protocol Repository {
            func reset()
        }
        """

        let output = try generate(source)

        XCTAssertFalse(output.contains("import Foundation"))
        XCTAssertTrue(output.contains("import MockRuntime"))
    }
    
    func testGenerationOfNonOptionalPropertiesOnStub() throws {
        let source = """
        protocol Repository {
            var currentPlaybackTime: TimeInterval { get }
                
            var isRadioPlayingPublisher: Published<RadioState>.Publisher { get }
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("currentPlaybackTimeStub: TimeInterval?"))
        XCTAssertTrue(output.contains("isRadioPlayingPublisherStub: Published<RadioState>.Publisher?"))
    }

    func testCompletePipelineDeduplicatesImports() throws {
        let source = """
        import Foundation
        import Foundation

        protocol Repository {
            func load(id: UUID) -> User
        }

        struct User {}
        """

        let output = try generate(source)

        XCTAssertEqual(output.components(separatedBy: "import Foundation").count - 1, 1)
        XCTAssertEqual(output.components(separatedBy: "import MockRuntime").count - 1, 1)
    }

    func testCompletePipelinePreservesAsyncThrowingAndVariadicMethod() throws {
        let source = """
        protocol Repository {
            func load(id: UUID, value: inout Int, names: String...) async throws -> User
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("func load(id: UUID, value: inout Int, names: String...) async throws -> User"))
        XCTAssertTrue(output.contains("MockMethodStorage<(UUID, Int, [String]), User>"))
        XCTAssertTrue(output.contains("try await _loadStorage.invokeAsyncThrowing((id, value, names), arguments: [id, value, names], callArguments: [id, value, names])"))
    }

    func testCompletePipelineGeneratesGetSetPropertyStorage() throws {
        let source = """
        protocol Repository {
            var onLinkClicked: (String) -> Void
            var onEvent: (String) -> Bool?
            var onEmpty: () -> ()
            var count: Int { get set }
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("private var _countStorage: MockPropertyStorage<Int> = MockPropertyStorage()"))
        XCTAssertTrue(output.contains("var count: Int"))
        XCTAssertTrue(output.contains("MockRuntime.recordPropertyAccess(owner: self, method: \"count\", storage: _countStorage)"))
        XCTAssertTrue(output.contains("return _countStorage.get(countStub)"))
        XCTAssertTrue(output.contains("onLinkClickedStub: ((String) -> Void)?"))
        XCTAssertTrue(output.contains("onEventStub: ((String) -> Bool?)?"))
        XCTAssertTrue(output.contains("onEmptyStub: (() -> ())?"))
        XCTAssertTrue(output.contains("_countStorage.set(newValue)"))
    }
    
    func testOptionalGetPropertyStorage() throws {
        let source = """
        protocol Repository {
            var count: Int? { get }
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("private var _countStorage: MockPropertyStorage<Int?> = MockPropertyStorage()"))
        XCTAssertTrue(output.contains("var count: Int?"))
        XCTAssertTrue(output.contains("MockRuntime.recordPropertyAccess(owner: self, method: \"count\", storage: _countStorage)"))
        XCTAssertTrue(output.contains("return _countStorage.get()"))
    }

    func testCompletePipelinePreservesMultipleInheritedTypes() throws {
        let source = """
        public protocol Repository: Sendable, Identifiable {
            func load() -> User
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("public final class MockRepository: Repository, @unchecked Sendable, Identifiable"))
        XCTAssertTrue(output.contains("public func load() -> User"))
    }



    func testInheritedProtocolMembersAreGeneratedForEveryConformance() throws {
        let source = """
        protocol BaseLoginInteractorInputProtocol {
            func resetSession()
        }

        protocol LoginInteractorInputProtocol: BaseLoginInteractorInputProtocol {
            func login(email: String, password: String) -> Bool
        }
        """
        let descriptors = try parser().parse(source: source)
        let child = try XCTUnwrap(descriptors.first(where: { $0.name == "LoginInteractorInputProtocol" }))
        let model = MockTransformer().makeModel(from: child, allProtocols: descriptors)
        let output = SwiftEmitter().emit(MockToSwiftTransformer().transform(model))

        XCTAssertTrue(output.contains("MockLoginInteractorInputProtocol: LoginInteractorInputProtocol, BaseLoginInteractorInputProtocol"))
        XCTAssertTrue(output.contains("func login(email: String, password: String) -> Bool"))
        XCTAssertTrue(output.contains("func resetSession()"))
        XCTAssertTrue(output.contains("_resetSessionStorage"))
    }
    
    func testInheritedCompositeProtocolsAreGeneratedForEveryConformance() throws {
        let source = """
        protocol BaseLoginInteractorInputProtocol {
            func resetSession()
        }

        protocol LoginInteractorInputProtocol {
            func login(email: String, password: String) -> Bool
        }
        
        protocol GeneralLoginProtocol: BaseLoginInteractorInputProtocol, LoginInteractorInputProtocol {
            func logout()
        }
        """
        let descriptors = try parser().parse(source: source)
        let child = try XCTUnwrap(descriptors.first(where: { $0.name == "GeneralLoginProtocol" }))
        let model = MockTransformer().makeModel(from: child, allProtocols: descriptors)
        let output = SwiftEmitter().emit(MockToSwiftTransformer().transform(model))

        XCTAssertTrue(output.contains("MockGeneralLoginProtocol: GeneralLoginProtocol, BaseLoginInteractorInputProtocol, LoginInteractorInputProtocol"))
        XCTAssertTrue(output.contains("func login(email: String, password: String) -> Bool"))
        XCTAssertTrue(output.contains("func resetSession()"))
        XCTAssertTrue(output.contains("func logout()"))
        XCTAssertTrue(output.contains("_resetSessionStorage"))
    }

    func testOverloadedMethodsReceiveDistinctStorageNames() throws {
        let source = """
        protocol Repository {
            func load(id: UUID) -> User
            func load(name: String) -> User
        }
        """
        let output = try generate(source)

        XCTAssertTrue(output.contains("_load_id_UUID_returns_UserStorage"))
        XCTAssertTrue(output.contains("_load_name_String_returns_UserStorage"))
        XCTAssertFalse(output.contains("private var _loadStorage"))
    }

    func testCallbackBasedAsyncMethodPreservesCompletionHandlerAndSupportsAnswer() throws {
        let source = """
        protocol DataRepository {
            func retrieveData(
                id: String,
                completionHandler: @escaping ([String]?, Error?) -> Void
            )
        }
        """

        let output = try generate(source)
        XCTAssertTrue(output.contains("func retrieveData(id: String, completionHandler: @escaping ([String]?, Error?) -> Void)"))
        XCTAssertTrue(output.contains("MockMethodStorage<(String, ([String]?, Error?) -> Void), Void>"))
        XCTAssertTrue(output.contains("callArguments: [id, completionHandler]"))
        XCTAssertTrue(output.contains("arguments: [id]"))
        XCTAssertTrue(output.contains("func retrieveData(id: Any, completionHandler: Any"))
    }

    func testGeneratedSourceCompilationMatrix() throws {
        let fixtures: [CompilationFixture] = [
            CompilationFixture(
                name: "basic method",
                source: """
                import Foundation

                protocol Repository {
                    func load(id: UUID) -> User
                }

                struct User {}
                """
            ),
            CompilationFixture(
                name: "void method",
                source: """
                protocol Repository {
                    func reset()
                }
                """
            ),
            CompilationFixture(
                name: "throwing method",
                source: """
                protocol Repository {
                    func load() throws -> User
                }

                struct User {}
                """
            ),
            CompilationFixture(
                name: "async method",
                source: """
                protocol Repository {
                    func load() async -> User
                }

                struct User {}
                """
            ),
            CompilationFixture(
                name: "async throwing method",
                source: """
                protocol Repository {
                    func load() async throws -> User
                }

                struct User {}
                """
            ),
            CompilationFixture(
                name: "inout and variadic parameters",
                source: """
                import Foundation

                protocol Repository {
                    func load(id: UUID, value: inout Int, names: String...) async throws -> User
                }

                struct User {}
                """
            ),
            CompilationFixture(
                name: "get set property",
                source: """
                protocol Repository {
                    var count: Int { get set }
                }
                """
            ),
            CompilationFixture(
                name: "get only property",
                source: """
                protocol Repository {
                    var name: String { get }
                }
                """
            ),
            CompilationFixture(
                name: "complex types",
                source: """
                protocol Repository {
                    func query(
                        filter: [String: Int]?,
                        completion: (String, Int) async throws -> User
                    ) -> (value: User?, count: Int)
                }

                struct User {}
                """
            ),
            CompilationFixture(
                name: "multiple inherited protocols",
                source: """
                import Foundation

                protocol Repository: Sendable, Identifiable {
                    var id: UUID { get }
                    func load() -> User
                }

                struct User {}
                """
            )
        ]

        var failures: [String] = []

        for fixture in fixtures {
            do {
                let generatedSource = try generate(fixture.source)
                try compileGeneratedSource(
                    generatedSource,
                    protocolSource: fixture.source
                )
            } catch {
                failures.append("[\(fixture.name)] \(error)")
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Generated-source compilation failures:\n\n" + failures.joined(separator: "\n\n")
        )
    }

    private struct CompilationFixture {
        let name: String
        let source: String
    }

    private func compileGeneratedSource(
        _ generatedSource: String,
        protocolSource: String
    ) throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let runtimeDirectory = root
            .appendingPathComponent("Sources")
            .appendingPathComponent("MockRuntime")

        let runtimeSources = try fileManager.contentsOfDirectory(
            at: runtimeDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(
            runtimeSources.isEmpty,
            "No MockRuntime Swift sources were found at \(runtimeDirectory.path)"
        )

        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(
                "SwiftMockGenerator-\(UUID().uuidString)",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        let runtimeModulePath = temporaryDirectory
            .appendingPathComponent("MockRuntime.swiftmodule")
        let protocolPath = temporaryDirectory
            .appendingPathComponent("Protocol.swift")
        let generatedPath = temporaryDirectory
            .appendingPathComponent("GeneratedMock.swift")
        let generatedModulePath = temporaryDirectory
            .appendingPathComponent("GeneratedMocks.swiftmodule")

        try protocolSource.write(
            to: protocolPath,
            atomically: true,
            encoding: .utf8
        )
        try generatedSource.write(
            to: generatedPath,
            atomically: true,
            encoding: .utf8
        )

        let runtimeResult = try runSwiftc([
            "-swift-version", "6",
            "-emit-module",
            "-parse-as-library",
            "-module-name", "MockRuntime",
            "-emit-module-path", runtimeModulePath.path
        ] + runtimeSources.map(\.path))

        guard runtimeResult.status == 0 else {
            throw CompilationError(
                message: "MockRuntime failed to compile:\n\(runtimeResult.output)"
            )
        }

        let generatedResult = try runSwiftc([
            "-swift-version", "6",
            "-emit-module",
            "-parse-as-library",
            "-module-name", "GeneratedMocks",
            "-I", temporaryDirectory.path,
            "-emit-module-path", generatedModulePath.path,
            protocolPath.path,
            generatedPath.path
        ])

        guard generatedResult.status == 0 else {
            throw CompilationError(
                message: "Generated source failed to compile:\n\(generatedResult.output)\n\nGenerated source:\n\(generatedSource)"
            )
        }
    }

    private struct CompilationError: Error, CustomStringConvertible {
        let message: String

        var description: String { message }
    }

    private func runSwiftc(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swiftc"] + arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return (process.terminationStatus, output)
    }

    func testCompletePipelinePreservesComplexTypes() throws {
        let source = """
        protocol Repository {
            func query(filter: [String: Int]?, completion: (String, Int) async throws -> User) -> (value: User?, count: Int)
        }
        """

        let output = try generate(source)

        XCTAssertTrue(output.contains("[String: Int]?"))
        XCTAssertTrue(output.contains("(String, Int) async throws -> User"))
        XCTAssertTrue(output.contains("(value: User?, count: Int)"))
    }
    
    func testCompletePipelineDeduplicatesIdenticalImports() throws {
        let source = """
        import Foundation
        import Foundation

        protocol Repository {
            func load(id: UUID) -> User
        }

        struct User {}
        """

        let output = try generate(source)

        XCTAssertEqual(output.components(separatedBy: "import Foundation").count - 1, 1)
    }
}
