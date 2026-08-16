//
//  RCStore.swift
//  RCWidget (shared)
//
//  Almacenamiento compartido entre la app y la extensión de widget
//  mediante un App Group. Serializa los ciclos con Codable en el
//  UserDefaults del grupo.
//

import Foundation

enum RCStore {
    /// App Group compartido por la app y la extensión de widget.
    static let appGroupIdentifier = "group.dev.erikfloresq.RCWidget"

    /// Kind del widget de escritorio / Centro de Notificaciones.
    static let widgetKind = "dev.erikfloresq.RCWidget.progress"

    /// Kind del control del Centro de Control.
    static let controlKind = "dev.erikfloresq.RCWidget.control"

    private static let activeCycleKey = "activeCycle"
    private static let pastCyclesKey = "pastCycles"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    // MARK: - Active cycle
    //
    // Los overloads con parámetro `defaults:` permiten aislar el UserDefaults
    // en tests (con un suite dedicado). En producción se usa el default del App
    // Group.

    static func loadActiveCycle(from defaults: UserDefaults = RCStore.defaults) -> RCCycle? {
        guard let data = defaults.data(forKey: activeCycleKey),
              let cycle = try? JSONDecoder().decode(RCCycle.self, from: data) else {
            return nil
        }
        return cycle
    }

    static func saveActiveCycle(_ cycle: RCCycle, to defaults: UserDefaults = RCStore.defaults) {
        if let data = try? JSONEncoder().encode(cycle) {
            defaults.set(data, forKey: activeCycleKey)
        }
    }

    // MARK: - Past cycles

    static func loadPastCycles(from defaults: UserDefaults = RCStore.defaults) -> [RCCycle] {
        guard let data = defaults.data(forKey: pastCyclesKey),
              let cycles = try? JSONDecoder().decode([RCCycle].self, from: data) else {
            return []
        }
        return cycles
    }

    static func savePastCycles(_ cycles: [RCCycle], to defaults: UserDefaults = RCStore.defaults) {
        if let data = try? JSONEncoder().encode(cycles) {
            defaults.set(data, forKey: pastCyclesKey)
        }
    }

    /// Ciclo de respaldo para snapshots/placeholders del widget.
    static func placeholderCycle() -> RCCycle {
        let today = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 6, to: today) ?? today
        return RCCycle(title: "RC 1", startDate: today, endDate: end, durationDays: 7)
    }

    // MARK: - Migration

    /// Migra datos desde el `UserDefaults.standard` (versión anterior de la app,
    /// widget flotante) al App Group, una sola vez.
    static func migrateFromStandardIfNeeded() {
        let migratedKey = "didMigrateToAppGroup"
        guard !defaults.bool(forKey: migratedKey) else { return }

        let standard = UserDefaults.standard
        if loadActiveCycle() == nil, let data = standard.data(forKey: activeCycleKey) {
            defaults.set(data, forKey: activeCycleKey)
        }
        if loadPastCycles().isEmpty, let data = standard.data(forKey: pastCyclesKey) {
            defaults.set(data, forKey: pastCyclesKey)
        }
        defaults.set(true, forKey: migratedKey)
    }
}
