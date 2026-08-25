import Foundation

/// Reads and writes the accepted-output file. A missing file is not an error:
/// the first run on a fresh checkout has nothing to compare against and simply
/// reports every pair as new.
nonisolated enum GoldenStore {

    static func load(from url: URL) -> [String: GoldenRecord] {
        guard let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([GoldenRecord].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0) })
    }

    static func save(_ records: [GoldenRecord], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(records.sorted { $0.key < $1.key })
        data.append(0x0A)  // keep the file newline-terminated for git
        try data.write(to: url)
    }
}
