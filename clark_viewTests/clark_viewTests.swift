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

    @Test func itemsDecodeTheirWindow() throws {
        let payload = try decodePayload()
        let item = try #require(payload.items.first)

        #expect(item.startsAt == Date(timeIntervalSince1970: 1788044400))
        #expect(item.expiresAt == Date(timeIntervalSince1970: 1788051600))
    }

    /// A build can outlive a server rollback, so the pre-window shape still has to render.
    /// With no expiry the item is instantaneous rather than given an invented duration.
    @Test func legacyTimestampItemStillDecodes() throws {
        let payload = try decodePayload(items: """
        {
          "id": "1", "mainText": "Fever @ Wings", "subText": "ESPN",
          "caption": null, "emphasized": false, "timestamp": 1788044400
        }
        """)
        let item = try #require(payload.items.first)

        #expect(item.startsAt == Date(timeIntervalSince1970: 1788044400))
        #expect(item.expiresAt == Date(timeIntervalSince1970: 1788044401))
    }

    /// The instantaneous case: a one-second window is a real window, and the
    /// refresh lands on its bounds like any other.
    @Test func instantaneousItemSchedulesRefreshOnItsOwnBounds() throws {
        let peak = Date(timeIntervalSince1970: 1788044400)
        let payload = try decodePayload(items: """
        {
          "id": "3:peak", "mainText": "Eclipse Peak", "subText": "Total eclipse",
          "caption": "PEAK", "emphasized": false,
          "startsAt": 1788044400, "expiresAt": 1788044401
        }
        """)
        let item = try #require(payload.items.first)
        #expect(item.expiresAt.timeIntervalSince(item.startsAt) == 1)

        // Far out: the next bound wins, but never past the hourly floor.
        let early = peak.addingTimeInterval(-7200)
        #expect(nextRefreshDate(for: payload, after: early) == early.addingTimeInterval(3600))
        // Inside the last hour: exactly the start.
        let close = peak.addingTimeInterval(-600)
        #expect(nextRefreshDate(for: payload, after: close) == peak)
        // Between the bounds, the expiry is under the one-minute floor, so the floor wins.
        #expect(nextRefreshDate(for: payload, after: peak) == peak.addingTimeInterval(60))
        // Past both bounds there is nothing to wait for but the hourly refresh.
        let after = peak.addingTimeInterval(10)
        #expect(nextRefreshDate(for: payload, after: after) == after.addingTimeInterval(3600))
    }

    /// The state machine: one label set, and each item's own window picks from it.
    @Test func lifecycleLabelFollowsEachItemsOwnWindow() throws {
        let start = Date(timeIntervalSince1970: 1788044400)
        let payload = try decodePayload(
            lifecycle: """
            { "upcoming": null, "current": "LIVE", "expired": "END" }
            """,
            items: """
            {
              "id": "1", "mainText": "Fever @ Wings", "subText": "ESPN",
              "startsAt": 1788044400, "expiresAt": 1788051600
            }
            """
        )
        let item = try #require(payload.items.first)
        let labels = try #require(payload.lifecycle)

        #expect(item.lifecycleLabel(labels, at: start.addingTimeInterval(-1)) == nil)
        #expect(item.lifecycleLabel(labels, at: start) == "LIVE")
        #expect(item.lifecycleLabel(labels, at: item.expiresAt.addingTimeInterval(-1)) == "LIVE")
        // Half-open: the expiry bound itself is already over.
        #expect(item.lifecycleLabel(labels, at: item.expiresAt) == "END")
    }

    /// A build can outlive a server that doesn't send labels yet, and vice versa.
    @Test func lifecycleFallsBackToTheRetiredCaption() throws {
        let payload = try decodePayload(items: """
        {
          "id": "1", "mainText": "Fever @ Wings", "subText": "ESPN",
          "caption": "LIVE", "emphasized": true,
          "startsAt": 1788044400, "expiresAt": 1788051600
        }
        """)
        let item = try #require(payload.items.first)

        #expect(payload.lifecycle == nil)
        // No labels: the server-resolved word is all there is, whatever the clock says.
        #expect(item.lifecycleLabel(nil, at: Date(timeIntervalSince1970: 0)) == "LIVE")
    }

    /// An item with no `caption` and no labels renders its start time, not an empty word.
    @Test func absentLifecycleAndCaptionResolveToNoLabel() throws {
        let payload = try decodePayload()
        let item = try #require(payload.items.first)

        #expect(item.lifecycleLabel(nil, at: .now) == nil)
    }

    /// The timeline carries an entry at every bound, so the label advances without a fetch.
    @Test func lifecycleEntriesLandOnEveryUpcomingBound() throws {
        let now = Date(timeIntervalSince1970: 1788044000)
        let payload = try decodePayload(items: """
        {
          "id": "1", "mainText": "A", "subText": "",
          "startsAt": 1788044400, "expiresAt": 1788051600
        },
        {
          "id": "2", "mainText": "B", "subText": "",
          "startsAt": 1788044400, "expiresAt": 1788048000
        }
        """)

        // Deduplicated and ordered; the shared start appears once.
        #expect(lifecycleEntryDates(for: payload, after: now) == [
            Date(timeIntervalSince1970: 1788044400),
            Date(timeIntervalSince1970: 1788048000),
            Date(timeIntervalSince1970: 1788051600),
        ])
        // Bounds already past are not entries.
        #expect(lifecycleEntryDates(for: payload, after: Date(timeIntervalSince1970: 1788048000)) == [
            Date(timeIntervalSince1970: 1788051600),
        ])
        #expect(lifecycleEntryDates(for: payload, after: now, limit: 1).count == 1)
    }

    @Test func emptyFeedFallsBackToTheHourlyRefresh() {
        let now = Date(timeIntervalSince1970: 1788044400)
        let payload = WidgetPayload(schemaVersion: 3, items: [])

        #expect(nextRefreshDate(for: payload, after: now) == now.addingTimeInterval(3600))
    }

    private func decodePayload(
        presentation: String? = nil,
        lifecycle: String? = nil,
        items: String = """
        {
          "id": "1",
          "mainText": "Fever @ Wings",
          "subText": "ESPN",
          "caption": null,
          "emphasized": false,
          "startsAt": 1788044400,
          "expiresAt": 1788051600,
          "timestamp": 1788044400
        }
        """
    ) throws -> WidgetPayload {
        let presentationField = presentation.map { "\"presentation\": \($0)," } ?? ""
        let lifecycleField = lifecycle.map { "\"lifecycle\": \($0)," } ?? ""
        let data = Data("""
        {
          "schemaVersion": 3,
          \(presentationField)
          \(lifecycleField)
          "items": [\(items)]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetPayload.self, from: data)
    }
}
