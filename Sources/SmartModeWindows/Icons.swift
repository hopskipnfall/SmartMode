import WinSDK

/// Draws the tray icons in code: a half-filled circle (like the macOS glyph), and a solid amber
/// one while there is no location. Light grey reads on both light and dark taskbars.
enum Icons {
    static let normal = make(color: 0xFFD0_D0D0, halfFilled: true)
    static let warning = make(color: 0xFFF5_A623, halfFilled: false)

    private static func make(color: UInt32, halfFilled: Bool) -> HICON? {
        let size = 32
        var pixels = [UInt32](repeating: 0, count: size * size)   // BGRA, alpha in the top byte
        let center = Double(size - 1) / 2
        for y in 0..<size {
            for x in 0..<size {
                let dx = Double(x) - center, dy = Double(y) - center
                let distance = (dx * dx + dy * dy).squareRoot()
                let ring = distance <= 14.5 && distance >= 12
                let disc = distance < 12
                let leftHalf = Double(x) < center
                if ring || (disc && (!halfFilled || leftHalf)) { pixels[y * size + x] = color }
            }
        }
        let colorBitmap = CreateBitmap(Int32(size), Int32(size), 1, 32, pixels)
        let maskBitmap = CreateBitmap(Int32(size), Int32(size), 1, 1, nil)
        var info = ICONINFO(fIcon: true, xHotspot: 0, yHotspot: 0, hbmMask: maskBitmap, hbmColor: colorBitmap)
        let icon = CreateIconIndirect(&info)
        DeleteObject(colorBitmap)
        DeleteObject(maskBitmap)
        return icon
    }
}
