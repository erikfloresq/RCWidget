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
}
