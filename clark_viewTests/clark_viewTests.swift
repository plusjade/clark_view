//
//  clark_viewTests.swift
//  clark_viewTests
//
//  Created by Jade Dominguez on 8/18/26.
//

import Foundation
import Testing
@testable import clark_view

@MainActor
struct clark_viewTests {

    @Test func presentationlessPayloadUsesDefaultBeaconPresentation() throws {
        let payload = try decodePayload()

        #expect(payload.items.count == 1)
        #expect(WidgetPresentation(payload: payload.presentation) == .defaultPresentation)
    }

    @Test func validPresentationOverridesRootSurfaces() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 2,
          "template": "beacon",
          "rootSurface": {
            "light": "#14213D",
            "dark": "#261447"
          }
        }
        """)
        let presentation = WidgetPresentation(payload: payload.presentation)

        #expect(presentation.template == .beacon)
        #expect(presentation.rootSurface.light == WidgetSRGBColor(hex: "#14213D"))
        #expect(presentation.rootSurface.dark == WidgetSRGBColor(hex: "#261447"))
    }

    @Test func beaconTemplateIsSelectable() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 2,
          "template": "beacon",
          "rootSurface": {
            "light": "#14213D",
            "dark": "#261447"
          }
        }
        """)

        #expect(WidgetPresentation(payload: payload.presentation).template == .beacon)
    }

    @Test func malformedPresentationFieldsDegradeIndependently() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 2,
          "template": 42,
          "rootSurface": {
            "light": "navy",
            "dark": "#123456"
          }
        }
        """)
        let presentation = WidgetPresentation(payload: payload.presentation)

        #expect(payload.items.count == 1)
        #expect(presentation.template == .beacon)
        #expect(presentation.rootSurface.light == .white)
        #expect(presentation.rootSurface.dark == WidgetSRGBColor(hex: "#123456"))
    }

    @Test func malformedPresentationEnvelopeDoesNotDiscardItems() throws {
        let payload = try decodePayload(presentation: "\"not-an-object\"")

        #expect(payload.items.count == 1)
        #expect(payload.presentation == nil)
        #expect(WidgetPresentation(payload: payload.presentation) == .defaultPresentation)
    }

    @Test func unknownTemplateUsesBeaconAndValidPalette() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 2,
          "template": "future-v2",
          "rootSurface": {
            "light": "#14213D",
            "dark": "#261447"
          }
        }
        """)
        let presentation = WidgetPresentation(payload: payload.presentation)

        #expect(presentation.template == .beacon)
        #expect(presentation.rootSurface.light == WidgetSRGBColor(hex: "#14213D"))
        #expect(presentation.rootSurface.dark == WidgetSRGBColor(hex: "#261447"))
    }

    @Test func unsupportedPresentationVersionUsesDefaultBeaconPresentation() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 3,
          "template": "beacon",
          "rootSurface": {
            "light": "#14213D",
            "dark": "#261447"
          }
        }
        """)

        #expect(WidgetPresentation(payload: payload.presentation) == .defaultPresentation)
    }

    @Test func legacyFullColorPresentationUsesDefaultBeaconPresentation() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 1,
          "template": "system-v1",
          "fullColor": {
            "primarySurface": "#14213D",
            "secondarySurface": "#261447"
          }
        }
        """)
        #expect(WidgetPresentation(payload: payload.presentation) == .defaultPresentation)
    }

    @Test func widgetRefreshDiagnosticsDescribeLatestOutcome() {
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)

        let inProgress = WidgetRefreshDiagnosticSnapshot(
            lastRequestedAt: first,
            lastAttemptedAt: second,
            lastSucceededAt: first,
            lastFailedAt: nil,
            lastError: nil
        )
        #expect(inProgress.resultDescription == "In progress")

        let failure = WidgetRefreshDiagnosticSnapshot(
            lastRequestedAt: first,
            lastAttemptedAt: second,
            lastSucceededAt: first,
            lastFailedAt: second,
            lastError: "Offline"
        )
        #expect(failure.resultDescription == "Failed: Offline")

        let success = WidgetRefreshDiagnosticSnapshot(
            lastRequestedAt: first,
            lastAttemptedAt: second,
            lastSucceededAt: second,
            lastFailedAt: first,
            lastError: nil
        )
        #expect(success.resultDescription == "Succeeded")
    }

    private func decodePayload(presentation: String? = nil) throws -> WidgetPayload {
        let presentationField = presentation.map { "\"presentation\": \($0)," } ?? ""
        let data = Data("""
        {
          "schemaVersion": 2,
          \(presentationField)
          "items": [
            {
              "id": "1",
              "mainText": "Fever @ Wings",
              "subText": "ESPN",
              "caption": null,
              "emphasized": false,
              "timestamp": 1788044400
            }
          ]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetPayload.self, from: data)
    }
}
