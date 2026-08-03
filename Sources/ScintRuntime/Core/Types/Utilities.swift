import Foundation
import CryptoKit


extension UUID {
    static func typeId(_ type: Any.Type) -> TypeId { deterministicTypeId(String(reflecting: type)) }

    static func deterministicTypeId(_ fullyQualifiedName: String) -> UUID {
        let data = Data(fullyQualifiedName.utf8)
        let digest = SHA256.hash(data: data)
        let bytes = [UInt8](digest)

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2],
            bytes[3], bytes[4], bytes[5],
            (bytes[6] & 0x0F) | 0x50, bytes[7],
            (bytes[8] & 0x3F) | 0x80, bytes[9],
            bytes[10], bytes[11], bytes[12],
            bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension String {
    var normalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .map { $0.isLetter || $0.isNumber ? String($0).lowercased() : " " }
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    var tokenized: [String] {
        normalized
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
