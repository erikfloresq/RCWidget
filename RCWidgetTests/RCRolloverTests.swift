//
//  RCRolloverTests.swift
//  RCWidgetTests
//
//  Tests para la lógica pura de rollover compartida entre app y widget.
//
//  Regresión que cubren: antes del fix, el widget no avanzaba el ciclo cuando
//  su rango de fechas ya había vencido; sólo la app lo hacía. Al centralizar
//  el rollover en `RCRollover.advance`, validamos aquí que la misma lógica
//  funciona para todos los escenarios que el widget puede encontrar en frío:
//  ciclo vigente, un rollover pendiente, catch-up de varios ciclos vencidos,
//  herencia de duración modificada, y persistencia de Quarter/Sprint.
//

import Testing
@testable import RCWidget
import Foundation

struct RCRolloverTests {

    // MARK: Helpers

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func makeCycle(
        title: String = "RC 1",
        start: Date,
        end: Date,
        duration: Int? = nil,
        qsEnabled: Bool = false,
        sprint: Int = 1
    ) -> RCCycle {
        RCCycle(
            title: title,
            startDate: start,
            endDate: end,
            durationDays: duration,
            quarterSprintEnabled: qsEnabled,
            sprint: sprint,
            quarterSprintStartDate: start,
            quarterSprintEndDate: end
        )
    }

    // MARK: - No rollover

    @Test("Sin cambios cuando el ciclo activo aún contiene a `now`")
    func testNoRolloverWhenActive() {
        let cycle = makeCycle(
            start: date(2026, 1, 1),
            end: date(2026, 1, 7),
            duration: 7
        )
        let result = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 1, 5))

        #expect(result.didChange == false)
        #expect(result.activeCycle.title == "RC 1")
        #expect(result.pastCycles.isEmpty)
    }

    // MARK: - Single rollover

    @Test("Rollea al siguiente RC cuando el rango venció")
    func testSingleRollover() {
        let calendar = Calendar.current
        // RC 1: 1–7 de enero (7 días). Hoy es 8 de enero -> debe rollear a RC 2.
        let cycle = makeCycle(
            start: date(2026, 1, 1),
            end: date(2026, 1, 7),
            duration: 7
        )
        let result = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 1, 8))

        #expect(result.didChange == true)
        #expect(result.activeCycle.title == "RC 2")
        #expect(result.activeCycle.durationDays == 7)
        #expect(calendar.component(.day, from: result.activeCycle.startDate) == 8)
        #expect(calendar.component(.day, from: result.activeCycle.endDate) == 14)
        #expect(result.pastCycles.count == 1)
        #expect(result.pastCycles[0].title == "RC 1")
    }

    // MARK: - Catch-up: escenario del bug (app cerrada varios días)

    @Test("Catch-up de varios ciclos vencidos cuando la app estuvo cerrada")
    func testCatchUpMultipleCycles() {
        // RC 1: 1–7 de enero. Hoy es 22 de enero: han vencido RC 1, RC 2 y RC 3.
        // El widget debe llegar a RC 4 (15–21) → hoy 22 → RC 5 (22–28).
        // 1–7 (RC1), 8–14 (RC2), 15–21 (RC3), 22–28 (RC4).
        // En 22 de enero, RC4 aún está vigente (día 1), así que:
        // pastCycles = [RC1, RC2, RC3], activeCycle = RC4.
        let calendar = Calendar.current
        let cycle = makeCycle(
            start: date(2026, 1, 1),
            end: date(2026, 1, 7),
            duration: 7
        )
        let result = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 1, 22))

        #expect(result.didChange == true)
        #expect(result.activeCycle.title == "RC 4")
        #expect(result.activeCycle.durationDays == 7)
        #expect(calendar.component(.day, from: result.activeCycle.startDate) == 22)
        #expect(calendar.component(.day, from: result.activeCycle.endDate) == 28)
        #expect(result.pastCycles.count == 3)
        #expect(result.pastCycles.map(\.title) == ["RC 1", "RC 2", "RC 3"])
    }

    // MARK: - Hereda duración modificada

    @Test("Al rollear se hereda la duración exacta del ciclo anterior")
    func testInheritsCustomDuration() {
        let calendar = Calendar.current
        // RC 3: 1–10 de febrero (10 días). Hoy es 12 -> rolla a RC 4 con 10 días.
        let cycle = makeCycle(
            title: "RC 3",
            start: date(2026, 2, 1),
            end: date(2026, 2, 10),
            duration: 10
        )
        let result = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 2, 12))

        #expect(result.didChange == true)
        #expect(result.activeCycle.title == "RC 4")
        #expect(result.activeCycle.durationDays == 10)
        #expect(calendar.component(.day, from: result.activeCycle.startDate) == 11)
        #expect(calendar.component(.day, from: result.activeCycle.endDate) == 20)
    }

    // MARK: - Quarter/Sprint

    @Test("Rollea conservando la configuración de Quarter/Sprint activa")
    func testRolloverPreservesQuarterSprintConfig() {
        // RC vencido, pero rango Q/Sprint (todo enero) todavía vigente al día 8.
        // Así aislamos: valida sólo que el flag/número del sprint se conservan
        // durante el rollover del RC (el auto-avance del sprint se cubre en su
        // propio test).
        let cycle = RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 7),
            durationDays: 7,
            quarterSprintEnabled: true,
            sprint: 2,
            quarterSprintStartDate: date(2026, 1, 1),
            quarterSprintEndDate: date(2026, 1, 31)
        )
        let result = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 1, 8))

        #expect(result.didChange == true)
        #expect(result.activeCycle.title == "RC 2")
        #expect(result.activeCycle.quarterSprintEnabled == true)
        #expect(result.activeCycle.sprint == 2)
        // Rango Q/Sprint intacto (aún vigente, no se debe recalcular).
        #expect(result.activeCycle.quarterSprintStartDate == cycle.quarterSprintStartDate)
    }

    @Test("Aplica auto-avance del sprint aunque el RC no rollee")
    func testSprintAdvancesEvenIfRCDoesNot() {
        // RC amplio: 1 enero – 30 abril. Sprint: 1–7 enero. Hoy es 15 enero.
        // El RC sigue vigente, pero el sprint debería avanzar a sprint 2 (8–14) y
        // luego sprint 3 (15–21).
        let cycle = RCCycle(
            title: "RC 1",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 4, 30),
            durationDays: 120,
            quarterSprintEnabled: true,
            sprint: 1,
            quarterSprintStartDate: date(2026, 1, 1),
            quarterSprintEndDate: date(2026, 1, 7)
        )
        let result = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 1, 15))

        #expect(result.didChange == true)
        #expect(result.activeCycle.title == "RC 1") // RC no cambia
        #expect(result.activeCycle.sprint == 3)
        #expect(result.pastCycles.isEmpty) // el sprint no genera historial
    }

    // MARK: - Historial preservado

    @Test("El historial existente se preserva y crece al final")
    func testPreservesExistingHistory() {
        let old = makeCycle(
            title: "RC 0",
            start: date(2025, 12, 25),
            end: date(2025, 12, 31),
            duration: 7
        )
        let cycle = makeCycle(
            start: date(2026, 1, 1),
            end: date(2026, 1, 7),
            duration: 7
        )
        let result = RCRollover.advance(active: cycle, past: [old], asOf: date(2026, 1, 10))

        #expect(result.activeCycle.title == "RC 2")
        #expect(result.pastCycles.count == 2)
        #expect(result.pastCycles.map(\.title) == ["RC 0", "RC 1"])
    }

    // MARK: - Idempotencia

    @Test("Llamar advance dos veces sobre el mismo estado no duplica historial")
    func testIdempotency() {
        let cycle = makeCycle(
            start: date(2026, 1, 1),
            end: date(2026, 1, 7),
            duration: 7
        )
        let first = RCRollover.advance(active: cycle, past: [], asOf: date(2026, 1, 8))
        let second = RCRollover.advance(active: first.activeCycle, past: first.pastCycles, asOf: date(2026, 1, 8))

        #expect(second.didChange == false)
        #expect(second.activeCycle.title == first.activeCycle.title)
        #expect(second.pastCycles.count == first.pastCycles.count)
    }

    // MARK: - Título custom

    @Test("Título sin número recibe sufijo ' 2'")
    func testTitleAdvancerFallback() {
        #expect(RCRollover.defaultTitleAdvancer("RC") == "RC 2")
        #expect(RCRollover.defaultTitleAdvancer("Sprint") == "Sprint 2")
    }

    @Test("Título con número lo incrementa preservando el prefijo")
    func testTitleAdvancerIncrement() {
        #expect(RCRollover.defaultTitleAdvancer("RC 1") == "RC 2")
        #expect(RCRollover.defaultTitleAdvancer("RC 9") == "RC 10")
        #expect(RCRollover.defaultTitleAdvancer("Release Candidate 42") == "Release Candidate 43")
    }

    // MARK: - Fecha del próximo rollover (política del widget)

    @Test("nextRolloverDate es medianoche del día posterior al endDate")
    func testNextRolloverDate() {
        let calendar = Calendar.current
        let cycle = makeCycle(
            start: date(2026, 1, 1),
            end: date(2026, 1, 7),
            duration: 7
        )
        let rollover = RCRollover.nextRolloverDate(after: cycle)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: rollover)

        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 8)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test("nextRolloverDate está siempre en el futuro respecto al ciclo activo")
    func testNextRolloverDateIsAfterEndDate() {
        let cycle = makeCycle(
            start: date(2026, 3, 1),
            end: date(2026, 3, 15),
            duration: 15
        )
        let rollover = RCRollover.nextRolloverDate(after: cycle)
        #expect(rollover > cycle.endDate)
    }
}
