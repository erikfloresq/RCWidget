# Contexto del proyecto RCWidget

## Qué es

RCWidget es una aplicación nativa para macOS que ayuda a seguir ciclos de Release Candidate. Está escrita en Swift 5 con SwiftUI y requiere macOS 26.4 o posterior. Incluye un dashboard, un `MenuBarExtra` opcional, un widget de escritorio/Centro de Notificaciones y un control del Centro de Control.

## Estructura

- `RCWidget/RCWidgetApp.swift`: punto de entrada, ventana Dashboard, menú de barra y políticas de activación/Dock.
- `RCWidget/ContentView.swift`: `RCCycleManager`, vistas del dashboard y menú de barra. Persiste los cambios y solicita la actualización de los timelines de WidgetKit.
- `RCShared/RCCycle.swift`: modelo `Codable` del ciclo, normalización de fechas, progreso y avance de sprint. Este código se compila en la app y en la extensión.
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

## Cambios y comprobaciones

- Mantener la lógica de fechas y rollover en `RCShared` para que la app y extensión sigan las mismas reglas.
- Al cambiar persistencia, revisar compatibilidad del App Group y migración; no cambiar identificadores guardados sin una migración deliberada.
- Al añadir textos visibles, actualizar los String Catalogs en español e inglés.
- El proyecto Xcode es `RCWidget.xcodeproj`; targets: `RCWidget`, `RCWidgetExtension`, `RCWidgetTests` y `RCWidgetUITests`. No hay dependencias de paquetes declaradas en el proyecto.
- Para cambios funcionales, ejecutar las pruebas pertinentes con Xcode cuando el usuario solicite verificación o la tarea lo requiera. Las pruebas existentes usan Swift Testing (`import Testing`).

