//
//  RCStatusControl.swift
//  RCWidgetExtension
//
//  Control del Centro de Control (macOS 26): muestra el ciclo RC activo
//  de forma compacta y abre la app al pulsarlo.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent para abrir la app

struct RCOpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir RCWidget"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Valor dinámico del control

struct RCControlValue {
    let title: String
    let subtitle: String
}

struct RCControlValueProvider: ControlValueProvider {
    var previewValue: RCControlValue {
        RCControlValue(title: "RC 1", subtitle: String(localized: "Día \(1) de \(7)"))
    }

    func currentValue() async throws -> RCControlValue {
        // Aplica rollover si el ciclo activo ya venció (la app puede llevar
        // horas cerrada). Sin esto, el control mostraba el ciclo caducado.
        let cycle = RCRollover.advanceStoredCycle(now: Date())
        let dayText = String(localized: "Día \(cycle.daysElapsed()) de \(cycle.durationDays)")
        let subtitle: String
        if let qsLabel = cycle.quarterSprintLabel {
            subtitle = "\(qsLabel) · \(dayText)"
        } else {
            subtitle = dayText
        }
        return RCControlValue(title: cycle.title, subtitle: subtitle)
    }
}

// MARK: - Control

struct RCStatusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: RCStore.controlKind, provider: RCControlValueProvider()) { value in
            ControlWidgetButton(action: RCOpenAppIntent()) {
                Label(value.title, systemImage: "calendar.badge.clock")
                Text(value.subtitle)
            }
        }
        .displayName("RC Tracker")
        .description("Muestra el ciclo activo y abre RCWidget.")
    }
}
