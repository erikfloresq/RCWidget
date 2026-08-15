//
//  RCRollover.swift
//  RCWidget (shared)
//
//  Lógica pura de auto-avance (rollover) del ciclo RC.
//
//  Se comparte entre la app (RCCycleManager) y la extensión de widget
//  (RCProvider / RCStatusControl) para que ambos avancen el ciclo con las
//  mismas reglas cuando su rango de fechas ya venció. Antes del fix, sólo
//  la app avanzaba el ciclo; cuando la app estaba cerrada el widget mostraba
//  un ciclo caducado hasta que el usuario abría la app.
//

import Foundation

enum RCRollover {
    /// Resultado de una iteración de rollover.
    struct Result: Equatable {
        var activeCycle: RCCycle
        var pastCycles: [RCCycle]
        /// `true` si hubo algún cambio (rollover del RC o auto-avance del sprint).
        var didChange: Bool
    }

    /// Avanza el ciclo activo hasta que su rango contenga a `now`, moviendo los
    /// ciclos vencidos al historial. Hereda la duración del ciclo anterior y la
    /// configuración de Quarter/Sprint. Además, aplica el auto-avance del sprint.
    ///
    /// Es determinístico y no realiza IO — el llamador decide si persiste el
    /// resultado. La app llama `saveActiveCycle` / `savePastCycles` en el `didSet`;
    /// la extensión de widget persiste sólo cuando `didChange == true`.
    static func advance(
        active: RCCycle,
        past: [RCCycle],
        titleAdvancer: (String) -> String = RCRollover.defaultTitleAdvancer,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Result {
        var current = active
        var history = past
        var changed = false
        let todayStart = calendar.startOfDay(for: now)

        while true {
            let endDayStart = calendar.startOfDay(for: current.endDate)
            guard let nextStart = calendar.date(byAdding: .day, value: 1, to: endDayStart) else { break }
            if todayStart < nextStart { break }

            // Congela el ciclo vencido en el historial sin arrastrar la
            // configuración Q/Sprint (que sigue avanzando en el ciclo activo).
            let completed = RCCycle(
                id: current.id,
                title: current.title,
                startDate: current.startDate,
                endDate: current.endDate,
                durationDays: current.durationDays
            )
            history.append(completed)

            let nextTitle = titleAdvancer(current.title)
            let nextDuration = current.durationDays

            var components = DateComponents()
            components.day = nextDuration - 1
            components.hour = 23
            components.minute = 59
            components.second = 59
            guard let nextEnd = calendar.date(byAdding: components, to: nextStart) else { break }

            current = RCCycle(
                id: UUID(),
                title: nextTitle,
                startDate: nextStart,
                endDate: nextEnd,
                durationDays: nextDuration,
                quarterSprintEnabled: current.quarterSprintEnabled,
                sprint: current.sprint,
                quarterSprintStartDate: current.quarterSprintStartDate,
                quarterSprintEndDate: current.quarterSprintEndDate
            )
            changed = true
        }

        // El sprint (opcional) tiene su propio rango y avanza independiente.
        let sprintAdvanced = current.advancingSprint(asOf: now, calendar: calendar)
        if sprintAdvanced != current {
            current = sprintAdvanced
            changed = true
        }

        return Result(activeCycle: current, pastCycles: history, didChange: changed)
    }

    /// Momento en el que el ciclo activo debe rollear al siguiente:
    /// medianoche (00:00:00) del día posterior al `endDate`.
    ///
    /// Se usa como `TimelineReloadPolicy.after(...)` para que WidgetKit vuelva
    /// a llamar `getTimeline` exactamente cuando el ciclo vence, sin depender
    /// del ritmo de refresco genérico.
    static func nextRolloverDate(after cycle: RCCycle, calendar: Calendar = .current) -> Date {
        let endDayStart = calendar.startOfDay(for: cycle.endDate)
        return calendar.date(byAdding: .day, value: 1, to: endDayStart) ?? cycle.endDate
    }

    /// Flujo end-to-end del widget: lee el ciclo activo y el historial del
    /// almacenamiento compartido, aplica `advance` con la fecha dada, persiste
    /// el resultado si cambió y devuelve el ciclo vigente.
    ///
    /// Este es el punto de entrada que el `TimelineProvider` y el `Control`
    /// deben usar para asegurar que el widget refleje el rollover incluso
    /// cuando la app está cerrada. `defaults` es inyectable para tests.
    @discardableResult
    static func advanceStoredCycle(
        now: Date,
        defaults: UserDefaults = RCStore.defaults
    ) -> RCCycle {
        let stored = RCStore.loadActiveCycle(from: defaults) ?? RCStore.placeholderCycle()
        let past = RCStore.loadPastCycles(from: defaults)
        let result = RCRollover.advance(active: stored, past: past, asOf: now)
        if result.didChange {
            RCStore.saveActiveCycle(result.activeCycle, to: defaults)
            RCStore.savePastCycles(result.pastCycles, to: defaults)
        }
        return result.activeCycle
    }

    /// Regla estándar de incremento del título: si termina en un número, lo
    /// aumenta en 1; si no, agrega " 2". Es la misma lógica de la app para que
    /// el rollover del widget sea equivalente.
    static func defaultTitleAdvancer(_ title: String) -> String {
        let pattern = #"(.*?)\s*(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(
            in: title,
            options: [],
            range: NSRange(title.startIndex..., in: title)
           ) {
            let titleRange = match.range(at: 1)
            let numberRange = match.range(at: 2)
            if let titleSub = Range(titleRange, in: title),
               let numberSub = Range(numberRange, in: title),
               let currentNum = Int(title[numberSub]) {
                let baseTitle = title[titleSub].trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(baseTitle) \(currentNum + 1)"
            }
        }
        return "\(title) 2"
    }
}
