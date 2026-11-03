import CGtk
import Foundation
import SmartModeCore

/// Search for a place by name or type coordinates; click a result to use it.
final class LocationWindow {
    private let model: AppModel
    private var window: UnsafeMutablePointer<GtkWidget>?
    private var entry: UnsafeMutablePointer<GtkWidget>?
    private var message: UnsafeMutablePointer<GtkWidget>?
    private var results: UnsafeMutablePointer<GtkWidget>?
    private var current: UnsafeMutablePointer<GtkWidget>?
    private var searchID = 0

    init(model: AppModel) { self.model = model }

    func show() {
        if window == nil { build() }
        gtk_entry_set_text(UnsafeMutableRawPointer(entry!).assumingMemoryBound(to: GtkEntry.self), "")
        setMessage(nil)
        clearResults()
        gtk_label_set_text(UnsafeMutableRawPointer(current!).assumingMemoryBound(to: GtkLabel.self),
                           "Current: \(model.locationLabel ?? "not set")")
        gtk_widget_show_all(window)
        gtk_window_present(UnsafeMutableRawPointer(window!).assumingMemoryBound(to: GtkWindow.self))
        gtk_widget_grab_focus(entry)
    }

    private func build() {
        let win = gtk_window_new(GTK_WINDOW_TOPLEVEL)!
        let gtkWindow = UnsafeMutableRawPointer(win).assumingMemoryBound(to: GtkWindow.self)
        gtk_window_set_title(gtkWindow, "Set Location")
        gtk_window_set_default_size(gtkWindow, 440, 380)
        gtk_window_set_position(gtkWindow, GTK_WIN_POS_CENTER)
        gtk_container_set_border_width(UnsafeMutableRawPointer(win).assumingMemoryBound(to: GtkContainer.self), 16)
        // Closing hides the window so it can be shown again.
        let hideOnDelete: @convention(c) (UnsafeMutablePointer<GtkWidget>?, UnsafeMutablePointer<GdkEvent>?, gpointer?) -> gboolean = { w, _, _ in
            gtk_widget_hide(w); return 1
        }
        g_signal_connect_data(win, "delete-event", unsafeBitCast(hideOnDelete, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))

        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10)!
        func boxAdd(_ child: UnsafeMutablePointer<GtkWidget>?, expand: Bool = false) {
            gtk_box_pack_start(UnsafeMutableRawPointer(box).assumingMemoryBound(to: GtkBox.self), child, expand ? 1 : 0, expand ? 1 : 0, 0)
        }
        func label(_ text: String) -> UnsafeMutablePointer<GtkWidget> {
            let l = gtk_label_new(text)!
            gtk_label_set_xalign(UnsafeMutableRawPointer(l).assumingMemoryBound(to: GtkLabel.self), 0)
            gtk_label_set_line_wrap(UnsafeMutableRawPointer(l).assumingMemoryBound(to: GtkLabel.self), 1)
            return l
        }

        boxAdd(label("Where are you?"))
        boxAdd(label("Search for a city or place, or type coordinates such as 35.69, 139.69."))

        let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        entry = gtk_entry_new()
        let searchButton = gtk_button_new_with_label("Search")!
        gtk_box_pack_start(UnsafeMutableRawPointer(row).assumingMemoryBound(to: GtkBox.self), entry, 1, 1, 0)
        gtk_box_pack_start(UnsafeMutableRawPointer(row).assumingMemoryBound(to: GtkBox.self), searchButton, 0, 0, 0)
        boxAdd(row)
        connect(entry, "activate") { [self] in search() }
        connect(searchButton, "clicked") { [self] in search() }

        message = label("")
        boxAdd(message)

        let scroll = gtk_scrolled_window_new(nil, nil)!
        results = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)
        gtk_container_add(UnsafeMutableRawPointer(scroll).assumingMemoryBound(to: GtkContainer.self), results)
        boxAdd(scroll, expand: true)

        current = label("")
        boxAdd(current)

        gtk_container_add(UnsafeMutableRawPointer(win).assumingMemoryBound(to: GtkContainer.self), box)
        window = win
    }

    private func setMessage(_ text: String?) {
        gtk_label_set_text(UnsafeMutableRawPointer(message!).assumingMemoryBound(to: GtkLabel.self), text ?? "")
    }

    private func clearResults() {
        let container = UnsafeMutableRawPointer(results!).assumingMemoryBound(to: GtkContainer.self)
        var child = gtk_container_get_children(container)
        while let node = child {
            gtk_widget_destroy(node.pointee.data.assumingMemoryBound(to: GtkWidget.self))
            child = node.pointee.next
        }
    }

    private func search() {
        let text = String(cString: gtk_entry_get_text(UnsafeMutableRawPointer(entry!).assumingMemoryBound(to: GtkEntry.self)))
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchID += 1
        let id = searchID
        setMessage("Searching…")
        clearResults()
        model.search(text) { [self] places, failed in
            guard id == searchID else { return }   // a newer search superseded this one
            setMessage(failed ? "Couldn't search. Check your internet connection, or type coordinates like 35.69, 139.69."
                       : places.isEmpty ? "No places found. Try a nearby city, or type coordinates like 35.69, 139.69." : nil)
            for place in places {
                let button = gtk_button_new_with_label("\(place.label)  (\(String(format: "%.2f, %.2f", place.latitude, place.longitude)))")!
                connect(button, "clicked") { [self] in
                    model.choose(place)
                    gtk_widget_hide(window)
                }
                gtk_box_pack_start(UnsafeMutableRawPointer(results!).assumingMemoryBound(to: GtkBox.self), button, 0, 0, 0)
            }
            gtk_widget_show_all(results)
        }
    }
}
