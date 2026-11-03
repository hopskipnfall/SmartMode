import CGtk

/// Closures cross into C as a retained box handed back as user data.
private final class Box {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

/// Runs `work` on the GTK main thread. Safe to call from any thread.
func onMain(_ work: @escaping () -> Void) {
    let data = Unmanaged.passRetained(Box(work)).toOpaque()
    g_idle_add({ data in
        Unmanaged<Box>.fromOpaque(data!).takeRetainedValue().run()
        return 0
    }, data)
}

/// Calls `work` every `seconds` for the life of the process.
func every(seconds: UInt32, _ work: @escaping () -> Void) {
    let data = Unmanaged.passRetained(Box(work)).toOpaque()
    g_timeout_add_seconds(seconds, { data in
        Unmanaged<Box>.fromOpaque(data!).takeUnretainedValue().run()
        return 1
    }, data)
}

/// Connects a no-argument signal ("activate", "clicked", "toggled", ...).
func connect<T>(_ object: UnsafeMutablePointer<T>?, _ signal: String, _ work: @escaping () -> Void) {
    let data = Unmanaged.passRetained(Box(work)).toOpaque()
    let callback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = { _, data in
        Unmanaged<Box>.fromOpaque(data!).takeUnretainedValue().run()
    }
    g_signal_connect_data(object, signal, unsafeBitCast(callback, to: GCallback.self), data, nil, GConnectFlags(rawValue: 0))
}

func widget<T>(_ pointer: UnsafeMutablePointer<T>?) -> UnsafeMutablePointer<GtkWidget>? {
    pointer.map { UnsafeMutableRawPointer($0).assumingMemoryBound(to: GtkWidget.self) }
}
