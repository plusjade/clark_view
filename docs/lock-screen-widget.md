# Lock Screen widget

The proof of concept adds `.accessoryRectangular` to the existing Clark View widget.
It uses the same provider, pairing, widget kind, refresh schedule, and push handler.
The first feed item is displayed independently of the large Home Screen widget's focus.

Edit `ClarkViewWidget/BeaconLockScreenView.swift` to iterate on the surface.
`BeaconDateTimeView` in `BeaconWidgetTemplate.swift` shares Beacon's caption and local
date/time formatting, with an accessory font and system foreground color. Lock Screen
rendering uses system styles and a clear container instead of the Home Screen palette.
The title uses bold title3; status and source use semibold subheadline with primary
foreground contrast. Titles and source details each occupy one line and truncate
when space is limited. Increase legibility by reducing content before shrinking fonts;
the system controls the accessory rectangle’s size and Lock Screen color treatment.

Open the “Lock Screen” preview in `ClarkViewWidget.swift` for live-caption, upcoming,
empty, and long-text fixtures. Widget gallery snapshots also use offline sample data.
Build and run the app, then customize the Lock Screen, choose Add Widgets → Clark View,
and select the rectangular widget. Pair the app to display the current feed.

Before shipping, inspect the widget on a device with long text, VoiceOver, and
Always On dimming. Circular and inline accessory families are not implemented.
