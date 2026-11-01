import CommonCrypto
import Foundation

// MARK: - Bank balance from the ATS savegame
//
// REV12 telemetry does not expose the player's bank account, so the balance is
// read from the newest savegame. ATS writes that value when it autosaves or
// when the player makes a quicksave; the reader refreshes without blocking the
// dashboard's render loop.

final class BankBalanceReader {
    private let queue = DispatchQueue(label: "com.hsgaming.ats.bank-reader", qos: .utility)
    private let lock = NSLock()
    private var cached: Int64?
    private var lastPath: String?
    private var lastModified: Date?
    private var timer: DispatchSourceTimer?

    init() {
        queue.async { [weak self] in
            self?.refresh(force: true)
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + 2,
            repeating: 4,
            leeway: .milliseconds(500)
        )
        timer.setEventHandler { [weak self] in
            self?.refresh(force: false)
        }
        timer.resume()
        self.timer = timer
    }

    deinit {
        timer?.cancel()
    }

    func current() -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    private func refresh(force: Bool) {
        guard let url = newestSave() else { return }

        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let modified = values?.contentModificationDate

        lock.lock()
        let unchanged = url.path == lastPath && modified == lastModified
        lock.unlock()

        if !force && unchanged {
            return
        }

        guard let balance = SIIBankParser.bankBalance(at: url) else {
            return
        }

        lock.lock()
        cached = balance
        lastPath = url.path
        lastModified = modified
        lock.unlock()
    }

    private func newestSave() -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var roots: [URL] = []

        let steamUsers = home.appendingPathComponent(
            "Library/Application Support/Steam/userdata",
            isDirectory: true
        )
        if let users = try? fileManager.contentsOfDirectory(
            at: steamUsers,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            for user in users {
                let profiles = user.appendingPathComponent(
                    "270880/remote/profiles",
                    isDirectory: true
                )
                if fileManager.fileExists(atPath: profiles.path) {
                    roots.append(profiles)
                }
            }
        }

        addProfileRoots(
            from: home.appendingPathComponent(
                "Library/Application Support/American Truck Simulator",
                isDirectory: true
            ),
            to: &roots
        )
        addProfileRoots(
            from: home.appendingPathComponent(
                "Documents/American Truck Simulator",
                isDirectory: true
            ),
            to: &roots
        )
        addProfileRoots(
            from: home.appendingPathComponent(
                "Library/CloudStorage/OneDrive-Personal/Documentos/American Truck Simulator",
                isDirectory: true
            ),
            to: &roots
        )

        var newest: (url: URL, modified: Date)?

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.lastPathComponent == "game.sii" else { continue }
                guard !url.path.contains(".bak") else { continue }

                let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .contentModificationDateKey]
                )
                guard values?.isRegularFile == true else { continue }

                let modified = values?.contentModificationDate ?? .distantPast
                if newest == nil || modified > newest!.modified {
                    newest = (url, modified)
                }
            }
        }

        return newest?.url
    }

    private func addProfileRoots(from base: URL, to roots: inout [URL]) {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return
        }

        for entry in entries {
            let name = entry.lastPathComponent
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?
                .isDirectory == true
            guard isDirectory else { continue }

            if name == "profiles"
                || name == "steam_profiles"
                || (name.hasPrefix("steam_profiles") && !name.hasSuffix(".bak")) {
                roots.append(entry)
            }
        }
    }
}

// MARK: - SII parsing

enum SIIBankParser {
    // SCS uses the same AES key for the encrypted save container.
    private static let key: [UInt8] = [
        0x2a, 0x5f, 0xcb, 0x17, 0x91, 0xd2, 0x2f, 0xb6,
        0x02, 0x45, 0xb3, 0xd8, 0x36, 0x9e, 0xd0, 0xb2,
        0xc2, 0x73, 0x71, 0x56, 0x3f, 0xbf, 0x1f, 0x3c,
        0x9e, 0xdf, 0x6b, 0x11, 0x82, 0x5a, 0x5d, 0x0a
    ]

    private static let scsCSignature: UInt32 = 0x4373_6353 // "ScsC"
    private static let bsiiSignature: UInt32 = 0x4949_5342 // "BSII"
    private static let siiNSignature: UInt32 = 0x4e69_6953 // "SiiN"

    static func bankBalance(at url: URL) -> Int64? {
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        return bankBalance(from: bytes)
    }

    static func bankBalance(from bytes: Data) -> Int64? {
        guard bytes.count >= 4, let signature = readUInt32(bytes, at: 0) else {
            return nil
        }

        if signature == scsCSignature {
            guard let decoded = decryptScsC(bytes) else { return nil }
            return parseBSII(decoded)
        }

        if signature == bsiiSignature {
            return parseBSII(bytes)
        }

        if signature == siiNSignature {
            return parsePlainText(bytes)
        }

        return nil
    }

    private static func decryptScsC(_ encrypted: Data) -> Data? {
        guard encrypted.count > 56 else { return nil }

        let iv = [UInt8](encrypted[36..<52])
        let ciphertext = encrypted.subdata(in: 56..<encrypted.count)
        var output = Data(count: ciphertext.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        let ciphertextLength = ciphertext.count
        let keyLength = key.count
        var outputLength = 0

        let status = ciphertext.withUnsafeBytes { inputBytes in
            iv.withUnsafeBytes { ivBytes in
                key.withUnsafeBytes { keyBytes in
                    output.withUnsafeMutableBytes { outputBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            keyLength,
                            ivBytes.baseAddress,
                            inputBytes.baseAddress,
                            ciphertextLength,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }

        let decrypted = Data(output.prefix(outputLength))
        return inflate(decrypted)
    }

    private static func inflate(_ compressed: Data) -> Data? {
        // NSData's .zlib algorithm expects a raw DEFLATE stream. SCS stores a
        // standard zlib stream, so remove its two-byte header and Adler-32
        // trailer before inflating.
        guard compressed.count > 6 else { return nil }
        let deflated = compressed.dropFirst(2).dropLast(4)
        guard let inflated = try? (Data(deflated) as NSData).decompressed(using: .zlib) else {
            return nil
        }
        return inflated as Data
    }

    private static func parsePlainText(_ bytes: Data) -> Int64? {
        guard let text = String(data: bytes, encoding: .utf8) else { return nil }
        guard let regex = try? NSRegularExpression(
            pattern: #"money_account\s*:\s*(-?\d+)"#
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Int64(text[valueRange])
    }

    private static func readUInt32(_ bytes: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    private struct Field {
        let name: String
        let type: UInt32
    }

    private struct Template {
        let name: String
        let fields: [Field]
    }

    private struct Reader {
        let bytes: Data
        var offset = 0

        var remaining: Int {
            bytes.count - offset
        }

        mutating func readUInt8() throws -> UInt8 {
            guard offset < bytes.count else { throw SIIError.invalidData }
            defer { offset += 1 }
            return bytes[offset]
        }

        mutating func readUInt32() throws -> UInt32 {
            guard offset + 4 <= bytes.count else { throw SIIError.invalidData }
            defer { offset += 4 }
            return UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        }

        mutating func readUInt64() throws -> UInt64 {
            let low = UInt64(try readUInt32())
            let high = UInt64(try readUInt32())
            return low | (high << 32)
        }

        mutating func readString() throws -> String {
            let length = Int(try readUInt32())
            guard length >= 0, offset + length <= bytes.count else {
                throw SIIError.invalidData
            }
            let range = offset..<(offset + length)
            offset += length
            return String(decoding: bytes[range], as: UTF8.self)
        }

        mutating func skip(_ count: Int) throws {
            guard count >= 0, offset + count <= bytes.count else {
                throw SIIError.invalidData
            }
            offset += count
        }

        mutating func skipIdentifier() throws {
            let parts = Int(try readUInt8())
            if parts == 0xFF {
                try skip(8)
            } else {
                try skip(parts * 8)
            }
        }

        mutating func skipField(type: UInt32, version: UInt32) throws {
            switch type {
            case 1:
                _ = try readString()
            case 2:
                let count = Int(try readUInt32())
                for _ in 0..<count { _ = try readString() }
            case 3:
                try skip(8)
            case 4:
                try skip(Int(try readUInt32()) * 8)
            case 5:
                try skip(4)
            case 6:
                try skip(Int(try readUInt32()) * 4)
            case 7:
                try skip(8)
            case 8:
                try skip(Int(try readUInt32()) * 8)
            case 9:
                try skip(12)
            case 10:
                try skip(Int(try readUInt32()) * 12)
            case 17:
                try skip(12)
            case 18:
                try skip(Int(try readUInt32()) * 12)
            case 23:
                try skip(16)
            case 24:
                try skip(Int(try readUInt32()) * 16)
            case 25:
                try skip(version == 1 ? 28 : 32)
            case 26:
                try skip(Int(try readUInt32()) * (version == 1 ? 28 : 32))
            case 37:
                try skip(4)
            case 38:
                try skip(Int(try readUInt32()) * 4)
            case 39:
                try skip(4)
            case 40:
                try skip(Int(try readUInt32()) * 4)
            case 41:
                try skip(2)
            case 42:
                try skip(Int(try readUInt32()) * 2)
            case 43:
                try skip(2)
            case 44:
                try skip(Int(try readUInt32()) * 2)
            case 47:
                try skip(4)
            case 49:
                try skip(8)
            case 50:
                try skip(Int(try readUInt32()) * 8)
            case 51:
                try skip(8)
            case 52:
                try skip(Int(try readUInt32()) * 8)
            case 53:
                try skip(1)
            case 54:
                try skip(Int(try readUInt32()))
            case 55:
                try skip(4)
            case 57, 59, 61:
                try skipIdentifier()
            case 58, 60, 62:
                let count = Int(try readUInt32())
                for _ in 0..<count { try skipIdentifier() }
            default:
                throw SIIError.unsupportedType(type)
            }
        }
    }

    private enum SIIError: Error {
        case invalidData
        case unsupportedType(UInt32)
    }

    private static func parseBSII(_ bytes: Data) -> Int64? {
        var reader = Reader(bytes: bytes)
        var templates: [UInt32: Template] = [:]
        var balance: Int64?

        do {
            guard try reader.readUInt32() == bsiiSignature else { return nil }
            let version = try reader.readUInt32()
            guard (1...3).contains(version) else { return nil }

            while reader.remaining >= 4 {
                let blockType = try reader.readUInt32()

                if blockType == 0 {
                    let valid = try reader.readUInt8() != 0
                    if !valid { continue }

                    let structureID = try reader.readUInt32()
                    let name = try reader.readString()
                    var fields: [Field] = []

                    while true {
                        let type = try reader.readUInt32()
                        if type == 0 { break }

                        let fieldName = try reader.readString()
                        if type == 55 {
                            // Ordinal string declarations carry their value list
                            // in the template, before any instance data.
                            let count = Int(try reader.readUInt32())
                            for _ in 0..<count {
                                try reader.skip(4)
                                _ = try reader.readString()
                            }
                        }
                        fields.append(Field(name: fieldName, type: type))
                    }

                    if templates[structureID] == nil {
                        templates[structureID] = Template(name: name, fields: fields)
                    }
                } else {
                    guard let template = templates[blockType] else { return nil }
                    try reader.skipIdentifier()

                    for field in template.fields {
                        if template.name == "bank", field.name == "money_account" {
                            switch field.type {
                            case 49:
                                balance = Int64(bitPattern: try reader.readUInt64())
                            case 51:
                                balance = Int64(bitPattern: try reader.readUInt64())
                            default:
                                try reader.skipField(type: field.type, version: version)
                            }
                        } else {
                            try reader.skipField(type: field.type, version: version)
                        }
                    }
                }
            }
        } catch {
            return nil
        }

        return balance
    }
}
