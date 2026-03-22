import Foundation
import ZipArchive

enum GameImporterError: LocalizedError {
    case unzipFailed

    var errorDescription: String? {
        switch self {
        case .unzipFailed:
            return "Khong the giai nen file ZIP."
        }
    }
}

enum GameImporter {
    static func importGame(from zipURL: URL) throws -> Game {
        let hasSecurityScope = zipURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                zipURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let gamesDirectory = try gamesDirectoryURL()
        let gameFolderName = zipURL.deletingPathExtension().lastPathComponent
        let destinationFolderURL = gamesDirectory.appendingPathComponent(gameFolderName, isDirectory: true)

        if fileManager.fileExists(atPath: destinationFolderURL.path) {
            try fileManager.removeItem(at: destinationFolderURL)
        }

        try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)

        let didUnzip = SSZipArchive.unzipFile(
            atPath: zipURL.path,
            toDestination: destinationFolderURL.path
        )
        guard didUnzip else {
            throw GameImporterError.unzipFailed
        }

        let detection = GameDetector.detectGame(at: destinationFolderURL)
        let gameName = detection.title ?? gameFolderName
        return Game(
            id: Game.stableID(for: destinationFolderURL.path),
            name: gameName,
            path: destinationFolderURL.path,
            version: detection.version
        )
    }

    static func loadInstalledGames() -> [Game] {
        let fileManager = FileManager.default
        guard let gamesDirectory = try? gamesDirectoryURL() else {
            return []
        }

        guard let urls = try? fileManager.contentsOfDirectory(
            at: gamesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let games = urls.compactMap { url -> Game? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }

            let detection = GameDetector.detectGame(at: url)
            let gameName = detection.title ?? url.lastPathComponent
            return Game(
                id: Game.stableID(for: url.path),
                name: gameName,
                path: url.path,
                version: detection.version
            )
        }

        return games.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func gamesDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let gamesURL = documentsURL.appendingPathComponent("Games", isDirectory: true)

        if !fileManager.fileExists(atPath: gamesURL.path) {
            try fileManager.createDirectory(at: gamesURL, withIntermediateDirectories: true)
        }

        return gamesURL
    }
}
