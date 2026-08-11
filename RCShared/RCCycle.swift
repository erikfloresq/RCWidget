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

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date, durationDays: Int? = nil) {
        self.id = id
        self.title = title

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        self.startDate = start

        // Ensure endDate is at least the startDate
        let finalEnd = end < start ? start : end

        // Set end date to the end of that day (23:59:59)
        var endComponents = calendar.dateComponents([.year, .month, .day], from: finalEnd)
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        self.endDate = calendar.date(from: endComponents) ?? finalEnd

        if let duration = durationDays {
            self.durationDays = duration
        } else {
            let components = calendar.dateComponents([.day], from: start, to: finalEnd)
            self.durationDays = max(1, (components.day ?? 0) + 1)
        }
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
            return "¡Ciclo Completado!"
        }

        let remaining = endDate.timeIntervalSince(now)
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if days > 0 {
            if hours > 0 {
                return "Quedan \(days) \(days == 1 ? "día" : "días") y \(hours) \(hours == 1 ? "hora" : "horas")"
            } else {
                return "Quedan \(days) \(days == 1 ? "día" : "días")"
            }
        } else if hours > 0 {
            return "Quedan \(hours) \(hours == 1 ? "hora" : "horas") y \(minutes) \(minutes == 1 ? "min" : "mins")"
        } else if minutes > 0 {
            return "Quedan \(minutes) \(minutes == 1 ? "minuto" : "minutos")"
        } else {
            return "Quedan unos segundos"
        }
    }
}
