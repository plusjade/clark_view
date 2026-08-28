//
//  PairingClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// The one network write the app makes: redeeming a helper-issued code against
/// this install's device id (`POST /pair`).
enum PairingClient {
    enum Outcome {
        case paired(configID: String)
        case invalidOrExpiredCode
        case networkError
    }

    private struct PairResponse: Decodable {
        let ok: Bool
        let configId: String?
    }

    static func pair(code: String, device: String) async -> Outcome {
        var request = URLRequest(url: GameDataURL.baseURL.appendingPathComponent("pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["code": code, "device": device])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse else {
            return .networkError
        }
        guard httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(PairResponse.self, from: data),
              decoded.ok, let configID = decoded.configId else {
            return httpResponse.statusCode == 404 ? .invalidOrExpiredCode : .networkError
        }
        return .paired(configID: configID)
    }
}
