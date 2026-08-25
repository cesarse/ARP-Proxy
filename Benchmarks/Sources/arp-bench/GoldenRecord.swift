import Foundation

/// The accepted output for one fixture-and-dialect pair. The digest is the
/// point: any change to any pass moves it, so a diff in the golden file is the
/// review prompt — "this pass changed 40 KB of CNN, is that what you meant?"
nonisolated struct GoldenRecord: Codable, Sendable, Equatable {
    let fixture: String
    let dialect: String
    let outputBytes: Int
    let outputSHA256: String

    var key: String { "\(fixture)/\(dialect)" }

    init(fixture: String, dialect: String, outputBytes: Int, outputSHA256: String) {
        self.fixture = fixture
        self.dialect = dialect
        self.outputBytes = outputBytes
        self.outputSHA256 = outputSHA256
    }

    init(_ measurement: Measurement) {
        self.init(fixture: measurement.fixture,
                  dialect: measurement.version.rawValue,
                  outputBytes: measurement.outputBytes,
                  outputSHA256: measurement.outputSHA256)
    }
}
