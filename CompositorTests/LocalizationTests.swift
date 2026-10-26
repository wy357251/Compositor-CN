import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Compositor

/// The String Catalog and the dialogs it fills, both checked inside the app host.
///
/// Two failures a green suite used to hide: a translation whose bare `%` the format routine eats, and a `%@` handed
/// an `Int`, which ends the process — Canvas Size and Image Size both crashed on opening while every other test passed.
/// Whether the app host resolved Chinese. CI's runners are English, and only the two tests that ask the running app
/// what it shows depend on it; the table checks read a named localization and hold either way.
private let hostSpeaksChinese = localizedString("Exposure") != "Exposure"

@MainActor
struct LocalizationTests {
    /// A compiled table, read by localization rather than by the interface language, so the checks say the same thing
    /// whatever language the host happens to resolve.
    private func table(_ localization: String) throws -> [String: String] {
        let url = try #require(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                               subdirectory: nil, localization: localization))
        let plist = try PropertyListSerialization.propertyList(from: try Data(contentsOf: url), options: [], format: nil)
        let entries = try #require(plist as? [String: String], "\(localization) table isn't key/value strings")
        #expect(!entries.isEmpty)
        return entries
    }

    /// The conversions a format string will consume, `%%` left out because it stands for the sign itself. Anything
    /// else after a `%` counts as one: a translation that means 100% but writes `%` swallows the next character
    /// instead, and `%d` never survives this app's `localized(_:)`, which stringifies every argument to `NSString`.
    private func conversions(_ text: String) -> [String] {
        var found: [String] = []
        var rest = Substring(text[...])
        while let mark = rest.firstIndex(of: "%") {
            rest = rest[rest.index(after: mark)...]
            guard let sign = rest.first else { found.append("%<end>"); break }
            rest = rest[rest.index(after: rest.startIndex)...]
            found.append(sign == "%" ? "" : sign == "@" ? "%@" : "%\(sign)")
        }
        return found.filter { !$0.isEmpty }
    }

    @Test func translatedFormatStringsTakeTheArgumentsTheirKeysDo() throws {
        // Only a key with a `%@` is handed to `String(format:)` — `localized(_:)` is the sole caller and this app's
        // keys are all `%@`. A plain `%` elsewhere (100%, 300%) is text SwiftUI or AppKit shows as written, so it
        // isn't a conversion and must not be held to one.
        let english = try table("en")
        for (key, value) in try table("zh-Hans").sorted(by: { $0.key < $1.key }) {
            guard let source = english[key] else { Issue.record("\(key) isn't in the English table"); continue }
            #expect(!value.isEmpty, "\(key) translates to nothing")
            guard conversions(source).contains("%@") else {
                #expect(!conversions(value).contains("%@"), "\(key) → \(value) invents a placeholder the key doesn't have")
                continue
            }
            #expect(conversions(source) == conversions(value), "\(key) → \(value): \(conversions(source)) ≠ \(conversions(value))")
            #expect(conversions(value).allSatisfy { $0 == "%@" }, "\(key) → \(value) uses a conversion NSString can't fill")
        }
    }

    @Test func theConversionCheckIsNotBlind() {
        // A negative control for the test above: the mistakes it exists to catch do get caught.
        #expect(conversions("At 100%% each pixel") == [], "an escaped percent read as a conversion")
        #expect(conversions("在 100% 时每像素") == ["% "])
        #expect(conversions("Current: %@ × %@ pixels") == ["%@", "%@"])
        #expect(conversions("%@ of %@.") != conversions("%@的"), "a translation that dropped a conversion")
        #expect(conversions("缩小到 %d") == ["%d"], "a conversion NSString arguments don't satisfy")
    }

    @Test func everyFormatTranslationAppliesWithTheArgumentsTheAppPasses() throws {
        // What `localized(_:)` does: every argument becomes an `NSString`, because `%@` handed an `Int` crashes.
        // Filling each translated format string that way is what opening the dialog does.
        let english = try table("en")
        for (key, value) in try table("zh-Hans").sorted(by: { $0.key < $1.key }) where conversions(english[key] ?? "").contains("%@") {
            let filled = String(format: value, arguments: Array(repeating: "7" as NSString, count: conversions(value).count))
            #expect(!filled.contains("%@"), "\(key) → \(value) left a conversion unfilled")
        }
    }

    @Test(.enabled(if: hostSpeaksChinese)) func theInterpolatedDialogLinesHoldTheirNumbers() {
        // Canvas Size's and Image Size's lines, with the `Int` arguments they really take.
        #expect(localized("Current: %@ × %@ pixels", 400, 300).contains("400"))
        #expect(localized("New: %@ × %@ pixels · %@ uncompressed", 800, 600, "1.83 MB").contains("800"))
        #expect(localized("Final dimensions must be 1–%@ pixels per side.", 30_000).contains("30"))
        #expect(localized("%@ uncompressed RGBA canvas", "1.83 MB").contains("1.83"))
        #expect(localized("%@ of %@.", localizedString("Hue"), localizedString("Reds")).count > 2)
        #expect(localized("%@. Double-click to reset.", localizedString("Exposure")).count > 2)
    }

    @Test(.enabled(if: hostSpeaksChinese)) func labelsThatReachTheUIThroughAVariableAreTranslated() {
        // Neither `Text(aString)` nor `.help(aString)` nor AppKit's `toolTip` looks anything up, so these all ride on
        // a lookup made on the way in: Canvas Size's anchor grid, and the slider titles and tips a sheet's own
        // helper takes as a `String` argument.
        for key in ["Top left", "Top center", "Top right", "Middle left", "Center", "Middle right",
                    "Bottom left", "Bottom center", "Bottom right", "Selected",
                    "Exposure", "Contrast", "Temperature", "Saturation", "Luminance", "Vibrance", "Clarity", "Dehaze",
                    "Texture", "Size", "Opacity", "Distance", "Angle", "Blur", "Gamma", "Reds", "Blues",
                    "Input black", "Output white", "Width", "Height", "Expand", "Contract",
                    "Whites", "Blacks", "Highlights", "Shadows", "Masking", "Midpoint", "Roundness"] {
            #expect(localizedString(key) != key, "\(key) is still English")
        }
    }

    /// Laid out in a hosting view the way the sheet is: the body runs, so a line that crashes, crashes here.
    private func render(_ root: some View, _ what: String) {
        let view = NSHostingView(rootView: root)
        view.frame = CGRect(origin: .zero, size: view.fittingSize)
        view.layoutSubtreeIfNeeded()
        #expect(view.bounds.width > 1 && view.bounds.height > 1, "\(what) laid out nothing")
    }

    private func session() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 40, height: 30)
        let image = try #require(CGImage(width: 40, height: 30, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 40 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: CGDataProvider(data: Data(repeating: 200, count: 40 * 30 * 4) as CFData)!,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Flat"))
        return session
    }

    @Test func canvasSizeSheetLaysOut() throws {
        let session = try session()
        render(CanvasSizeSheet(document: try #require(session.document), session: session) { _ in }, "Canvas Size")
    }

    @Test func imageSizeSheetLaysOut() throws {
        let session = try session()
        render(ImageSizeSheet(document: try #require(session.document)) { _ in }, "Image Size")
    }

    @Test func newCanvasSheetLaysOut() throws {
        render(NewCanvasSheet(session: try session()), "New Canvas")
    }

    @Test func exportAsSheetLaysOutInEveryFormat() async throws {
        let session = try session()
        let snapshot = try #require(session.projectSnapshot())
        let raster = try await ImageExporter.shared.render(snapshot)
        for format in ExportFormat.allCases {
            // GIF and Channel Pack read the document's layers, EXR needs half floats: the sheet lists only what it has,
            // so each one is opened to reach the lines the others don't draw.
            render(ExportAsSheet(raster: raster, snapshot: snapshot, session: session, format: format) { _ in },
                   "Export As (\(format.rawValue))")
        }
    }

    @Test func filterSheetsLayOut() throws {
        let session = try session()
        for kind in FilterKind.allCases {
            session.beginFilter(kind)
            render(FilterSheet(session: session), "Filter (\(kind.rawValue))")
            session.cancelFilter()
        }
    }

    @Test func effectSheetsLayOut() throws {
        let session = try session()
        for kind in LayerEffectKind.allCases {
            render(EffectsSheet(session: session, kind: kind), "Layer Effect (\(kind.rawValue))")
        }
    }

    @Test func adjustmentSheetsLayOut() throws {
        let session = try session()
        session.beginLevels()
        render(LevelsSheet(session: session), "Levels")
        session.cancelLevels()
        session.beginHueSaturation()
        render(HueSaturationSheet(session: session), "Hue/Saturation")
        session.cancelHueSaturation()
    }
}
