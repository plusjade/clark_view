//
//  GameSchema.swift
//  Shared
//
//  Created by Jade Dominguez on 8/20/26.
//

import Foundation
import SwiftUI

/// Decoded shape of the `?format=json` response. Mirrors what the server
/// currently rasterizes into the PNG; the widget renders this natively
/// instead of drawing an image on the server.
struct GameSchema: Codable {
    let schemaVersion: Int
    let day: String
    let games: [Game]
}

struct Game: Codable, Identifiable {
    enum Status: String, Codable {
        case scheduled
        case live
        case final
    }

    let id: String
    let status: Status
    let startTime: Date
    let away: TeamScore
    let home: TeamScore
    /// Freeform status text — inning, quarter + clock, "Final/OT", etc.
    /// Sport-specific formatting stays server-side so the client doesn't
    /// need per-sport branching.
    let detail: String?
}

struct TeamScore: Codable {
    let id: String
    let abbreviation: String
    let name: String
    let score: Int?
    let colorHex: String?

    var color: Color {
        guard let colorHex, let value = Int(colorHex.trimmingCharacters(in: .init(charactersIn: "#")), radix: 16) else {
            return .secondary
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
