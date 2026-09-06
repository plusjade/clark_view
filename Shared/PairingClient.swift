//
//  PairingClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation
import OSLog

private struct PairResponse: Decodable {
    let succeeded: Bool

    private enum CodingKeys: String, CodingKey {
        case succeeded = "ok"
    }
}

/// The one network write the app makes: redeeming a bunch-issued code to register
/// this install as a device (`POST /pair`).
enum PairingClient {
    private static let logger = Logger(subsystem: "plusjade.clark-view", category: "Pairing")

    enum Outcome: Equatable {
        case paired
        case invalidOrExpiredCode
        case networkError
        case serverError(statusCode: Int)
        case invalidResponse
    }

    static func pair(code: String, device: String) async -> Outcome {
        var request = URLRequest(url: GameDataURL.baseURL.appendingPathComponent("pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["code": code, "device": device])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                logger.error("POST /pair returned a non-HTTP response")
                return .invalidResponse
            }
            return interpret(data: data, statusCode: response.statusCode)
        } catch {
            let failure = error as NSError
            logger.error("POST /pair transport failure: \(failure.domain, privacy: .public) code=\(failure.code)")
            return .networkError
        }
    }

    static func interpret(data: Data, statusCode: Int) -> Outcome {
        if statusCode == 404 || statusCode == 422 {
            logger.notice("POST /pair rejected code: HTTP \(statusCode)")
            return .invalidOrExpiredCode
        }
        guard statusCode == 200 else {
            logger.error("POST /pair failed: HTTP \(statusCode)")
            return .serverError(statusCode: statusCode)
        }
        do {
            let decoded = try JSONDecoder().decode(PairResponse.self, from: data)
            guard decoded.succeeded else {
                logger.error("POST /pair HTTP 200 returned ok=false")
                return .invalidResponse
            }
            return .paired
        } catch {
            // Response bodies may contain identifiers; log only the failure category.
            logger.error("POST /pair HTTP 200 could not decode the success response")
            return .invalidResponse
        }
    }
}
