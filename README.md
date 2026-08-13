# 🗓️ RCWidget - macOS Release Candidate Cycle Tracker

`RCWidget` es una aplicación nativa para macOS diseñada específicamente para desarrolladores y equipos de producto que necesitan monitorear y gestionar los ciclos de **Release Candidate (RC)**. Desarrollada con **SwiftUI** y **WidgetKit**, ofrece una experiencia visualmente cuidada e integrada de forma nativa en el ecosistema de macOS.

La aplicación consta de cuatro componentes: un **Dashboard de Configuración** completo, un **Widget de WidgetKit** para el escritorio y el Centro de Notificaciones (con el diseño del anillo glassmórfico), un **Control del Centro de Control** para acceso rápido, y un **Widget de Barra de Menús** opcional (activable/desactivable desde el Dashboard).

---

## 📸 Capturas de Pantalla

> ⚠️ Algunas capturas corresponden a la versión anterior (widget flotante y barra de menús) y serán reemplazadas por el nuevo widget de WidgetKit.

### 1. Dashboard de Configuración
Un completo centro de control para configurar tus ciclos activos y visualizar el historial de RCs completadas.

![Dashboard de Configuración](screenshots/dashboard_view.png)

### 2. Widget de Escritorio (WidgetKit)
Widget nativo con el diseño del anillo de progreso glassmórfico, disponible en tamaños pequeño y mediano para el escritorio y el Centro de Notificaciones.

![Widget de Escritorio](screenshots/desktop_widget.png)

---

## 🚀 Características Principales (Features)

### 1. Dashboard de Control Centralizado (`DashboardView`)
*   **Monitoreo del Ciclo Activo:** Tarjeta de resumen premium que muestra el progreso del ciclo actual en tiempo real mediante una barra de progreso lineal degradada en tonos cian y azul.
*   **Editor Dinámico de Ciclo:** Formulario reactivo para configurar el nombre del ciclo, la fecha de inicio y de término mediante selectores de fecha nativos de macOS (`DatePicker`).
*   **Cálculo de Duración en Vivo:** Calcula e informa la duración total en días a medida que modificas las fechas, validando en tiempo real que la fecha de término sea posterior a la de inicio.
*   **Quarter y Sprint Opcionales con Rango Propio:** Para equipos que trabajan con sprints en paralelo dentro de un trimestre, un toggle opcional (desactivado por defecto) permite indicar el número de **Quarter** (Q1–Q4) y el número de **Sprint**, junto con su **propio rango de fechas independiente del RC** (el sprint suele correr en paralelo y no coincidir con el ciclo de Release Candidate). Al activarlo se muestra una etiqueta tipo `Q1 · Sprint 2` junto al RC activo en el Dashboard, el widget de barra de menús, el widget de escritorio y el Centro de Control. Los valores se heredan automáticamente en los rollovers de ciclo.
*   **Dashboard con Scroll:** La columna de configuración es desplazable, de modo que todo el contenido sigue accesible incluso cuando la ventana es pequeña.
*   **Historial y Archivo Automático:** Un panel derecho que recopila y muestra de forma cronológica inversa todos los ciclos finalizados con un check verde de completado, su rango de fechas y la duración total. Cuenta con la opción de limpiar el historial cuando se desee.
*   **Preferencias:** Toggle para mostrar u ocultar el icono de la barra de menús, más una guía para añadir el widget al escritorio y el control al Centro de Control.

### 2. Widget de WidgetKit para Escritorio y Centro de Notificaciones (`RCProgressWidget`)
*   **Extensión Nativa de WidgetKit:** Corre en su propio proceso (`RCWidgetExtension`) y comparte los datos del ciclo con la app mediante un **App Group** (`group.dev.erikfloresq.RCWidget`).
*   **Diseño del Anillo Glassmórfico:** Reutiliza el medidor circular con degradado dinámico (Cian ➡️ Azul ➡️ Púrpura) que ilustra el porcentaje completado del ciclo.
*   **Tamaños Pequeño y Mediano:** El tamaño pequeño muestra el anillo; el mediano añade barra de progreso lineal, días transcurridos y tiempo restante.
*   **Timeline Actualizada:** Genera entradas horarias para mantener frescos el contador de días, la barra de progreso y el texto de tiempo restante. La app llama a `WidgetCenter.reloadAllTimelines()` cada vez que cambian los datos.

### 3. Control del Centro de Control (`RCStatusControl`)
*   **ControlWidget Nativo:** Aparece en el Centro de Control de macOS mostrando el ciclo activo y el día actual mediante un `ControlValueProvider`.
*   **Acción Rápida:** Al pulsarlo ejecuta un `AppIntent` (`openAppWhenRun`) que abre la app RCWidget directamente en el Dashboard.

### 4. Widget de Barra de Menús Opcional (`MenuBarWidgetView`)
*   **Status Item Nativo:** `MenuBarExtra` que muestra un icono de calendario con el título corto del ciclo activo (ej: `RC 1`).
*   **Dropdown Interactivo:** Información del ciclo, barra de progreso, **Forzar Siguiente Ciclo**, acceso al Dashboard y salida de la app.
*   **Activable/Desactivable:** Se muestra u oculta desde el toggle de preferencias del Dashboard (persistido con `@AppStorage` vía `MenuBarExtra(isInserted:)`).

### 4. Automatización Inteligente y Lógica "Catch-Up"
*   **Auto-Rollover de Ciclos:** Una vez que la fecha de término del ciclo activo expira, la aplicación archiva automáticamente el ciclo completado en el historial de forma permanente.
*   **Auto-Incremento de Título por Regex:** Utiliza expresiones regulares (`NSRegularExpression`) para detectar números al final del título (ej: `"RC 1"`) y los incrementa matemáticamente a la siguiente iteración (ej: `"RC 2"`), manteniendo intacto el prefijo de texto.
*   **Herencia de Duración:** El ciclo nuevo hereda exactamente la duración en días establecida por el usuario en el ciclo anterior, calculando de manera inteligente su nueva fecha de inicio y término a partir del día siguiente de la expiración.
*   **Loop de Puesta al Día (Catch-Up Loop):** Si el usuario pasa semanas sin abrir la aplicación, un algoritmo cronometrado ejecuta un catch-up en bucle al iniciar para procesar, archivar en secuencia cronológica todos los ciclos que debieron haber transcurrido en ese período, y establecer el ciclo activo en la fecha y número correctos.

---

## 🛠️ Stack Tecnológico

*   **Lenguaje:** Swift 5
*   **Framework de Interfaz:** SwiftUI (vistas reactivas, `MenuBarExtra`, gradientes y animaciones) con AppKit puntual (`NSApp`)
*   **Widgets:** WidgetKit (`Widget`, `TimelineProvider`) y Control Center (`ControlWidget`, `AppIntents`)
*   **Datos Compartidos:** App Group + `UserDefaults(suiteName:)` con serialización `Codable` para compartir los ciclos entre la app y la extensión.
*   **Reactividad:** Combine (`Timer.publish`, `@Published`, `ObservableObject`)
*   **Localización:** String Catalogs (`.xcstrings`) en **español** (idioma base) e **inglés**, con fechas y duraciones formateadas según el locale del sistema (`Date.FormatStyle`, `DateComponentsFormatter`).
*   **Compatibilidad:** macOS 26 o superior

---

## 📥 Instrucciones de Ejecución y Desarrollo

1.  Asegúrate de contar con un equipo con **macOS 26+** y **Xcode 26+** instalado.
2.  Clona el repositorio en tu máquina local:
    ```bash
    git clone https://github.com/erikfloresq/RCWidget.git
    cd RCWidget
    ```
3.  Abre el archivo de proyecto en Xcode:
    ```bash
    open RCWidget.xcodeproj
    ```
4.  Selecciona el target **RCWidget** y haz clic en **Run** (`Cmd + R`). Xcode registrará automáticamente el App Group y los perfiles de firma.
5.  Configura tu ciclo en el Dashboard. Luego:
    *   **Widget de escritorio:** clic derecho en el escritorio → **Editar widgets** → busca **RCWidget** y arrástralo al escritorio o al Centro de Notificaciones.
    *   **Centro de Control:** abre el Centro de Control → **Editar controles** → añade el control **RC Tracker**.

---

## 🌟 Créditos y Licencia

Diseñado e implementado con pasión para macOS. Licencia MIT. Desarrollado por **Erik Flores**.
