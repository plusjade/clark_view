//
//  PairingClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

private struct PairResponse: Decodable {
    let succeeded: Bool

    private enum CodingKeys: String, CodingKey {
        case succeeded = "ok"
    }
}

/// The one network write the app makes: redeeming a bunch-issued code to register
/// this install as a device (`POST /pair`).
enum PairingClient {
    enum Outcome {
        case paired
        case invalidOrExpiredCode
        case networkError
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
              decoded.succeeded else {
            // 404: no such code. 422: code exists but has expired — the server
            // distinguishes them server-side, but the app shows the same copy either way.
            let invalidCode = httpResponse.statusCode == 404 || httpResponse.statusCode == 422
            return invalidCode ? .invalidOrExpiredCode : .networkError
        }
        return .paired
    }
}
