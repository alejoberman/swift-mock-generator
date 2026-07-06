import Foundation
import PackagePlugin
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
struct MockGeneratorCommandPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        guard (1...2).contains(arguments.count) else {
            Diagnostics.error("Usage: swift package generate-mocks <swift-file-or-source-directory> [output-directory]")
            throw PluginError.invalidArguments
        }

        let tool = try context.tool(named: "mockgen")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: context.package.directory.string)
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PluginError.generatorFailed(process.terminationStatus)
        }
    }
}

private enum PluginError: Error {
    case invalidArguments
    case generatorFailed(Int32)
}
