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

    @Test func legacyPayloadUsesControlPresentation() throws {
        let payload = try decodePayload()

        #expect(payload.items.count == 1)
        #expect(WidgetPresentation(payload: payload.presentation) == .control)
    }

    @Test func validPresentationOverridesFullColorSurfaces() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 1,
          "template": "standard-v1",
          "fullColor": {
            "primarySurface": "#14213D",
            "secondarySurface": "#261447"
          }
        }
        """)
        let presentation = WidgetPresentation(payload: payload.presentation)

        #expect(presentation.template == .standardV1)
        #expect(presentation.fullColor.primarySurface == WidgetSRGBColor(hex: "#14213D"))
        #expect(presentation.fullColor.secondarySurface == WidgetSRGBColor(hex: "#261447"))
    }

    @Test func systemTemplateIsSelectable() throws {
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

        #expect(WidgetPresentation(payload: payload.presentation).template == .systemV1)
    }

    @Test func malformedPresentationFieldsDegradeIndependently() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 1,
          "template": 42,
          "fullColor": {
            "primarySurface": "navy",
            "secondarySurface": "#123456"
          }
        }
        """)
        let presentation = WidgetPresentation(payload: payload.presentation)

        #expect(payload.items.count == 1)
        #expect(presentation.template == .standardV1)
        #expect(presentation.fullColor.primarySurface == .black)
        #expect(presentation.fullColor.secondarySurface == WidgetSRGBColor(hex: "#123456"))
    }

    @Test func malformedPresentationEnvelopeDoesNotDiscardItems() throws {
        let payload = try decodePayload(presentation: "\"not-an-object\"")

        #expect(payload.items.count == 1)
        #expect(payload.presentation == nil)
        #expect(WidgetPresentation(payload: payload.presentation) == .control)
    }

    @Test func unknownTemplateUsesStandardTemplateAndValidPalette() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 1,
          "template": "future-v2",
          "fullColor": {
            "primarySurface": "#14213D",
            "secondarySurface": "#261447"
          }
        }
        """)
        let presentation = WidgetPresentation(payload: payload.presentation)

        #expect(presentation.template == .standardV1)
        #expect(presentation.fullColor.primarySurface == WidgetSRGBColor(hex: "#14213D"))
        #expect(presentation.fullColor.secondarySurface == WidgetSRGBColor(hex: "#261447"))
    }

    @Test func unsupportedPresentationVersionUsesControlPresentation() throws {
        let payload = try decodePayload(presentation: """
        {
          "version": 2,
          "template": "standard-v1",
          "fullColor": {
            "primarySurface": "#14213D",
            "secondarySurface": "#261447"
          }
        }
        """)

        #expect(WidgetPresentation(payload: payload.presentation) == .control)
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
