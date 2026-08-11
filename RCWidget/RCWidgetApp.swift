//
//  RCWidgetApp.swift
//  RCWidget
//
//  Created by Erik Flores on 23/5/26.
//

import SwiftUI

// MARK: - App Delegate

/// Controla si la app termina al cerrar su última ventana. Cuando el icono de
/// la barra de menús está activo, la app sigue viva en segundo plano (en el
/// menu bar); si está desactivado, se cierra de forma normal.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Alinea el valor "crudo" de UserDefaults con el default de @AppStorage.
        UserDefaults.standard.register(defaults: ["showMenuBarItem": true])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Si el menu bar está activo, no terminar al cerrar la ventana.
        !UserDefaults.standard.bool(forKey: "showMenuBarItem")
    }
}

@main
struct RCWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = RCCycleManager()
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true

    var body: some Scene {
        // Main Dashboard window scene
        Window("RC Dashboard", id: "dashboard") {
            DashboardView(manager: manager)
                .frame(minWidth: 720, minHeight: 520)
        }

        // Native interactive Menu Bar status item widget.
        // Its visibility is controlled by the "showMenuBarItem" preference.
        MenuBarExtra(isInserted: $showMenuBarItem) {
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
