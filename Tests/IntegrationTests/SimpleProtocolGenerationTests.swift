import XCTest
@testable import MockGeneratorCore
@testable import MockGeneratorEmitter

final class SimpleProtocolGenerationTests: XCTestCase {

    var typeParser: TypeParser!
    var parameterParser: ParameterParser!
    var methodParser: MethodParser!
    var propertyParser: PropertyParser!
    var protocolVisitor: ProtocolVisitor!
    var parser: SwiftSyntaxProtocolParser!
    var transformer: MockTransformer!
    var swiftTransformer: MockToSwiftTransformer!
    var emitter: SwiftEmitter!

    override func setUpWithError() throws {
        typeParser = TypeParser()
        parameterParser = ParameterParser(typeParser: typeParser)
        methodParser = MethodParser(typeParser: typeParser, parameterParser: parameterParser)
        propertyParser = PropertyParser(typeParser: typeParser)
        protocolVisitor = ProtocolVisitor(methodParser: methodParser,
                                          propertyParser: propertyParser)
        parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)
        transformer = MockTransformer()
        swiftTransformer = MockToSwiftTransformer()
        emitter = SwiftEmitter()
    }

    func testSkeletonGeneration() throws {
        //Given
        let source = """
        protocol UserTotoRepository {
            func load(id: UUID) async throws -> User
        }
        """
        var generatedCode: String = ""
        
        //When
        let parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)
        
        if let protocols = try? parser.parse(source: source) {
            for descriptor in protocols {
                let model = transformer.makeModel(from: descriptor)
                let swiftFile = swiftTransformer.transform(model)
                let generatedSource = emitter.emit(swiftFile)
                generatedCode += generatedSource
            }
        }

        //Then
        XCTAssertTrue(generatedCode.contains("MockUserTotoRepository"), "Unexpected code generated")
        XCTAssertTrue(generatedCode.contains("func load(id: UUID) async throws -> User"), "Unexpected code generated")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
