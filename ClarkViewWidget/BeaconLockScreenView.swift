import SwiftUI
import WidgetKit

/// Compact Beacon surface sharing the main widget's feed and date/status treatment.
/// System foreground styles keep it legible in Lock Screen monochrome rendering.
struct BeaconLockScreenView: View {
    let entry: WidgetEntry

    var body: some View {
        Group {
            if let item = entry.payload.items.first {
                VStack(alignment: .leading, spacing: 2) {
                    BeaconDateTimeView(item: item, style: .accessory)

                    Text(item.mainText)
                        .font(.title.bold())
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            } else {
                Label("Nothing here right now", systemImage: "sportscourt")
                    .font(.caption)
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}
