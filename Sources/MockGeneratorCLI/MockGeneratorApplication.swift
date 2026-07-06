import Foundation
import MockGeneratorCore
import MockGeneratorEmitter

struct MockGeneratorApplication {

    private let parser: SwiftSyntaxProtocolParser
    private let transformer: MockTransformer
    
    private let swiftTransformer: MockToSwiftTransformer
    private let emitter: SwiftEmitter
    private let testUsageDiscovery = TestUsageDiscovery()
    private let usedProtocolFilter = UsedProtocolFilter()

    init(parser: SwiftSyntaxProtocolParser,
         transformer: MockTransformer,
         swiftTransformer: MockToSwiftTransformer,
         emitter: SwiftEmitter) {
        self.parser = parser
        self.transformer = transformer
        self.swiftTransformer = swiftTransformer
        self.emitter = emitter
    }

    func run(
        input: URL,
        outputDirectory: URL = URL(fileURLWithPath: "./GeneratedMocks"),
        scope: MockGenerationScope = .all,
        testDirectory: URL? = nil,
        moduleName: String
    ) throws {
        let outputURL = outputDirectory.standardizedFileURL
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        print("Mocks output: \(outputURL.path)")
        let source = try String(contentsOf: input, encoding: .utf8)
        let protocols = try parser.parse(source: source)
        let selected = try selectProtocols(protocols, scope: scope, testDirectory: testDirectory)
        try generateMocks(protocols: selected, allProtocols: protocols, outputDirectory: outputURL, moduleName: moduleName)
    }

    /// Generates mocks from one Swift file or every Swift file under a directory.
    func run(
        sourcePath: URL,
        outputDirectory: URL = URL(fileURLWithPath: "./GeneratedMocks"),
        scope: MockGenerationScope = .all,
        testDirectory: URL? = nil,
        moduleName: String
    ) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourcePath.path, isDirectory: &isDirectory) else {
            throw MockGeneratorCLIError.pathDoesNotExist(sourcePath.path)
        }
        guard isDirectory.boolValue else {
            try run(input: sourcePath, outputDirectory: outputDirectory, scope: scope, testDirectory: testDirectory, moduleName: moduleName)
            return
        }

        let outputURL = outputDirectory.standardizedFileURL
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        print("Scanning Swift sources under: \(sourcePath.path)")
        print("Mocks output: \(outputURL.path)")

        // TODO: add ignored directories dinamically.
        let ignoredDirectoryNames: Set<String> = [".build", ".git", "DerivedData", "Pods", "Carthage", "GeneratedMocks"]
        guard let enumerator = FileManager.default.enumerator(
            at: sourcePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw MockGeneratorCLIError.cannotEnumerate(sourcePath.path)
        }

        let outputPath = outputURL.resolvingSymlinksInPath().standardizedFileURL.path
        var sourceFiles: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                if ignoredDirectoryNames.contains(url.lastPathComponent) ||
                    url.resolvingSymlinksInPath().standardizedFileURL.path == outputPath {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension == "swift" else { continue }
            let standardizedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
            if standardizedPath.hasPrefix(outputPath + "/") || standardizedPath == outputPath { continue }
            sourceFiles.append(url)
        }

        sourceFiles.sort { $0.path < $1.path }
        guard !sourceFiles.isEmpty else {
            print("No Swift source files found.")
            return
        }
        var allProtocols: [ProtocolDescriptor] = []
        for sourceFile in sourceFiles {
            let source = try String(contentsOf: sourceFile, encoding: .utf8)
            allProtocols.append(contentsOf: try parser.parse(source: source))
        }
        let selected = try selectProtocols(allProtocols, scope: scope, testDirectory: testDirectory)
        try generateMocks(protocols: selected, allProtocols: allProtocols, outputDirectory: outputURL, moduleName: moduleName)
        print("Processed \(sourceFiles.count) Swift source file(s).")
    }

    private func selectProtocols(
        _ protocols: [ProtocolDescriptor],
        scope: MockGenerationScope,
        testDirectory: URL?
    ) throws -> [ProtocolDescriptor] {
        guard scope == .used else { return protocols }
        guard let testDirectory else {
            throw MockGeneratorCLIError.testDirectoryRequired
        }
        let references = try testUsageDiscovery.discoverMockTypeNames(in: testDirectory)
        let selected = usedProtocolFilter.filter(protocols, referencedMockTypeNames: references)
        print("Used-mock filtering: found \(references.count) mock type reference(s); generating \(selected.count) of \(protocols.count) discovered protocol(s).")
        return selected
    }

    private func generateMocks(
        protocols: [ProtocolDescriptor],
        allProtocols: [ProtocolDescriptor],
        outputDirectory: URL,
        moduleName: String
    ) throws {
        let moduleUnderText = "@testable import \(moduleName)\n"
        for descriptor in protocols {
            let model = transformer.makeModel(from: descriptor, allProtocols: allProtocols)
            let swiftFile = swiftTransformer.transform(model)
            let generatedSource = moduleUnderText + emitter.emit(swiftFile)
            let destination = outputDirectory.appendingPathComponent(model.className + ".swift")
            try generatedSource.write(to: destination, atomically: true, encoding: .utf8)
            print("Generated \(destination.lastPathComponent) from protocol \(descriptor.name)")
        }
    }
}

enum MockGenerationScope: Equatable {
    case all
    case used
}

private enum MockGeneratorCLIError: Error, CustomStringConvertible {
    case pathDoesNotExist(String)
    case cannotEnumerate(String)
    case testDirectoryRequired

    var description: String {
        switch self {
        case .pathDoesNotExist(let path): return "Source path does not exist: \(path)"
        case .cannotEnumerate(let path): return "Cannot enumerate source directory: \(path)"
        case .testDirectoryRequired: return "--scope used requires --tests <test-source-directory>."
        }
    }
}
