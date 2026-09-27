import SwiftUI
import WidgetKit

/// Shared feed date line for the large widget and the app's feed preview.
struct WidgetLifecycleContext {
    var labels: WidgetLifecycleLabels?
    var now: Date = .now
}

extension EnvironmentValues {
    @Entry var widgetLifecycle: WidgetLifecycleContext = WidgetLifecycleContext(labels: nil)
}

func dayLabel(for date: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent
    if calendar.isDateInToday(date) { return "TODAY" }
    if calendar.isDateInTomorrow(date) { return "TMRW" }

    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter.string(from: date).uppercased()
}

struct BeaconDateTimeView: View {
    enum Style {
        case primary
        case secondary
        case accessory
    }

    enum Layout {
        case inline
        case stacked
    }

    @Environment(\.widgetLifecycle) private var lifecycle

    let item: WidgetItem
    let style: Style
    var layout: Layout = .inline

    private var detail: String {
        item.lifecycleLabel(lifecycle.labels, at: lifecycle.now)
            ?? item.startsAt.formatted(date: .omitted, time: .shortened)
    }

    private var label: String {
        switch layout {
        case .inline:
            return "\(dayLabel(for: item.startsAt)) · \(detail)"
        case .stacked:
            return "\(dayLabel(for: item.startsAt))\n\(detail)"
        }
    }

    private var font: Font {
        switch style {
        case .primary: return .system(.title2, design: .default, weight: .bold)
        case .secondary: return .system(.subheadline, design: .default, weight: .semibold)
        case .accessory: return .system(.subheadline, design: .default, weight: .semibold)
        }
    }

    var body: some View {
        Text(label)
            .font(font)
            .monospacedDigit()
            .lineLimit(layout == .stacked ? 2 : 1)
            .fixedSize(horizontal: false, vertical: layout == .stacked)
            .foregroundStyle(style == .accessory ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
            .widgetAccentable()
    }
}
