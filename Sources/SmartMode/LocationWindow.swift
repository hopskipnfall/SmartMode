import AppKit
import SwiftUI
import SmartModeCore

@MainActor
final class LocationSearchModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Place] = []
    @Published var isSearching = false
    @Published var message: String?

    private var searchID = 0

    func reset() {
        query = ""
        results = []
        message = nil
        isSearching = false
        searchID += 1
    }

    func run() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searchID += 1
        let id = searchID
        isSearching = true
        message = nil
        Task {
            let outcome = await PlaceSearch.search(text)
            guard id == searchID else { return }   // a newer search superseded this one
            isSearching = false
            results = outcome.places
            if outcome.failed {
                message = "Couldn't search. Check your internet connection, or type coordinates like 35.69, 139.69."
            } else if outcome.places.isEmpty {
                message = "No places found. Try a nearby city, or type coordinates like 35.69, 139.69."
            }
        }
    }
}

struct LocationSearchView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var search: LocationSearchModel
    let pick: (Place) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where are you?").font(.headline)
            Text("Search for a city or place in any language, or type coordinates such as 35.69, 139.69.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                TextField("City, place, or coordinates", text: $search.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { search.run() }
                Button("Search") { search.run() }
                    .disabled(search.isSearching)
            }

            if model.locationSetInConfig {
                Text("latitude/longitude in config.yaml currently override this. Remove those two lines to use the place you pick here.")
                    .font(.callout).foregroundStyle(.orange)
            }

            if search.isSearching {
                ProgressView().controlSize(.small)
            } else if let message = search.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            List(search.results) { place in
                Button {
                    pick(place)
                } label: {
                    HStack {
                        Text(place.label)
                        Spacer()
                        Text(String(format: "%.2f, %.2f", place.latitude, place.longitude))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 120)

            Text("Current: \(model.locationLabel ?? "not set")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 440, height: 380)
    }
}

/// A plain AppKit window, because a menu-bar-only app has no window scene to open.
@MainActor
final class LocationWindowController {
    static let shared = LocationWindowController()

    private var window: NSWindow?
    private let search = LocationSearchModel()

    func show(model: AppModel) {
        if window == nil {
            let view = LocationSearchView(model: model, search: search) { [weak self] place in
                model.choose(place)
                self?.window?.close()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Set Location"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        search.reset()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
