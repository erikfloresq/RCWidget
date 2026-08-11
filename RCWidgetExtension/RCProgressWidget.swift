//
//  RCProgressWidget.swift
//  RCWidgetExtension
//
//  Widget de escritorio / Centro de Notificaciones que muestra el
//  progreso del ciclo Release Candidate activo, reusando el diseño
//  glassmórfico del anillo de la versión anterior.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct RCEntry: TimelineEntry {
    let date: Date
    let cycle: RCCycle
}

struct RCProvider: TimelineProvider {
    func placeholder(in context: Context) -> RCEntry {
        RCEntry(date: Date(), cycle: RCStore.placeholderCycle())
    }

    func getSnapshot(in context: Context, completion: @escaping (RCEntry) -> Void) {
        let cycle = RCStore.loadActiveCycle() ?? RCStore.placeholderCycle()
        completion(RCEntry(date: Date(), cycle: cycle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RCEntry>) -> Void) {
        let cycle = RCStore.loadActiveCycle() ?? RCStore.placeholderCycle()
        let now = Date()
        let calendar = Calendar.current

        // Una entrada por hora durante 24 h para mantener frescos el contador
        // de días, la barra de progreso y el texto de tiempo restante.
        var entries: [RCEntry] = []
        for hourOffset in 0..<24 {
            let date = calendar.date(byAdding: .hour, value: hourOffset, to: now) ?? now
            entries.append(RCEntry(date: date, cycle: cycle))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct RCProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RCStore.widgetKind, provider: RCProvider()) { entry in
            RCProgressWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.09, blue: 0.16),
                            Color(red: 0.02, green: 0.03, blue: 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("RC Tracker")
        .description("Muestra el progreso de tu ciclo de Release Candidate activo.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

private let rcGradientColors = [Color.cyan, Color.blue, Color.purple]

struct RCProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RCEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    // MARK: Small

    private var smallBody: some View {
        VStack(spacing: 8) {
            header
            RCProgressRing(
                progress: entry.cycle.progress(asOf: entry.date),
                title: entry.cycle.title,
                subtitle: String(localized: "Día \(entry.cycle.daysElapsed(asOf: entry.date)) de \(entry.cycle.durationDays)")
            )
            .frame(maxHeight: .infinity)

            Text(entry.cycle.timeRemainingText(asOf: entry.date))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Medium

    private var mediumBody: some View {
        HStack(spacing: 18) {
            RCProgressRing(
                progress: entry.cycle.progress(asOf: entry.date),
                title: entry.cycle.title,
                subtitle: String(localized: "Día \(entry.cycle.daysElapsed(asOf: entry.date))/\(entry.cycle.durationDays)")
            )
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                header

                Text(entry.cycle.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Linear progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * CGFloat(entry.cycle.progress(asOf: entry.date))), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Día \(entry.cycle.daysElapsed(asOf: entry.date)) de \(entry.cycle.durationDays)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(entry.cycle.timeRemainingText(asOf: entry.date))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Shared header

    private var header: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("RC TRACKER")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1)
            Spacer(minLength: 0)
        }
    }
}

/// Anillo de progreso circular con degradado (Cian → Azul → Púrpura).
struct RCProgressRing: View {
    let progress: Double
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)

            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(colors: rcGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(14)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RCProgressWidget()
} timeline: {
    RCEntry(date: .now, cycle: RCStore.placeholderCycle())
}

#Preview("Medium", as: .systemMedium) {
    RCProgressWidget()
} timeline: {
    RCEntry(date: .now, cycle: RCStore.placeholderCycle())
}
