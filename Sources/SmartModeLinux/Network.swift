import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// GTK owns the main thread and never drains the Dispatch main queue, so networking uses plain
/// completion handlers and hops back to the GTK thread with `onMain`.
func fetch(_ url: URL, _ completion: @escaping (Data?) -> Void) {
    var request = URLRequest(url: url, timeoutInterval: 15)
    request.setValue("SmartMode", forHTTPHeaderField: "User-Agent")
    URLSession.shared.dataTask(with: request) { data, response, _ in
        let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
        onMain { completion(ok ? data : nil) }
    }.resume()
}
