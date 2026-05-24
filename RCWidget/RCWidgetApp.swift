//
//  RCWidgetApp.swift
//  RCWidget
//
//  Created by Erik Flores on 23/5/26.
//

import SwiftUI

@main
struct RCWidgetApp: App {
    @StateObject private var manager = RCCycleManager()
    
    var body: some Scene {
        // Main Dashboard window scene
        Window("RC Dashboard", id: "dashboard") {
            DashboardView(manager: manager)
                .frame(minWidth: 720, minHeight: 520)
        }
        
        // Native interactive Menu Bar status item widget
        MenuBarExtra {
            MenuBarWidgetView(manager: manager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                Text(manager.activeCycle.title)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
