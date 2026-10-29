# Contexto del proyecto RCWidget

## Qué es

RCWidget es una aplicación nativa para macOS que ayuda a seguir ciclos de Release Candidate. Está escrita en modo de lenguaje Swift 6, usa SwiftUI y requiere macOS 26.4 o posterior. Incluye un dashboard, un `MenuBarExtra` opcional, un widget de escritorio/Centro de Notificaciones y un control del Centro de Control.

## Estructura

- `RCWidget/RCWidgetApp.swift`: punto de entrada, ventana Dashboard, menú de barra y políticas de activación/Dock.
- `RCWidget/ContentView.swift`: `RCCycleManager` aislado a `MainActor`, vistas del dashboard y menú de barra. Persiste los cambios y solicita la actualización de los timelines de WidgetKit.
- `RCShared/RCCycle.swift`: modelo `Codable` y `Sendable` del ciclo, normalización de fechas, progreso y avance de sprint. Este código se compila en la app y en la extensión.
- `RCShared/RCRollover.swift`: lógica determinística de rollover/catch-up, título siguiente, archivo de ciclos vencidos y helper de persistencia compartida. Mantenerla independiente de UI/IO salvo el helper explícito `advanceStoredCycle`.
- `RCShared/RCStore.swift`: persistencia `Codable` en `UserDefaults` del App Group y migración de los datos antiguos desde `UserDefaults.standard`.
- `RCWidgetExtension/`: implementación de WidgetKit y control del Centro de Control; ambos consumen la lógica/modelo compartidos.
- `RCWidgetTests/`: pruebas de modelo, rollover, persistencia y refresco del widget. `RCWidgetUITests/`: pruebas de interfaz.
- `*.xcstrings`: catálogos de localización. Español es el idioma principal; también se mantiene inglés.
- `README.md`: descripción funcional amplia, capturas y guía de ejecución.

## Modelo y reglas que conviene preservar

- El ciclo activo y el historial se comparten con la extensión mediante el App Group `group.dev.erikfloresq.RCWidget`. Los identificadores de widget/control están definidos en `RCStore`.
- Los días del ciclo son inclusivos. El inicio se normaliza a medianoche y el final al último segundo del día. Si cambia esta regla, revisar progreso, rollover y pruebas de fechas.
- Cuando vence un ciclo, se archiva una copia en el historial; el siguiente hereda la duración y se crea desde el día posterior. `RCRollover.advance` hace catch-up si vencieron varios ciclos.
- Quarter/Sprint es opcional y tiene rango de fechas independiente del RC. El quarter se deriva del mes de inicio del sprint; el sprint avanza sin agregar entradas al historial de RC.
- App, widget y control pueden ejecutarse en momentos distintos. El widget/control deben usar el helper compartido de rollover para no mostrar ciclos vencidos cuando la app está cerrada.
- Los campos nuevos de `RCCycle` deben decodificarse con valores por defecto cuando sea necesario para conservar compatibilidad con datos guardados por versiones previas.

## Swift 6 y concurrencia

- Los cuatro targets (`RCWidget`, `RCWidgetExtension`, `RCWidgetTests` y `RCWidgetUITests`) usan `SWIFT_VERSION = 6.0`; el proyecto se compila con un toolchain Swift 6.2. Mantenerlo así al modificar configuraciones Debug/Release.
- La app conserva sus ajustes `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY = YES`. No extender el aislamiento global a la extensión o a los tests sin revisar las consecuencias en código compartido.
- El estado de UI y `RCCycleManager` pertenecen a `MainActor`. Los modelos y resultados de lógica compartida que cruzan límites de aislamiento deben ser valores `Sendable`.
- `AppDelegate.userDefaultsChanged()` es un callback `nonisolated`: `UserDefaults.didChangeNotification` puede entregarse en el hilo que publica la notificación. Debe saltar a `MainActor` antes de acceder a AppKit o cambiar la política de activación.
- Preferir corregir el aislamiento en el origen. No usar `@unchecked Sendable`, `nonisolated(unsafe)` ni `@preconcurrency` como atajos; cualquier excepción necesitaría una invariancia de seguridad documentada y un plan para eliminarla.
- Las propiedades estáticas de metadatos de `AppIntent` deben ser constantes cuando el protocolo lo permita, evitando estado global mutable.

## Cambios y comprobaciones

- Mantener la lógica de fechas y rollover en `RCShared` para que la app y extensión sigan las mismas reglas.
- Al cambiar persistencia, revisar compatibilidad del App Group y migración; no cambiar identificadores guardados sin una migración deliberada.
- Al añadir textos visibles, actualizar los String Catalogs en español e inglés.
- El proyecto Xcode es `RCWidget.xcodeproj`; targets: `RCWidget`, `RCWidgetExtension`, `RCWidgetTests` y `RCWidgetUITests`. No hay dependencias de paquetes declaradas en el proyecto.
- Para cambios funcionales, ejecutar las pruebas pertinentes con Xcode cuando el usuario solicite verificación o la tarea lo requiera. Las pruebas existentes usan Swift Testing (`import Testing`).
- La suite principal de pruebas (`RCWidget`) cubre 33 pruebas de modelo, rollover y persistencia. El scheme compartido principal no incluye `RCWidgetUITests`; compilar ese target aparte y no interpretar un fallo de arranque del runner como fallo de aserciones.

