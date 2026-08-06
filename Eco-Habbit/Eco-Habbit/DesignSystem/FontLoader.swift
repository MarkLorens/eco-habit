import CoreText
import UIKit

/// `UIAppFonts` covers the normal case, but a synchronized-folder build can copy the
/// TTFs into a subdirectory of the bundle where that lookup misses. Registering every
/// bundled font at launch makes `Font.custom("Caprasimo", …)` resolve either way.
enum FontLoader {
    static func registerBundledFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])

        for url in Set(urls) {
            // Already-registered fonts fail here; that's the expected no-op.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        #if DEBUG
        let missing = [Theme.F.headingName, Theme.F.bodyName]
            .filter { UIFont(name: $0, size: 12) == nil }
        if !missing.isEmpty {
            print("[EcoHabit] Fonts unavailable, falling back to system: \(missing)")
        }
        #endif
    }
}
