import Foundation
import MockGeneratorCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func printUsage() {
    print("""
    Usage: mockgen <swift-file-or-source-directory> [output-directory] [--scope all|used] [--tests TEST_DIRECTORY]

    --scope all   Generate mocks for every discovered protocol (default).
    --scope used  Generate only mocks referenced by Swift files in --tests.
    --tests       Directory containing the test target's Swift source files.
    --module      The module name under test.

    Example: mockgen Sources/MyApp Tests/GeneratedMocks --scope used --tests Tests/MyAppTests
    """)
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    printUsage()
    exit(EXIT_SUCCESS)
}

guard let sourceArgument = arguments.first, !sourceArgument.hasPrefix("--") else {
    printUsage()
    exit(EXIT_FAILURE)
}

var positional: [String] = []
var scope: MockGenerationScope = .all
var testDirectory: URL?
var moduleName = ""
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    switch argument {
    case "--scope":
        guard index + 1 < arguments.count else {
            fputs("mockgen: --scope requires 'all' or 'used'.\n", stderr)
            exit(EXIT_FAILURE)
        }
        switch arguments[index + 1] {
        case "all": scope = .all
        case "used": scope = .used
        default:
            fputs("mockgen: invalid scope '\(arguments[index + 1])'; expected 'all' or 'used'.\n", stderr)
            exit(EXIT_FAILURE)
        }
        index += 2
    case "--tests":
        guard index + 1 < arguments.count else {
            fputs("mockgen: --tests requires a directory.\n", stderr)
            exit(EXIT_FAILURE)
        }
        testDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        index += 2
    case "--module":
        guard index + 1 < arguments.count else {
            fputs("mockgen: --module requires a module name.\n", stderr)
            exit(EXIT_FAILURE)
        }
        moduleName = arguments[index + 1]
        index += 2
    default:
        if argument.hasPrefix("--") {
            fputs("mockgen: unknown option '\(argument)'.\n", stderr)
            exit(EXIT_FAILURE)
        }
        positional.append(argument)
        index += 1
    }
}

guard (1...2).contains(positional.count) else {
    printUsage()
    exit(EXIT_FAILURE)
}

let sourcePath = URL(fileURLWithPath: positional[0], isDirectory: true)
let outputPath = positional.count == 2
    ? URL(fileURLWithPath: positional[1], isDirectory: true)
    : URL(fileURLWithPath: "./GeneratedMocks", isDirectory: true)

do {
    try ApplicationFactory.make().run(
        sourcePath: sourcePath,
        outputDirectory: outputPath,
        scope: scope,
        testDirectory: testDirectory,
        moduleName: moduleName
    )
} catch {
    fputs("mockgen: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
