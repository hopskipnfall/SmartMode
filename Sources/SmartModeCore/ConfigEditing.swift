import Foundation

/// Returns `text` with the `location:` section set to `place`, changing nothing else, so the
/// user's comments and other settings survive. Empty values in the section are filled in, an
/// existing section's values are replaced and missing keys added, and a file with no section
/// gets one at the top.
public func configText(_ text: String, settingLocationTo place: Place) -> String {
    let coordinates = String(format: "%.4f, %.4f", place.latitude, place.longitude)
    // A typed coordinate pair has no name worth saving.
    let name = place.label == coordinates ? "" : yamlQuoted(place.label)
    let values: [(key: String, value: String)] = [
        ("locationName", name),
        ("latitude", String(format: "%.4f", place.latitude)),
        ("longitude", String(format: "%.4f", place.longitude)),
    ]
    func line(_ indent: String, _ key: String, _ value: String) -> String {
        indent + key + ":" + (value.isEmpty ? "" : " " + value)
    }

    var lines = text.components(separatedBy: "\n")
    guard let header = lines.firstIndex(where: isLocationHeader) else {
        let section = ["location:"] + values.map { line("  ", $0.key, $0.value) }
        return (section + [""] + lines).joined(separator: "\n")
    }

    // The section runs while lines are blank or indented; trailing blanks aren't part of it.
    var last = header
    var index = header + 1
    while index < lines.count {
        let current = lines[index]
        if current.trimmingCharacters(in: .whitespaces).isEmpty { index += 1; continue }
        guard current.first == " " || current.first == "\t" else { break }
        last = index
        index += 1
    }
    let indent = lines[(header + 1)...max(header + 1, last)].first { $0.first == " " || $0.first == "\t" }
        .map { String($0.prefix { $0 == " " || $0 == "\t" }) } ?? "  "

    for (key, value) in values {
        let replacement = line(indent, key, value)
        if let existing = lines.indices.first(where: { $0 > header && $0 <= last && isKeyLine(lines[$0], key) }) {
            lines[existing] = replacement
        } else {
            lines.insert(replacement, at: last + 1)
            last += 1
        }
    }
    return lines.joined(separator: "\n")
}

private func isLocationHeader(_ line: String) -> Bool {
    guard line.hasPrefix("location:") else { return false }
    let rest = line.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)
    return rest.isEmpty || rest.hasPrefix("#")
}

/// An indented, uncommented `key:` line.
private func isKeyLine(_ line: String, _ key: String) -> Bool {
    guard line.first == " " || line.first == "\t" else { return false }
    return line.drop(while: { $0 == " " || $0 == "\t" }).hasPrefix(key + ":")
}

private func yamlQuoted(_ s: String) -> String {
    let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: " ")
    return "\"" + escaped + "\""
}
