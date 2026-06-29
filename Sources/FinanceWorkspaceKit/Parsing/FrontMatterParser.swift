import Foundation

// T016 — Extract the leading `---`-delimited YAML front-matter block into flat metadata.
// v1 supports flat `key: value` lines plus inline lists (`key: [a, b]`). Missing or malformed
// front matter is handled gracefully (returns nil + the full text as body), never fatal.

public struct FrontMatterParser: Sendable {

    public init() {}

    public func extract(from markdown: String) -> (frontMatter: FrontMatter?, body: String) {
        let lines = markdown.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
            return (nil, markdown)
        }
        // Find the closing delimiter.
        guard let closeIndex = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return (nil, markdown)   // unterminated block → treat as no front matter
        }

        var values: [String: FrontMatterValue] = [:]
        for line in lines[1..<closeIndex] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = parseValue(rawValue)
        }

        let body = lines[(closeIndex + 1)...].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (FrontMatter(values: values), body)
    }

    private func parseValue(_ raw: String) -> FrontMatterValue {
        if raw.hasPrefix("["), raw.hasSuffix("]") {
            let inner = raw.dropFirst().dropLast()
            let items = inner.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                .filter { !$0.isEmpty }
            return .list(items)
        }
        if raw == "true" || raw == "false" { return .bool(raw == "true") }
        if let n = Double(raw) { return .number(n) }
        let unquoted = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return .string(unquoted)
    }
}
