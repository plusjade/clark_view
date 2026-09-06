//
//  WidgetPresentation.swift
//  Shared
//

import Foundation

/// Optional presentation envelope from the widget JSON response. Every field decodes
/// independently so presentation drift cannot turn otherwise-valid feed content into an
/// empty widget.
struct WidgetPresentationPayload: Decodable {
    let version: Int?
    let template: String?
    let rootSurface: WidgetRootSurfacePayload?

    private enum CodingKeys: String, CodingKey {
        case version
        case template
        case rootSurface
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try? container.decode(Int.self, forKey: .version)
        template = try? container.decode(String.self, forKey: .template)
        rootSurface = try? container.decode(WidgetRootSurfacePayload.self, forKey: .rootSurface)
    }
}

struct WidgetRootSurfacePayload: Decodable {
    let light: String?
    let dark: String?

    private enum CodingKeys: String, CodingKey {
        case light
        case dark
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        light = try? container.decode(String.self, forKey: .light)
        dark = try? container.decode(String.self, forKey: .dark)
    }
}

/// The presentation values the native renderer is prepared to honor. This deliberately uses
/// sRGB components rather than SwiftUI colors so wire validation stays independent of the view
/// framework and can be unit tested by the containing app.
struct WidgetPresentation: Equatable {
    enum Template: String, Equatable {
        /// Retained as a rendering reference while the server no longer selects it.
        case standardV1 = "standard-v1"
        case beacon = "beacon"
    }

    struct RootSurfacePalette: Equatable {
        let light: WidgetSRGBColor
        let dark: WidgetSRGBColor
    }

    static let defaultPresentation = WidgetPresentation(
        template: .beacon,
        rootSurface: RootSurfacePalette(light: .white, dark: .black)
    )

    let template: Template
    let rootSurface: RootSurfacePalette

    init(payload: WidgetPresentationPayload?) {
        guard let payload, payload.version == 2 else {
            self = .defaultPresentation
            return
        }

        let resolvedTemplate = payload.template.flatMap(Template.init(rawValue:))
            ?? Self.defaultPresentation.template
        let fallback = resolvedTemplate == .beacon
            ? Self.defaultPresentation.rootSurface
            : RootSurfacePalette(light: .black, dark: .black)
        template = resolvedTemplate
        rootSurface = RootSurfacePalette(
            light: payload.rootSurface?.light.flatMap(WidgetSRGBColor.init(hex:)) ?? fallback.light,
            dark: payload.rootSurface?.dark.flatMap(WidgetSRGBColor.init(hex:)) ?? fallback.dark
        )
    }

    private init(template: Template, rootSurface: RootSurfacePalette) {
        self.template = template
        self.rootSurface = rootSurface
    }
}

/// Opaque six-digit sRGB, matching the `#RRGGBB` presentation contract. Alpha is intentionally
/// unsupported because a translucent server value could make widget contrast depend on an
/// uncontrolled Home Screen background.
struct WidgetSRGBColor: Equatable {
    static let black = WidgetSRGBColor(red: 0, green: 0, blue: 0)
    static let white = WidgetSRGBColor(red: 1, green: 1, blue: 1)

    let red: Double
    let green: Double
    let blue: Double

    nonisolated init?(hex: String) {
        guard hex.count == 7,
              hex.first == "#",
              let value = UInt32(hex.dropFirst(), radix: 16) else {
            return nil
        }

        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    private init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
