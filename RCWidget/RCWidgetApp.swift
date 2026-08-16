//
//  RCWidgetApp.swift
//  RCWidget
//
//  Created by Erik Flores on 23/5/26.
//

import SwiftUI

// MARK: - App Delegate

/// Aplica dos preferencias de comportamiento de aplicación:
///
/// - `showMenuBarItem`: si el icono de la barra de menús está activo, la app
///   sigue viva al cerrar la última ventana. Si no, termina de forma normal.
/// - `hideDockIcon`: cuando el menu bar está activo, permite ocultar el icono
///   del Dock (y sacar la app del Cmd+Tab) cambiando la activation policy a
///   `.accessory`. Si el usuario apaga el menu bar, la policy se fuerza a
///   `.regular` automáticamente para no dejar la app sin punto de entrada.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Alinea los valores "crudos" de UserDefaults con los defaults de
        // @AppStorage para que la primera lectura antes del primer set sea
        // correcta (evita parpadeos al lanzar).
        UserDefaults.standard.register(defaults: [
            "showMenuBarItem": true,
            "hideDockIcon": false
        ])
        applyActivationPolicy()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Si el menu bar está activo, no terminar al cerrar la ventana.
        !UserDefaults.standard.bool(forKey: "showMenuBarItem")
    }

    @objc private func userDefaultsChanged() {
        applyActivationPolicy()
    }

    /// Ajusta la activation policy según las preferencias actuales.
    /// Ocultar el Dock sólo se aplica si el menu bar sigue activo — en caso
    /// contrario la app quedaría inaccesible sin ventana ni icono.
    private func applyActivationPolicy() {
        let menuBarActive = UserDefaults.standard.bool(forKey: "showMenuBarItem")
        let hideDock = UserDefaults.standard.bool(forKey: "hideDockIcon")
        let target: NSApplication.ActivationPolicy = (menuBarActive && hideDock)
            ? .accessory
            : .regular
        guard NSApp.activationPolicy() != target else { return }
        NSApp.setActivationPolicy(target)
        if target == .regular {
            // Al volver de accessory a regular, la app estaba fuera del Dock
            // y del Cmd+Tab; reactivarla trae su ventana al frente.
            NSApp.activate(ignoringOtherApps: true)
        }
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
