import Foundation

if let arg = CommandLine.arguments.dropFirst().first {
    print(URL(fileURLWithPath: arg).resolvingSymlinksInPath().path)
} else {
    print(FileManager.default.currentDirectoryPath)
}
