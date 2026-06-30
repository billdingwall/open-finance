import Foundation

// T034 — Read/write Taxes/settings.csv as typed WorkspaceSettings. The file is key/value
// (one setting per row). Missing file → typed defaults. Writes are backed up and atomic
// (FR-017). A UI-facing @Observable wrapper is added with the presentation layer (Phase 5).

public enum FilingStatus: String, Codable, Sendable, CaseIterable {
    case single
    case marriedFilingJointly = "married_filing_jointly"
    case marriedFilingSeparately = "married_filing_separately"
    case headOfHousehold = "head_of_household"
    case qualifyingWidow = "qualifying_widow"
}

public struct WorkspaceSettings: Sendable, Equatable {
    public var filingStatus: FilingStatus
    public var taxYear: Int
    public var defaultCurrency: String
    public var timezone: String

    public init(filingStatus: FilingStatus, taxYear: Int, defaultCurrency: String, timezone: String) {
        self.filingStatus = filingStatus
        self.taxYear = taxYear
        self.defaultCurrency = defaultCurrency
        self.timezone = timezone
    }

    public static func defaults(taxYear: Int = WorkspaceLayout.currentTaxYear()) -> WorkspaceSettings {
        WorkspaceSettings(filingStatus: .single, taxYear: taxYear, defaultCurrency: "USD", timezone: "UTC")
    }
}

public struct SettingsStore: Sendable {

    private static let relativePath = "Taxes/settings.csv"
    private let coordinator: FileCoordinatorService

    public init(coordinator: FileCoordinatorService = FileCoordinatorService()) {
        self.coordinator = coordinator
    }

    /// Read typed settings; returns typed defaults when the file is absent (never throws on missing).
    public func read(workspaceURL: URL) throws -> WorkspaceSettings {
        let url = workspaceURL.appendingPathComponent(Self.relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return .defaults() }
        let text = try coordinator.coordinatedRead(url) { try String(contentsOf: $0, encoding: .utf8) }
        return Self.parse(text)
    }

    /// Write settings back through a backed-up, atomic write.
    public func write(_ settings: WorkspaceSettings, to workspaceURL: URL) throws {
        let url = workspaceURL.appendingPathComponent(Self.relativePath)
        let backups = BackupService(backupsDir: workspaceURL.appendingPathComponent(".finance-meta/backups"))
        try backups.backup(url)
        let content = Self.serialize(settings)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try coordinator.coordinatedWrite(url) { dest in
            try Data(content.utf8).write(to: dest, options: .atomic)
        }
    }

    // MARK: - Serialization (key/value rows)

    static func parse(_ text: String) -> WorkspaceSettings {
        let (body, _) = CSVParserService.stripLeadingComments(text)
        let rows = CSVParserService.tokenize(body)
        var kv: [String: String] = [:]
        for row in rows.dropFirst() where row.count >= 2 {   // dropFirst() skips the key,value header
            kv[row[0].trimmingCharacters(in: .whitespaces)] = row[1].trimmingCharacters(in: .whitespaces)
        }
        let defaults = WorkspaceSettings.defaults()
        return WorkspaceSettings(
            filingStatus: kv["filing_status"].flatMap(FilingStatus.init(rawValue:)) ?? defaults.filingStatus,
            taxYear: kv["tax_year"].flatMap { Int($0) } ?? defaults.taxYear,
            defaultCurrency: kv["default_currency"].flatMap { $0.isEmpty ? nil : $0 } ?? defaults.defaultCurrency,
            timezone: kv["timezone"].flatMap { $0.isEmpty ? nil : $0 } ?? defaults.timezone)
    }

    static func serialize(_ settings: WorkspaceSettings) -> String {
        """
        # schema_version: 1
        key,value
        filing_status,\(settings.filingStatus.rawValue)
        tax_year,\(settings.taxYear)
        default_currency,\(settings.defaultCurrency)
        timezone,\(settings.timezone)

        """
    }
}
