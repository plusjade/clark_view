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
    let fullColor: WidgetFullColorPayload?

    private enum CodingKeys: String, CodingKey {
        case version
        case template
        case fullColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try? container.decode(Int.self, forKey: .version)
        template = try? container.decode(String.self, forKey: .template)
        fullColor = try? container.decode(WidgetFullColorPayload.self, forKey: .fullColor)
    }
}

struct WidgetFullColorPayload: Decodable {
    let primarySurface: String?
    let secondarySurface: String?

    private enum CodingKeys: String, CodingKey {
        case primarySurface
        case secondarySurface
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primarySurface = try? container.decode(String.self, forKey: .primarySurface)
        secondarySurface = try? container.decode(String.self, forKey: .secondarySurface)
    }
}

/// The presentation values the native renderer is prepared to honor. This deliberately uses
/// sRGB components rather than SwiftUI colors so wire validation stays independent of the view
/// framework and can be unit tested by the containing app.
struct WidgetPresentation: Equatable {
    enum Template: String, Equatable {
        case standardV1 = "standard-v1"
    }

    struct FullColorPalette: Equatable {
        let primarySurface: WidgetSRGBColor
        let secondarySurface: WidgetSRGBColor
    }

    static let control = WidgetPresentation(
        template: .standardV1,
        fullColor: FullColorPalette(primarySurface: .black, secondarySurface: .black)
    )

    let template: Template
    let fullColor: FullColorPalette

    init(payload: WidgetPresentationPayload?) {
        guard let payload, payload.version == 1 else {
            self = .control
            return
        }

        template = payload.template.flatMap(Template.init(rawValue:)) ?? Self.control.template
        fullColor = FullColorPalette(
            primarySurface: payload.fullColor?.primarySurface.flatMap(WidgetSRGBColor.init(hex:))
                ?? Self.control.fullColor.primarySurface,
            secondarySurface: payload.fullColor?.secondarySurface.flatMap(WidgetSRGBColor.init(hex:))
                ?? Self.control.fullColor.secondarySurface
        )
    }

    private init(template: Template, fullColor: FullColorPalette) {
        self.template = template
        self.fullColor = fullColor
    }
}

/// Opaque six-digit sRGB, matching the `#RRGGBB` presentation contract. Alpha is intentionally
/// unsupported because a translucent server value could make widget contrast depend on an
/// uncontrolled Home Screen background.
struct WidgetSRGBColor: Equatable {
    static let black = WidgetSRGBColor(red: 0, green: 0, blue: 0)

    let red: Double
    let green: Double
    let blue: Double

    init?(hex: String) {
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
