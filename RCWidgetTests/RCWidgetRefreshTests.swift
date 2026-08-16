//
//  RCWidgetRefreshTests.swift
//  RCWidgetTests
//
//  Tests end-to-end del refresco del widget. Ejercitan el mismo flujo que el
//  `TimelineProvider` y el `ControlValueProvider` de la extensión: leer del
//  almacenamiento compartido, aplicar rollover, persistir el resultado.
//
//  Regresión que evitan: antes del fix, la extensión no aplicaba rollover.
//  Si la app estaba cerrada cuando el ciclo vencía, el widget seguía mostrando
//  el ciclo caducado hasta que el usuario abría la app.
//

import Testing
@testable import RCWidget
import Foundation

struct RCWidgetRefreshTests {

    // MARK: Helpers

    /// UserDefaults aislado por test: cada test usa un suite único y lo limpia
    /// al terminar. Evita colisiones con el App Group real de la app.
    private final class IsolatedDefaults {
        let name: String
        let defaults: UserDefaults

        init(function: String = #function) {
            self.name = "test.\(UUID().uuidString).\(function)"
            self.defaults = UserDefaults(suiteName: name)!
            self.defaults.removePersistentDomain(forName: name)
        }

        deinit {
            defaults.removePersistentDomain(forName: name)
        }
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func seed(
        _ defaults: UserDefaults,
        active: RCCycle,
        past: [RCCycle] = []
    ) {
        RCStore.saveActiveCycle(active, to: defaults)
        RCStore.savePastCycles(past, to: defaults)
    }

    private func loadActive(_ defaults: UserDefaults) -> RCCycle? {
        RCStore.loadActiveCycle(from: defaults)
    }

    private func loadPast(_ defaults: UserDefaults) -> [RCCycle] {
        RCStore.loadPastCycles(from: defaults)
    }

    // MARK: - El widget avanza el ciclo caducado (regresión principal)

    @Test("Widget avanza el ciclo cuando la app estuvo cerrada al vencer el rango")
    func testWidgetRolloverWhenAppWasClosed() {
        let iso = IsolatedDefaults()
        // Estado persistido por la app: RC 1 del 1 al 7 de enero.
        let expired = RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 7),
            durationDays: 7
        )
        seed(iso.defaults, active: expired)

        // El widget se despierta el 8 de enero. Antes del fix: mostraba RC 1
        // caducado. Con el fix: avanza a RC 2 y persiste.
        let cycle = RCRollover.advanceStoredCycle(now: date(2026, 1, 8), defaults: iso.defaults)

        #expect(cycle.title == "RC 2")
        #expect(cycle.durationDays == 7)

        // Y el rollover queda persistido para el próximo refresh o para la app.
        let persistedActive = loadActive(iso.defaults)
        let persistedPast = loadPast(iso.defaults)
        #expect(persistedActive?.title == "RC 2")
        #expect(persistedPast.count == 1)
        #expect(persistedPast[0].title == "RC 1")
    }

    @Test("Widget hace catch-up de varios ciclos si la app estuvo cerrada mucho tiempo")
    func testWidgetCatchUpMultipleCycles() {
        let iso = IsolatedDefaults()
        let expired = RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 7),
            durationDays: 7
        )
        seed(iso.defaults, active: expired)

        // Han pasado 3 ciclos completos (RC 1, RC 2, RC 3) y estamos en el 4.
        let cycle = RCRollover.advanceStoredCycle(now: date(2026, 1, 22), defaults: iso.defaults)

        #expect(cycle.title == "RC 4")
        #expect(loadPast(iso.defaults).map(\.title) == ["RC 1", "RC 2", "RC 3"])
    }

    // MARK: - No toca nada cuando el ciclo sigue vigente

    @Test("Widget no altera el estado cuando el ciclo activo sigue vigente")
    func testWidgetNoOpWhenCycleActive() {
        let iso = IsolatedDefaults()
        let active = RCCycle(
            title: "RC 5",
            startDate: date(2026, 3, 1),
            endDate: date(2026, 3, 14),
            durationDays: 14
        )
        seed(iso.defaults, active: active, past: [])

        let cycle = RCRollover.advanceStoredCycle(now: date(2026, 3, 7), defaults: iso.defaults)

        #expect(cycle.title == "RC 5")
        #expect(loadPast(iso.defaults).isEmpty)
        // El ciclo persistido es idéntico al original.
        #expect(loadActive(iso.defaults)?.id == active.id)
    }

    // MARK: - Idempotencia entre llamadas repetidas del widget

    @Test("Llamadas consecutivas del widget son idempotentes cuando el estado ya está al día")
    func testWidgetIdempotentAfterCatchUp() {
        let iso = IsolatedDefaults()
        seed(iso.defaults, active: RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 7),
            durationDays: 7
        ))

        let now = date(2026, 1, 22)
        let first = RCRollover.advanceStoredCycle(now: now, defaults: iso.defaults)
        let idAfterFirst = loadActive(iso.defaults)?.id
        let pastCountAfterFirst = loadPast(iso.defaults).count

        let second = RCRollover.advanceStoredCycle(now: now, defaults: iso.defaults)

        #expect(first.title == second.title)
        #expect(loadActive(iso.defaults)?.id == idAfterFirst)
        #expect(loadPast(iso.defaults).count == pastCountAfterFirst)
    }

    // MARK: - Sincronización app ↔ widget vía App Group

    @Test("Cambios que hace el widget son visibles para el siguiente lector (app o widget)")
    func testWidgetChangesAreVisibleToNextReader() {
        let iso = IsolatedDefaults()
        seed(iso.defaults, active: RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 7),
            durationDays: 7
        ))

        // 1. Widget se refresca a las 8 de enero -> rollover a RC 2.
        _ = RCRollover.advanceStoredCycle(now: date(2026, 1, 8), defaults: iso.defaults)

        // 2. Otro cliente (p. ej. el menu bar al reabrir la app) lee el store.
        let seenByApp = loadActive(iso.defaults)
        #expect(seenByApp?.title == "RC 2")
    }

    // MARK: - Cold start del widget sin datos previos

    @Test("Widget en frío sin datos usa el placeholder y no falla")
    func testWidgetColdStartUsesPlaceholder() {
        let iso = IsolatedDefaults()
        // No sembramos nada -> defaults vacíos, como al instalar la app.
        let cycle = RCRollover.advanceStoredCycle(now: date(2026, 1, 8), defaults: iso.defaults)

        // El placeholder arranca hoy con 7 días de duración, así que en su
        // primer refresh no ha vencido y no persiste ningún historial.
        #expect(cycle.durationDays == 7)
        #expect(loadPast(iso.defaults).isEmpty)
    }

    // MARK: - Política de refresh del timeline

    @Test("La política .after usa el instante del próximo rollover, no una hora fija")
    func testTimelineRefreshPolicyMatchesRollover() {
        let iso = IsolatedDefaults()
        let active = RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 7),
            durationDays: 7
        )
        seed(iso.defaults, active: active)

        // El widget consulta la fecha en que debe reactivar el timeline.
        let cycle = RCRollover.advanceStoredCycle(now: date(2026, 1, 5), defaults: iso.defaults)
        let refreshAt = RCRollover.nextRolloverDate(after: cycle)

        // Debería ser exactamente medianoche del 8 de enero (día siguiente al fin del ciclo).
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: refreshAt)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 8)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
    }
}
