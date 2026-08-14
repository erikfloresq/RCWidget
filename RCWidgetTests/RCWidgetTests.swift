//
//  RCWidgetTests.swift
//  RCWidgetTests
//
//  Created by Erik Flores on 23/5/26.
//

import Testing
@testable import RCWidget
import Foundation

struct RCWidgetTests {

    @Test("Test Title Increment Logic")
    func testTitleIncrement() {
        let manager = RCCycleManager()
        
        #expect(manager.incrementTitle("RC 1") == "RC 2")
        #expect(manager.incrementTitle("RC 9") == "RC 10")
        #expect(manager.incrementTitle("Sprint 5") == "Sprint 6")
        #expect(manager.incrementTitle("Sprint") == "Sprint 2")
        #expect(manager.incrementTitle("RC 2026") == "RC 2027")
    }

    @Test("Test Cycle Initialization and Days Calculation")
    func testCycleInitialization() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 7))!
        
        let cycle = RCCycle(title: "RC 1", startDate: start, endDate: end)
        
        #expect(cycle.durationDays == 7)
        #expect(calendar.component(.hour, from: cycle.endDate) == 23)
        #expect(calendar.component(.minute, from: cycle.endDate) == 59)
        #expect(calendar.component(.second, from: cycle.endDate) == 59)
    }

    @Test("Test Scenario from User Prompt")
    func testUserRolloverScenario() {
        let calendar = Calendar.current
        let start1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
        let end1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 7, hour: 23, minute: 59, second: 59))!
        
        // 1. Initial Cycle RC 1 (7 days)
        let activeCycle = RCCycle(title: "RC 1", startDate: start1, endDate: end1, durationDays: 7)
        #expect(activeCycle.durationDays == 7)
        
        // 2. Rollover to RC 2 (inherits 7 days)
        let endDateStart = calendar.startOfDay(for: activeCycle.endDate)
        let nextCycleStart = calendar.date(byAdding: .day, value: 1, to: endDateStart)!
        
        #expect(calendar.component(.day, from: nextCycleStart) == 8)
        #expect(calendar.component(.month, from: nextCycleStart) == 1)
        
        let nextTitle = "RC 2"
        let nextDuration = activeCycle.durationDays
        
        var components = DateComponents()
        components.day = nextDuration - 1
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        let nextEnd = calendar.date(byAdding: components, to: nextCycleStart)!
        
        let nextCycle = RCCycle(title: nextTitle, startDate: nextCycleStart, endDate: nextEnd, durationDays: nextDuration)
        
        #expect(nextCycle.title == "RC 2")
        #expect(nextCycle.durationDays == 7)
        #expect(calendar.component(.day, from: nextCycle.endDate) == 14)
        
        // 3. User configures RC 3 with 10 days (15/1/2026 - 24/1/2026)
        let start3 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let end3 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 24))!
        
        let customRC3 = RCCycle(title: "RC 3", startDate: start3, endDate: end3)
        #expect(customRC3.durationDays == 10)
        
        // 4. Next rollover (RC 4) inherits 10 days
        let end3Start = calendar.startOfDay(for: customRC3.endDate)
        let rc4Start = calendar.date(byAdding: .day, value: 1, to: end3Start)!
        
        #expect(calendar.component(.day, from: rc4Start) == 25)
        
        let rc4Title = "RC 4"
        let rc4Duration = customRC3.durationDays
        
        var rc4Components = DateComponents()
        rc4Components.day = rc4Duration - 1
        rc4Components.hour = 23
        rc4Components.minute = 59
        rc4Components.second = 59
        
        let rc4End = calendar.date(byAdding: rc4Components, to: rc4Start)!
        
        let rc4 = RCCycle(title: rc4Title, startDate: rc4Start, endDate: rc4End, durationDays: rc4Duration)
        
        #expect(rc4.title == "RC 4")
        #expect(rc4.durationDays == 10)
        #expect(calendar.component(.day, from: rc4.endDate) == 3)
        #expect(calendar.component(.month, from: rc4.endDate) == 2) // Feb 3, 2026
    }

    // MARK: - Quarter / Sprint

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Quarter/Sprint label is nil when disabled, formatted when enabled")
    func testQuarterSprintLabel() {
        // Sprint que inicia en enero -> Q1.
        let start = makeDate(2026, 1, 5)
        let end = makeDate(2026, 1, 11)

        // Disabled by default -> no label
        let plain = RCCycle(title: "RC 3", startDate: start, endDate: end)
        #expect(plain.quarterSprintEnabled == false)
        #expect(plain.quarterSprintLabel == nil)

        // Enabled -> "Q1 · Sprint 2" (Q derivado del mes de inicio)
        let tagged = RCCycle(
            title: "RC 3",
            startDate: start,
            endDate: end,
            quarterSprintEnabled: true,
            sprint: 2,
            quarterSprintStartDate: start,
            quarterSprintEndDate: end
        )
        #expect(tagged.quarter == 1)
        #expect(tagged.quarterSprintLabel == "Q1 · Sprint 2")
    }

    @Test("Quarter is derived from the sprint start month (calendar quarters)")
    func testQuarterDerivedFromMonth() {
        // Q1 = ene–mar, Q2 = abr–jun, Q3 = jul–sep, Q4 = oct–dic.
        #expect(RCCycle.quarter(for: makeDate(2026, 1, 1)) == 1)   // enero  -> Q1
        #expect(RCCycle.quarter(for: makeDate(2026, 3, 31)) == 1)  // marzo  -> Q1
        #expect(RCCycle.quarter(for: makeDate(2026, 4, 1)) == 2)   // abril  -> Q2
        #expect(RCCycle.quarter(for: makeDate(2026, 6, 30)) == 2)  // junio  -> Q2
        #expect(RCCycle.quarter(for: makeDate(2026, 7, 1)) == 3)   // julio  -> Q3
        #expect(RCCycle.quarter(for: makeDate(2026, 9, 30)) == 3)  // sept.  -> Q3
        #expect(RCCycle.quarter(for: makeDate(2026, 10, 1)) == 4)  // oct.   -> Q4
        #expect(RCCycle.quarter(for: makeDate(2026, 12, 31)) == 4) // dic.   -> Q4
    }

    @Test("Sprint is clamped to a minimum of 1")
    func testSprintClamping() {
        let start = makeDate(2026, 2, 1)
        let end = makeDate(2026, 2, 7)

        let cycle = RCCycle(
            title: "RC 1",
            startDate: start,
            endDate: end,
            quarterSprintEnabled: true,
            sprint: -3
        )
        #expect(cycle.sprint == 1)
    }

    @Test("Decoding legacy data without Quarter/Sprint fields keeps the feature disabled")
    func testBackwardCompatibleDecoding() throws {
        // JSON as produced by an older app version (no quarterSprint* keys).
        let legacyJSON = """
        {
            "id": "\(UUID().uuidString)",
            "title": "RC 5",
            "startDate": 758160000,
            "endDate": 758678399,
            "durationDays": 7
        }
        """
        let data = Data(legacyJSON.utf8)
        let cycle = try JSONDecoder().decode(RCCycle.self, from: data)

        #expect(cycle.title == "RC 5")
        #expect(cycle.quarterSprintEnabled == false)
        #expect(cycle.sprint == 1)
        #expect(cycle.quarterSprintLabel == nil)
        // El rango de Q/Sprint cae de vuelta al rango del RC cuando falta.
        #expect(cycle.quarterSprintStartDate == cycle.startDate)
        #expect(cycle.quarterSprintEndDate == cycle.endDate)
    }

    @Test("Quarter/Sprint keeps an independent date range from the RC")
    func testQuarterSprintIndependentRange() {
        let calendar = Calendar.current
        let rcStart = makeDate(2026, 1, 1)
        let rcEnd = makeDate(2026, 1, 7)
        // Sprint spans a wider, offset range than the RC.
        let qsStart = makeDate(2026, 1, 5)
        let qsEnd = makeDate(2026, 1, 20)

        let cycle = RCCycle(
            title: "RC 3",
            startDate: rcStart,
            endDate: rcEnd,
            quarterSprintEnabled: true,
            sprint: 2,
            quarterSprintStartDate: qsStart,
            quarterSprintEndDate: qsEnd
        )

        // RC range untouched by the Q/Sprint range.
        #expect(cycle.durationDays == 7)
        #expect(calendar.component(.day, from: cycle.startDate) == 1)
        // Independent Q/Sprint range preserved and normalized (end of day).
        #expect(calendar.component(.day, from: cycle.quarterSprintStartDate) == 5)
        #expect(calendar.component(.day, from: cycle.quarterSprintEndDate) == 20)
        #expect(calendar.component(.hour, from: cycle.quarterSprintEndDate) == 23)
        #expect(cycle.quarter == 1) // enero
    }

    @Test("Quarter/Sprint defaults its range to the RC range when unset")
    func testQuarterSprintRangeFallsBackToRC() {
        let start = makeDate(2026, 3, 1)
        let end = makeDate(2026, 3, 10)

        let cycle = RCCycle(title: "RC 1", startDate: start, endDate: end, quarterSprintEnabled: true)

        #expect(cycle.quarterSprintStartDate == cycle.startDate)
        #expect(cycle.quarterSprintEndDate == cycle.endDate)
        #expect(cycle.quarter == 1) // marzo -> Q1
    }

    @Test("Quarter/Sprint survives an encode/decode round trip")
    func testQuarterSprintRoundTrip() throws {
        let qsStart = makeDate(2026, 7, 6)  // julio -> Q3
        let qsEnd = makeDate(2026, 7, 19)
        let original = RCCycle(
            title: "RC 7",
            startDate: makeDate(2026, 7, 1),
            endDate: makeDate(2026, 7, 14),
            quarterSprintEnabled: true,
            sprint: 4,
            quarterSprintStartDate: qsStart,
            quarterSprintEndDate: qsEnd
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RCCycle.self, from: data)

        #expect(decoded.quarterSprintEnabled == true)
        #expect(decoded.quarter == 3)
        #expect(decoded.sprint == 4)
        #expect(decoded.quarterSprintLabel == "Q3 · Sprint 4")
        #expect(decoded.quarterSprintStartDate == original.quarterSprintStartDate)
        #expect(decoded.quarterSprintEndDate == original.quarterSprintEndDate)
    }

    // MARK: - Sprint auto-advance

    @Test("Sprint auto-advances when its range has expired, inheriting duration")
    func testSprintAutoAdvance() {
        let calendar = Calendar.current
        // Sprint de 7 días: 1–7 de enero.
        let cycle = RCCycle(
            title: "RC 1",
            startDate: makeDate(2026, 1, 1),
            endDate: makeDate(2026, 1, 7),
            quarterSprintEnabled: true,
            sprint: 1,
            quarterSprintStartDate: makeDate(2026, 1, 1),
            quarterSprintEndDate: makeDate(2026, 1, 7)
        )

        // Hoy es el 10 de enero: un solo periodo ha vencido.
        let advanced = cycle.advancingSprint(asOf: makeDate(2026, 1, 10))

        #expect(advanced.sprint == 2)
        #expect(calendar.component(.day, from: advanced.quarterSprintStartDate) == 8)  // 8 de enero
        #expect(calendar.component(.day, from: advanced.quarterSprintEndDate) == 14)   // 14 de enero
        #expect(advanced.quarter == 1)
    }

    @Test("Sprint catch-up processes several expired periods and updates the quarter")
    func testSprintAutoAdvanceCrossesQuarter() {
        // Sprint de 7 días arrancando el 20 de marzo (Q1).
        let cycle = RCCycle(
            title: "RC 1",
            startDate: makeDate(2026, 3, 20),
            endDate: makeDate(2026, 3, 26),
            quarterSprintEnabled: true,
            sprint: 1,
            quarterSprintStartDate: makeDate(2026, 3, 20),
            quarterSprintEndDate: makeDate(2026, 3, 26)
        )

        // Al 5 de abril han vencido dos periodos: 27-mar→2-abr y 3-abr→9-abr.
        let advanced = cycle.advancingSprint(asOf: makeDate(2026, 4, 5))

        #expect(advanced.sprint == 3)
        #expect(Calendar.current.component(.month, from: advanced.quarterSprintStartDate) == 4) // abril
        #expect(advanced.quarter == 2) // el sprint activo ya cayó en Q2
    }

    @Test("Sprint does not advance while today is within its range")
    func testSprintNoAdvanceWithinRange() {
        let cycle = RCCycle(
            title: "RC 1",
            startDate: makeDate(2026, 5, 1),
            endDate: makeDate(2026, 5, 14),
            quarterSprintEnabled: true,
            sprint: 3,
            quarterSprintStartDate: makeDate(2026, 5, 1),
            quarterSprintEndDate: makeDate(2026, 5, 14)
        )

        let same = cycle.advancingSprint(asOf: makeDate(2026, 5, 10))
        #expect(same == cycle)
        #expect(same.sprint == 3)
    }

    @Test("Sprint does not advance when the feature is disabled")
    func testSprintNoAdvanceWhenDisabled() {
        let cycle = RCCycle(
            title: "RC 1",
            startDate: makeDate(2026, 1, 1),
            endDate: makeDate(2026, 1, 7),
            quarterSprintEnabled: false,
            sprint: 1,
            quarterSprintStartDate: makeDate(2026, 1, 1),
            quarterSprintEndDate: makeDate(2026, 1, 7)
        )

        let unchanged = cycle.advancingSprint(asOf: makeDate(2026, 3, 1))
        #expect(unchanged == cycle)
        #expect(unchanged.sprint == 1)
    }
}
