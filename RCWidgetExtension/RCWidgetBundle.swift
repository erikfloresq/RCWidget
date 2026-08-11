//
//  RCWidgetBundle.swift
//  RCWidgetExtension
//
//  Punto de entrada de la extensión. Agrupa el widget de escritorio /
//  Centro de Notificaciones y el control del Centro de Control.
//

import WidgetKit
import SwiftUI

@main
struct RCWidgetBundle: WidgetBundle {
    var body: some Widget {
        RCProgressWidget()
        RCStatusControl()
    }
}
