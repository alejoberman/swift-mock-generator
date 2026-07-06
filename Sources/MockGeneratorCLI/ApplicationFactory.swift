import Foundation
import MockGeneratorCore
import MockGeneratorEmitter

/// Build object graph behind a factory
enum ApplicationFactory {

    static func make() -> MockGeneratorApplication {

        let typeParser = TypeParser()

        let parameterParser = ParameterParser(typeParser: typeParser)

        let methodParser = MethodParser(typeParser: typeParser, parameterParser: parameterParser)

        let propertyParser = PropertyParser(typeParser: typeParser)

        let protocolVisitor = ProtocolVisitor(methodParser: methodParser,
                                              propertyParser: propertyParser)

        let parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)

        let transformer = MockTransformer()
        
        let swiftTransformer = MockToSwiftTransformer()
        
        let emitter = SwiftEmitter()

        return MockGeneratorApplication(parser: parser,
                                        transformer: transformer,
                                        swiftTransformer: swiftTransformer,
                                        emitter: emitter)
    }
}
