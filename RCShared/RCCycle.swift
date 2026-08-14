//
//  RCCycle.swift
//  RCWidget (shared)
//
//  Modelo de ciclo Release Candidate y helpers de progreso.
//  Este archivo se compila tanto en la app como en la extensión de widget.
//

import Foundation

// MARK: - Data Model

struct RCCycle: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var durationDays: Int

    // MARK: Quarter / Sprint (opcional)
    //
    // Algunos equipos trabajan bajo sprints que corren en paralelo dentro de un
    // trimestre (quarter). Estos campos permiten indicar, de forma opcional, en
    // qué Q y sprint se encuentra el equipo (p. ej. "Q1 · Sprint 2").
    // La función está desactivada por defecto; el usuario debe activarla.
    //
    // El ciclo de Quarter/Sprint tiene su PROPIO rango de fechas, independiente
    // del rango del RC, porque un sprint suele correr en paralelo y no coincide
    // necesariamente con el ciclo de Release Candidate.
    //
    // El número de sprint se guarda y avanza automáticamente (ver
    // `advancingSprint`). El quarter (Q) NO se guarda: se deriva del mes de la
    // fecha de inicio del sprint según los trimestres calendario (Q1 = ene–mar,
    // Q2 = abr–jun, Q3 = jul–sep, Q4 = oct–dic).
    var quarterSprintEnabled: Bool
    var sprint: Int
    var quarterSprintStartDate: Date
    var quarterSprintEndDate: Date

    /// Quarter calendario (1–4) correspondiente al mes de `date`.
    /// Q1 = ene–mar, Q2 = abr–jun, Q3 = jul–sep, Q4 = oct–dic.
    static func quarter(for date: Date, calendar: Calendar = .current) -> Int {
        let month = calendar.component(.month, from: date)
        return (month - 1) / 3 + 1
    }

    /// Quarter derivado del mes de inicio del rango de Q/Sprint.
    var quarter: Int { RCCycle.quarter(for: quarterSprintStartDate) }

    /// Normaliza una fecha de inicio al comienzo del día (00:00:00).
    static func normalizedStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Normaliza una fecha de término al final del día (23:59:59) y garantiza
    /// que no sea anterior a `notBefore`.
    static func normalizedEnd(_ date: Date, notBefore: Date, calendar: Calendar = .current) -> Date {
        let end = calendar.startOfDay(for: date)
        let finalEnd = end < notBefore ? notBefore : end
        var endComponents = calendar.dateComponents([.year, .month, .day], from: finalEnd)
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        return calendar.date(from: endComponents) ?? finalEnd
    }

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        durationDays: Int? = nil,
        quarterSprintEnabled: Bool = false,
        sprint: Int = 1,
        quarterSprintStartDate: Date? = nil,
        quarterSprintEndDate: Date? = nil
    ) {
        self.id = id
        self.title = title

        self.quarterSprintEnabled = quarterSprintEnabled
        self.sprint = max(1, sprint)

        let calendar = Calendar.current
        let start = RCCycle.normalizedStart(startDate, calendar: calendar)
        self.startDate = start
        self.endDate = RCCycle.normalizedEnd(endDate, notBefore: start, calendar: calendar)

        if let duration = durationDays {
            self.durationDays = duration
        } else {
            let components = calendar.dateComponents([.day], from: start, to: self.endDate)
            self.durationDays = max(1, (components.day ?? 0) + 1)
        }

        // Rango de Q/Sprint: si no se especifica, cae de vuelta al rango del RC.
        let qsStart = RCCycle.normalizedStart(quarterSprintStartDate ?? startDate, calendar: calendar)
        self.quarterSprintStartDate = qsStart
        self.quarterSprintEndDate = RCCycle.normalizedEnd(
            quarterSprintEndDate ?? endDate,
            notBefore: qsStart,
            calendar: calendar
        )
    }

    // Decodificación tolerante: los ciclos guardados por versiones anteriores no
    // incluyen los campos de Quarter/Sprint, por lo que usamos valores por
    // defecto (función desactivada, rango igual al del RC) cuando faltan.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.durationDays = try container.decode(Int.self, forKey: .durationDays)
        self.quarterSprintEnabled = try container.decodeIfPresent(Bool.self, forKey: .quarterSprintEnabled) ?? false
        self.sprint = max(1, try container.decodeIfPresent(Int.self, forKey: .sprint) ?? 1)
        self.quarterSprintStartDate = try container.decodeIfPresent(Date.self, forKey: .quarterSprintStartDate) ?? startDate
        self.quarterSprintEndDate = try container.decodeIfPresent(Date.self, forKey: .quarterSprintEndDate) ?? endDate
    }
}

// MARK: - Quarter / Sprint label

extension RCCycle {
    /// Etiqueta "Q1 · Sprint 2" cuando la función está activada; `nil` si no.
    var quarterSprintLabel: String? {
        guard quarterSprintEnabled else { return nil }
        return String(localized: "Q\(quarter) · Sprint \(sprint)")
    }
}

// MARK: - Sprint auto-advance (puro, basado en una fecha de referencia)

extension RCCycle {
    /// Devuelve una copia del ciclo con el sprint avanzado hasta que su rango de
    /// fechas contenga a `now`. Por cada periodo de sprint ya vencido incrementa
    /// el número de sprint y desplaza el rango hacia adelante (heredando la misma
    /// duración), de forma análoga al auto-rollover del RC. El quarter se
    /// recalcula solo, porque se deriva del mes de inicio del nuevo rango.
    ///
    /// Si la función de Q/Sprint está desactivada, se devuelve sin cambios.
    func advancingSprint(asOf now: Date = Date(), calendar: Calendar = .current) -> RCCycle {
        guard quarterSprintEnabled else { return self }

        var result = self
        let todayStart = calendar.startOfDay(for: now)

        while true {
            let endStart = calendar.startOfDay(for: result.quarterSprintEndDate)
            // El siguiente sprint empieza el día después de que termina el actual.
            guard let nextStart = calendar.date(byAdding: .day, value: 1, to: endStart) else { break }

            // Solo avanza si hoy ya alcanzó (o pasó) el inicio del siguiente sprint.
            guard todayStart >= nextStart else { break }

            let duration = daysBetweenInclusive(start: result.quarterSprintStartDate, end: result.quarterSprintEndDate)

            var components = DateComponents()
            components.day = duration - 1
            components.hour = 23
            components.minute = 59
            components.second = 59
            guard let nextEnd = calendar.date(byAdding: components, to: nextStart) else { break }

            result.sprint += 1
            result.quarterSprintStartDate = nextStart
            result.quarterSprintEndDate = nextEnd
        }

        return result
    }
}

// MARK: - Derived progress helpers (pure, based on a reference date)

extension RCCycle {
    private func daysBetweenInclusive(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return max(1, (components.day ?? 0) + 1)
    }

    func daysElapsed(asOf now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: startDate) {
            return 0
        }
        if today > calendar.startOfDay(for: endDate) {
            return durationDays
        }
        let elapsed = daysBetweenInclusive(start: startDate, end: today)
        return min(durationDays, max(1, elapsed))
    }

    func progress(asOf now: Date = Date()) -> Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0.0 }
        let elapsed = now.timeIntervalSince(startDate)
        return max(0.0, min(1.0, elapsed / total))
    }

    func timeRemainingText(asOf now: Date = Date()) -> String {
        if now > endDate {
            return String(localized: "¡Ciclo Completado!")
        }

        let remaining = endDate.timeIntervalSince(now)
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600

        // DateComponentsFormatter localiza y pluraliza las unidades según el
        // locale actual (p. ej. "3 días, 5 horas" / "3 days, 5 hours").
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        if days > 0 {
            formatter.allowedUnits = [.day, .hour]
        } else if hours > 0 {
            formatter.allowedUnits = [.hour, .minute]
        } else {
            formatter.allowedUnits = [.minute]
        }

        guard let value = formatter.string(from: remaining), !value.isEmpty else {
            return String(localized: "Quedan unos segundos")
        }
        return String(localized: "Quedan \(value)")
    }
}
