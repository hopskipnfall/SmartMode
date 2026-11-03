import Foundation

/// The "new bug report" page for the repository, with the issue form's version and macOS fields
/// prefilled. Nothing else (no location, no settings) is put in the link.
public func bugReportURL(version: String, macOS: String) -> URL {
    var components = URLComponents(string: "https://github.com/hopskipnfall/SmartMode/issues/new")!
    components.queryItems = [
        URLQueryItem(name: "template", value: "bug_report.yml"),
        URLQueryItem(name: "version", value: version),
        URLQueryItem(name: "macos", value: macOS),
    ]
    return components.url!
}
