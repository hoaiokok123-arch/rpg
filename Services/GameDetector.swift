import Foundation

struct GameDetectionResult {
    let version: GameVersion
    let title: String?
}

enum GameDetector {
    static func detectGame(at gameFolderURL: URL) -> GameDetectionResult {
        let fileManager = FileManager.default
        let wwwURL = gameFolderURL.appendingPathComponent("www", isDirectory: true)
        let packageURL = wwwURL.appendingPathComponent("package.json")

        if fileManager.fileExists(atPath: packageURL.path) {
            return GameDetectionResult(version: .mz, title: readTitle(from: packageURL))
        }

        let coreURL = wwwURL
            .appendingPathComponent("js", isDirectory: true)
            .appendingPathComponent("rpg_core.js")
        if fileManager.fileExists(atPath: coreURL.path) {
            return GameDetectionResult(version: .mv, title: nil)
        }

        return GameDetectionResult(version: .unknown, title: nil)
    }

    private static func readTitle(from packageURL: URL) -> String? {
        guard
            let data = try? Data(contentsOf: packageURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let title = jsonObject["title"] as? String
        else {
            return nil
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }
}
