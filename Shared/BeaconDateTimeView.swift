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

    @Environment(\.widgetLifecycle) private var lifecycle

    let item: WidgetItem
    let style: Style

    private var label: String {
        let detail = item.lifecycleLabel(lifecycle.labels, at: lifecycle.now)
            ?? item.startsAt.formatted(date: .omitted, time: .shortened)
        return "\(dayLabel(for: item.startsAt)) · \(detail)"
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
            .lineLimit(1)
            .foregroundStyle(style == .accessory ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
            .widgetAccentable()
    }
}
