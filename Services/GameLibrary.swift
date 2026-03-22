import Foundation

@MainActor
final class GameLibrary: ObservableObject {
    @Published var games: [Game] = []

    func loadGames() {
        games = GameImporter.loadInstalledGames()
    }

    func importGame(url: URL) async throws -> Game {
        let game = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let importedGame = try GameImporter.importGame(from: url)
                    continuation.resume(returning: importedGame)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        loadGames()
        return game
    }

    func deleteGame(_ game: Game) {
        let fileManager = FileManager.default
        let gameFolderURL = URL(fileURLWithPath: game.path, isDirectory: true)
        if fileManager.fileExists(atPath: gameFolderURL.path) {
            try? fileManager.removeItem(at: gameFolderURL)
        }

        if let saveFolderURL = saveDirectoryURL(for: game) {
            try? fileManager.removeItem(at: saveFolderURL)
        }

        games.removeAll { $0.path == game.path }
    }

    private func saveDirectoryURL(for game: Game) -> URL? {
        let fileManager = FileManager.default
        guard
            let documentsURL = try? fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else {
            return nil
        }

        return documentsURL
            .appendingPathComponent("Saves", isDirectory: true)
            .appendingPathComponent(game.id.uuidString, isDirectory: true)
    }
}
