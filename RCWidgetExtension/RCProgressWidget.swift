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
        let cycle = Self.rolledOverCycle(now: Date())
        completion(RCEntry(date: Date(), cycle: cycle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RCEntry>) -> Void) {
        let now = Date()
        let cycle = Self.rolledOverCycle(now: now)
        let calendar = Calendar.current
        let rollover = RCRollover.nextRolloverDate(after: cycle, calendar: calendar)

        // Entradas horarias mientras el ciclo esté vigente, para que el contador
        // de días, la barra de progreso y el texto restante avancen sin esperar
        // a la próxima recarga de WidgetKit. Se cortan al momento del rollover
        // para no mostrar un ciclo "completado" cuando debería haber avanzado.
        var entries: [RCEntry] = []
        var pointer = now
        while pointer < rollover && entries.count < 25 {
            entries.append(RCEntry(date: pointer, cycle: cycle))
            guard let next = calendar.date(byAdding: .hour, value: 1, to: pointer) else { break }
            pointer = next
        }
        if entries.isEmpty {
            entries.append(RCEntry(date: now, cycle: cycle))
        }

        // .after(rollover) hace que WidgetKit pida un nuevo timeline en el
        // instante exacto del rollover; el próximo getTimeline verá el ciclo ya
        // avanzado gracias a rolledOverCycle(now:) y persistirá el nuevo estado.
        completion(Timeline(entries: entries, policy: .after(rollover)))
    }

    /// Carga el ciclo activo, aplica el rollover si su rango ya venció y
    /// persiste el resultado en el App Group. Se usa desde `getSnapshot` y
    /// `getTimeline` para que el widget avance el ciclo incluso cuando la app
    /// no está corriendo (antes, sólo la app lo hacía y el widget se quedaba
    /// mostrando un ciclo caducado). Delega en el helper compartido para que
    /// los tests puedan ejercitar exactamente el mismo flujo.
    static func rolledOverCycle(now: Date) -> RCCycle {
        RCRollover.advanceStoredCycle(now: now)
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
    //
    // El tamaño pequeño no tiene espacio para el anillo circular, así que usa el
    // mismo diseño lineal/compacto del widget de la barra de menús: encabezado,
    // etiqueta opcional de Q/Sprint, título, barra de progreso lineal y el
    // contador de días con el tiempo restante.

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if let qsLabel = entry.cycle.quarterSprintLabel {
                Text(qsLabel)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.35), in: Capsule())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(entry.cycle.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer(minLength: 0)

            // Linear progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * CGFloat(entry.cycle.progress(asOf: entry.date))), height: 6)
                }
            }
            .frame(height: 6)

            Text("Día \(entry.cycle.daysElapsed(asOf: entry.date)) de \(entry.cycle.durationDays)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(entry.cycle.timeRemainingText(asOf: entry.date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

                if let qsLabel = entry.cycle.quarterSprintLabel {
                    Text(qsLabel)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.35), in: Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

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
