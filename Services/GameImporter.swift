import Foundation
import ZIPFoundation

enum GameImporterError: LocalizedError {
    case unzipFailed
    case invalidGameStructure

    var errorDescription: String? {
        switch self {
        case .unzipFailed:
            return "Khong the giai nen file ZIP."
        case .invalidGameStructure:
            return "Khong tim thay cau truc game hop le (www/index.html)."
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

        do {
            try fileManager.unzipItem(at: zipURL, to: destinationFolderURL)
        } catch {
            throw GameImporterError.unzipFailed
        }

        let gameRootURL = try locateGameRoot(in: destinationFolderURL)
        try normalizeExtractedGame(at: gameRootURL)
        patchGameFiles(at: gameRootURL)

        let detection = GameDetector.detectGame(at: gameRootURL)
        let gameName = detection.title ?? gameFolderName
        return Game(
            id: Game.stableID(for: gameRootURL.path),
            name: gameName,
            path: gameRootURL.path,
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

            let gameRootURL = (try? locateGameRoot(in: url)) ?? url

            let detection = GameDetector.detectGame(at: gameRootURL)
            let gameName = detection.title ?? gameRootURL.lastPathComponent
            return Game(
                id: Game.stableID(for: gameRootURL.path),
                name: gameName,
                path: gameRootURL.path,
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

    private static func locateGameRoot(in extractedDirectoryURL: URL) throws -> URL {
        let fileManager = FileManager.default

        func hasIndex(in root: URL) -> Bool {
            let indexURL = root
                .appendingPathComponent("www", isDirectory: true)
                .appendingPathComponent("index.html")
            return fileManager.fileExists(atPath: indexURL.path)
        }

        if hasIndex(in: extractedDirectoryURL) {
            return extractedDirectoryURL
        }

        guard let enumerator = fileManager.enumerator(
            at: extractedDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw GameImporterError.invalidGameStructure
        }

        while let candidate = enumerator.nextObject() as? URL {
            let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else {
                continue
            }

            if hasIndex(in: candidate) {
                return candidate
            }
        }

        throw GameImporterError.invalidGameStructure
    }

    private static func normalizeExtractedGame(at gameRootURL: URL) throws {
        let fileManager = FileManager.default
        let wwwURL = gameRootURL.appendingPathComponent("www", isDirectory: true)
        guard fileManager.fileExists(atPath: wwwURL.path) else {
            return
        }

        try normalizeDirectoryName(at: wwwURL, expectedName: "data")
        try normalizeDirectoryName(at: wwwURL, expectedName: "js")
        try normalizeDirectoryName(at: wwwURL, expectedName: "img")
        try normalizeDirectoryName(at: wwwURL, expectedName: "audio")
        try normalizeDirectoryName(at: wwwURL, expectedName: "fonts")

        try normalizeMVDataFiles(at: wwwURL.appendingPathComponent("data", isDirectory: true))
        try normalizeMVPluginFiles(at: wwwURL)
    }

    private static func normalizeDirectoryName(at parentURL: URL, expectedName: String) throws {
        let fileManager = FileManager.default
        let expectedURL = parentURL.appendingPathComponent(expectedName, isDirectory: true)
        if fileManager.fileExists(atPath: expectedURL.path) {
            return
        }

        guard
            let entries = try? fileManager.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }

        guard let match = entries.first(where: {
            $0.lastPathComponent.caseInsensitiveCompare(expectedName) == .orderedSame &&
            ((try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
        }) else {
            return
        }

        try fileManager.moveItem(at: match, to: expectedURL)
    }

    private static func normalizeMVDataFiles(at dataDirectoryURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: dataDirectoryURL.path) else {
            return
        }

        let expectedDatabaseFiles = [
            "Actors.json",
            "Classes.json",
            "Skills.json",
            "Items.json",
            "Weapons.json",
            "Armors.json",
            "Enemies.json",
            "Troops.json",
            "States.json",
            "Animations.json",
            "Tilesets.json",
            "CommonEvents.json",
            "System.json",
            "MapInfos.json"
        ]

        for fileName in expectedDatabaseFiles {
            try ensureFileExistsWithExpectedCase(fileName, in: dataDirectoryURL)
        }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: dataDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for entryURL in entries {
            guard entryURL.pathExtension.lowercased() == "json" else {
                continue
            }

            let name = entryURL.lastPathComponent
            let lowercased = name.lowercased()
            guard lowercased.hasPrefix("map"), lowercased.hasSuffix(".json") else {
                continue
            }

            let digits = String(lowercased.dropFirst(3).dropLast(5))
            guard digits.count == 3, digits.allSatisfy({ $0.isNumber }) else {
                continue
            }

            let canonicalName = "Map\(digits).json"
            let canonicalURL = dataDirectoryURL.appendingPathComponent(canonicalName)
            if !fileManager.fileExists(atPath: canonicalURL.path) {
                try fileManager.copyItem(at: entryURL, to: canonicalURL)
            }
        }
    }

    private static func normalizeMVPluginFiles(at wwwURL: URL) throws {
        let fileManager = FileManager.default
        let pluginsJSURL = wwwURL
            .appendingPathComponent("js", isDirectory: true)
            .appendingPathComponent("plugins.js")
        let pluginsDirectoryURL = wwwURL
            .appendingPathComponent("js", isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)

        guard
            fileManager.fileExists(atPath: pluginsJSURL.path),
            fileManager.fileExists(atPath: pluginsDirectoryURL.path),
            let content = try? String(contentsOf: pluginsJSURL, encoding: .utf8)
        else {
            return
        }

        let regex = try NSRegularExpression(pattern: "\"name\"\\s*:\\s*\"([^\"]+)\"")
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        let pluginNames = Set(matches.compactMap { match -> String? in
            guard match.numberOfRanges >= 2 else {
                return nil
            }
            let name = nsContent.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        })

        for pluginName in pluginNames {
            try ensureFileExistsWithExpectedCase("\(pluginName).js", in: pluginsDirectoryURL)
        }
    }

    private static func ensureFileExistsWithExpectedCase(_ expectedName: String, in directoryURL: URL) throws {
        let fileManager = FileManager.default
        let expectedURL = directoryURL.appendingPathComponent(expectedName)
        if fileManager.fileExists(atPath: expectedURL.path) {
            return
        }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        guard let match = entries.first(where: {
            $0.lastPathComponent.caseInsensitiveCompare(expectedName) == .orderedSame
        }) else {
            return
        }

        try fileManager.copyItem(at: match, to: expectedURL)
    }

    private static func patchGameFiles(at gameFolderURL: URL) {
        let fileManager = FileManager.default
        let jsURL = gameFolderURL.appendingPathComponent("www").appendingPathComponent("js")

        // -- 1. Patch rpg_managers.js (MV) --
        let managersURL = jsURL.appendingPathComponent("rpg_managers.js")
        if fileManager.fileExists(atPath: managersURL.path),
           var src = try? String(contentsOf: managersURL, encoding: .utf8),
           !src.contains("RPGPlayer-patched") {

            // Chi replace dung 1 expression, khong can match ca function
            src = src.replacingOccurrences(
                of: "window.top.document.hasFocus()",
                with: "true /*RPGPlayer-patched*/"
            )
            // Patch Utils.isNwjs
            src = src.replacingOccurrences(
                of: "return typeof require === \"function\" && typeof process === \"object\";",
                with: "return false; /*RPGPlayer-patched*/"
            )
            try? src.write(to: managersURL, atomically: true, encoding: .utf8)
            print("[Patcher] patched rpg_managers.js")
        }

        // -- 2. Patch rmmz_managers.js (MZ) --
        let rmmzURL = jsURL.appendingPathComponent("rmmz_managers.js")
        if fileManager.fileExists(atPath: rmmzURL.path),
           var src = try? String(contentsOf: rmmzURL, encoding: .utf8),
           !src.contains("RPGPlayer-patched") {

            src = src.replacingOccurrences(
                of: "window.top.document.hasFocus()",
                with: "true /*RPGPlayer-patched*/"
            )
            try? src.write(to: rmmzURL, atomically: true, encoding: .utf8)
            print("[Patcher] patched rmmz_managers.js")
        }

        // -- 3. Xoa hoan toan MAC_High_Hz_Fixes.js vi plugin nay crash tren iOS --
        let pluginsURL = jsURL.appendingPathComponent("plugins")
        let macFixURL = pluginsURL.appendingPathComponent("MAC_High_Hz_Fixes.js")
        if fileManager.fileExists(atPath: macFixURL.path) {
            // Thay bang file rong de plugin load khong loi nhung khong chay gi
            let empty = "/* MAC_High_Hz_Fixes disabled on iOS by RPGPlayer */"
            try? empty.write(to: macFixURL, atomically: true, encoding: .utf8)
            print("[Patcher] disabled MAC_High_Hz_Fixes.js")
        }
    }
}
