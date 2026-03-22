import Foundation
import CryptoKit

enum GameVersion: String, Codable {
    case mz
    case mv
    case unknown

    var badgeTitle: String {
        switch self {
        case .mz:
            return "MZ"
        case .mv:
            return "MV"
        case .unknown:
            return "?"
        }
    }
}

struct Game: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let version: GameVersion

    init(id: UUID = UUID(), name: String, path: String, version: GameVersion) {
        self.id = id
        self.name = name
        self.path = path
        self.version = version
    }

    static func stableID(for path: String) -> UUID {
        let digest = SHA256.hash(data: Data(path.utf8))
        let bytes = Array(digest.prefix(16))
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }
}
