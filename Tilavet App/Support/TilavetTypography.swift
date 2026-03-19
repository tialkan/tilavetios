import CoreText
import SwiftUI

enum AppFontRegistrar {
    private static var hasRegistered = false
    private static let bundledFonts = [
        "AmiriQuran.ttf"
    ]

    static func registerBundledFonts(bundle: Bundle = .main) {
        guard !hasRegistered else { return }

        for fileName in bundledFonts {
            let candidates = fontURLs(for: fileName, bundle: bundle)
            for url in candidates {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }

        hasRegistered = true
    }

    private static func fontURLs(for fileName: String, bundle: Bundle) -> [URL] {
        let nsName = fileName as NSString
        let baseName = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        return [
            bundle.url(forResource: baseName, withExtension: ext),
            bundle.url(forResource: baseName, withExtension: ext, subdirectory: "Resources/Fonts"),
            bundle.url(forResource: fileName, withExtension: nil),
            bundle.resourceURL?.appendingPathComponent(fileName)
        ]
        .compactMap { $0 }
    }
}

extension Font {
    static func tilavetQuran(size: CGFloat) -> Font {
        .custom("AmiriQuran-Regular", size: size)
    }
}
