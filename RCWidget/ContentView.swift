//
//  ContentView.swift
//  RCWidget
//
//  Created by Erik Flores on 23/5/26.
//

import SwiftUI
import AppKit
import Combine

// MARK: - 1. DATA MODEL

struct RCCycle: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var durationDays: Int
    
    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date, durationDays: Int? = nil) {
        self.id = id
        self.title = title
        
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        self.startDate = start
        
        // Ensure endDate is at least the startDate
        let finalEnd = end < start ? start : end
        
        // Set end date to the end of that day (23:59:59)
        var endComponents = calendar.dateComponents([.year, .month, .day], from: finalEnd)
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        self.endDate = calendar.date(from: endComponents) ?? finalEnd
        
        if let duration = durationDays {
            self.durationDays = duration
        } else {
            let components = calendar.dateComponents([.day], from: start, to: finalEnd)
            self.durationDays = max(1, (components.day ?? 0) + 1)
        }
    }
}

// MARK: - 2. CYCLE MANAGER

class RCCycleManager: ObservableObject {
    @Published var activeCycle: RCCycle {
        didSet {
            saveToUserDefaults()
        }
    }
    
    @Published var pastCycles: [RCCycle] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    @Published var showDesktopWidget: Bool {
        didSet {
            saveSettings()
            toggleDesktopWidget()
        }
    }
    
    @Published var menuBarOnly: Bool {
        didSet {
            saveSettings()
            updateActivationPolicy()
        }
    }
    
    // Internal timer to trigger UI updates and verify expirations
    private var timer: AnyCancellable?
    
    init() {
        // Load settings
        self.showDesktopWidget = UserDefaults.standard.bool(forKey: "showDesktopWidget")
        self.menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnly")
        
        // Load active cycle
        if let data = UserDefaults.standard.data(forKey: "activeCycle"),
           let cycle = try? JSONDecoder().decode(RCCycle.self, from: data) {
            self.activeCycle = cycle
        } else {
            // Default first cycle (7 days starting today)
            let today = Date()
            let calendar = Calendar.current
            let end = calendar.date(byAdding: .day, value: 6, to: today) ?? today
            self.activeCycle = RCCycle(title: "RC 1", startDate: today, endDate: end, durationDays: 7)
        }
        
        // Load past cycles
        if let data = UserDefaults.standard.data(forKey: "pastCycles"),
           let cycles = try? JSONDecoder().decode([RCCycle].self, from: data) {
            self.pastCycles = cycles
        } else {
            self.pastCycles = []
        }
        
        // Save initial values if they were generated
        saveToUserDefaults()
        
        // Dynamic Activation Policy setup
        DispatchQueue.main.async {
            self.updateActivationPolicy()
            self.toggleDesktopWidget()
        }
        
        // Auto check expiration and refresh UI
        self.checkAndProgressCycle()
        
        self.timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndProgressCycle()
                self?.objectWillChange.send() // Forces dynamic progress bars to tick
            }
    }
    
    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(activeCycle) {
            UserDefaults.standard.set(data, forKey: "activeCycle")
        }
        if let data = try? JSONEncoder().encode(pastCycles) {
            UserDefaults.standard.set(data, forKey: "pastCycles")
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(showDesktopWidget, forKey: "showDesktopWidget")
        UserDefaults.standard.set(menuBarOnly, forKey: "menuBarOnly")
    }
    
    // Dynamic update policy (dock icon visible or accessory agent)
    func updateActivationPolicy() {
        if menuBarOnly {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    func toggleDesktopWidget() {
        if showDesktopWidget {
            DesktopWindowManager.shared.show(manager: self)
        } else {
            DesktopWindowManager.shared.hide()
        }
    }
    
    // Calculate inclusive days between two dates
    private func daysBetweenInclusive(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return max(1, (components.day ?? 0) + 1)
    }
    
    // Core auto-increment text rollover logic
    func incrementTitle(_ title: String) -> String {
        let pattern = #"(.*?)\s*(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
            
            let titleRange = match.range(at: 1)
            let numberRange = match.range(at: 2)
            
            if let titleSub = Range(titleRange, in: title),
               let numberSub = Range(numberRange, in: title),
               let currentNum = Int(title[numberSub]) {
                let baseTitle = title[titleSub].trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(baseTitle) \(currentNum + 1)"
            }
        }
        return "\(title) 2"
    }
    
    // Verification & Automatic catch up loop
    func checkAndProgressCycle() {
        let calendar = Calendar.current
        var updated = false
        let todayStart = calendar.startOfDay(for: Date())
        
        while true {
            let endDateStart = calendar.startOfDay(for: activeCycle.endDate)
            // Next cycle starts the day after current active cycle end date
            guard let nextCycleStart = calendar.date(byAdding: .day, value: 1, to: endDateStart) else { break }
            
            // If today is equal to or past nextCycleStart, active cycle has finished!
            if todayStart >= nextCycleStart {
                // Save current active cycle to history
                let completedCycle = RCCycle(
                    id: activeCycle.id,
                    title: activeCycle.title,
                    startDate: activeCycle.startDate,
                    endDate: activeCycle.endDate,
                    durationDays: activeCycle.durationDays
                )
                pastCycles.append(completedCycle)
                
                // Roll over
                let nextTitle = incrementTitle(activeCycle.title)
                let nextDuration = activeCycle.durationDays // Inherit duration
                
                let nextStart = nextCycleStart
                
                // End date is nextStart + duration - 1 day
                var components = DateComponents()
                components.day = nextDuration - 1
                components.hour = 23
                components.minute = 59
                components.second = 59
                
                guard let nextEnd = calendar.date(byAdding: components, to: nextStart) else { break }
                
                activeCycle = RCCycle(id: UUID(), title: nextTitle, startDate: nextStart, endDate: nextEnd, durationDays: nextDuration)
                updated = true
            } else {
                break
            }
        }
        
        if updated {
            saveToUserDefaults()
            objectWillChange.send()
        }
    }
    
    // Updates active cycle with manual configuration
    func updateActiveCycle(title: String, startDate: Date, endDate: Date) {
        let calendar = Calendar.current
        let cleanedStart = calendar.startOfDay(for: startDate)
        
        // Ensure end date is at least start date
        let rawEnd = endDate < cleanedStart ? cleanedStart : endDate
        let cleanedEnd = endOfDay(for: rawEnd)
        
        let duration = daysBetweenInclusive(start: cleanedStart, end: cleanedEnd)
        
        activeCycle.title = title
        activeCycle.startDate = cleanedStart
        activeCycle.endDate = cleanedEnd
        activeCycle.durationDays = duration
        
        saveToUserDefaults()
        
        // Immediately run catch-up loop in case new range is already expired
        checkAndProgressCycle()
        
        // Notify views
        objectWillChange.send()
    }
    
    // Forces immediately rolling over to next cycle manually (useful for testing)
    func forceSkipToNextCycle() {
        let calendar = Calendar.current
        
        // Active cycle finishes now
        let completedCycle = RCCycle(
            id: activeCycle.id,
            title: activeCycle.title,
            startDate: activeCycle.startDate,
            endDate: activeCycle.endDate,
            durationDays: activeCycle.durationDays
        )
        pastCycles.append(completedCycle)
        
        // Next starts today
        let todayStart = calendar.startOfDay(for: Date())
        let nextTitle = incrementTitle(activeCycle.title)
        let nextDuration = activeCycle.durationDays
        
        var components = DateComponents()
        components.day = nextDuration - 1
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        let nextEnd = calendar.date(byAdding: components, to: todayStart) ?? todayStart
        
        activeCycle = RCCycle(id: UUID(), title: nextTitle, startDate: todayStart, endDate: nextEnd, durationDays: nextDuration)
        
        saveToUserDefaults()
        objectWillChange.send()
    }
    
    func clearHistory() {
        pastCycles.removeAll()
        saveToUserDefaults()
    }
    
    func resetAll() {
        let today = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 6, to: today) ?? today
        activeCycle = RCCycle(title: "RC 1", startDate: today, endDate: end, durationDays: 7)
        pastCycles.removeAll()
        saveToUserDefaults()
        objectWillChange.send()
    }
    
    // Helper to get end of day
    private func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: start) ?? date
    }
    
    // Dynamic Properties
    
    var daysElapsed: Int {
        let today = Calendar.current.startOfDay(for: Date())
        if today < Calendar.current.startOfDay(for: activeCycle.startDate) {
            return 0
        }
        if today > Calendar.current.startOfDay(for: activeCycle.endDate) {
            return activeCycle.durationDays
        }
        let elapsed = daysBetweenInclusive(start: activeCycle.startDate, end: today)
        return min(activeCycle.durationDays, max(1, elapsed))
    }
    
    var progress: Double {
        let now = Date()
        let start = activeCycle.startDate
        let end = activeCycle.endDate
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0.0 }
        let elapsed = now.timeIntervalSince(start)
        return max(0.0, min(1.0, elapsed / total))
    }
    
    var timeRemainingText: String {
        let now = Date()
        let end = activeCycle.endDate
        
        if now > end {
            return "¡Ciclo Completado!"
        }
        
        let remaining = end.timeIntervalSince(now)
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if days > 0 {
            if hours > 0 {
                return "Quedan \(days) \(days == 1 ? "día" : "días") y \(hours) \(hours == 1 ? "hora" : "horas")"
            } else {
                return "Quedan \(days) \(days == 1 ? "día" : "días")"
            }
        } else if hours > 0 {
            return "Quedan \(hours) \(hours == 1 ? "hora" : "horas") y \(minutes) \(minutes == 1 ? "min" : "mins")"
        } else if minutes > 0 {
            return "Quedan \(minutes) \(minutes == 1 ? "minuto" : "minutos")"
        } else {
            return "Quedan unos segundos"
        }
    }
}

// MARK: - 3. DESKTOP WINDOW MANAGER & CUSTOM APPKIT COMPONENTS

class DesktopWindow: NSWindow {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 220, height: 220),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.level = .floating // Float above normal windows, stays accessible
        self.isMovableByWindowBackground = true // Click & drag anywhere!
        
        self.contentView = contentView
        
        // Ensure it follows across virtual desktops (spaces)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

class DesktopWindowManager {
    static let shared = DesktopWindowManager()
    private var window: DesktopWindow?
    
    func show(manager: RCCycleManager) {
        if window != nil {
            window?.orderFront(nil)
            return
        }
        
        let view = DesktopWidgetView(manager: manager)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 220, height: 220)
        
        let win = DesktopWindow(contentView: hostingView)
        
        // Restore position
        if let savedFrame = UserDefaults.standard.string(forKey: "desktopWidgetFrame") {
            win.setFrame(from: savedFrame)
        } else {
            // Top Right default placement
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.maxX - 240
                let y = screenRect.maxY - 240
                win.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: win
        )
        
        win.orderFront(nil)
        self.window = win
    }
    
    func hide() {
        if let win = window {
            UserDefaults.standard.set(win.frameDescriptor, forKey: "desktopWidgetFrame")
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: win)
            win.close()
            window = nil
        }
    }
    
    @objc private func windowDidMove(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            UserDefaults.standard.set(win.frameDescriptor, forKey: "desktopWidgetFrame")
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 4. DESKTOP WIDGET VIEW (GLASSMORPHIC)

struct DesktopWidgetView: View {
    @ObservedObject var manager: RCCycleManager
    @State private var isHovering = false
    
    let gradientColors = [Color.cyan, Color.blue, Color.purple]
    
    var body: some View {
        VStack(spacing: 12) {
            // Custom bar with micro icons
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("RC TRACKER")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                }
                
                Spacer()
                
                if isHovering {
                    Button(action: {
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.windows.first(where: { $0.title == "RC Dashboard" }) {
                            window.makeKeyAndOrderFront(nil)
                        } else {
                            // Deep link fallback or dynamic window display trigger
                            NotificationCenter.default.post(name: NSNotification.Name("OpenDashboardWindow"), object: nil)
                        }
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 2)
            
            // Premium Ring progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(manager.progress))
                    .stroke(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: manager.progress)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 5, x: 0, y: 3)
                
                VStack(spacing: 2) {
                    Text(manager.activeCycle.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Text("Día \(manager.daysElapsed) de \(manager.activeCycle.durationDays)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
            }
            .frame(width: 115, height: 115)
            
            // Dynamic text status
            VStack(spacing: 3) {
                Text(manager.timeRemainingText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(formatDate(manager.activeCycle.startDate)) - \(formatDate(manager.activeCycle.endDate))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .frame(width: 220, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.2))
                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).cornerRadius(24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.05), Color.black.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMM"
        return formatter.string(from: date)
    }
}

// MARK: - 5. MENU BAR DROPDOWN WIDGET VIEW

struct MenuBarWidgetView: View {
    @ObservedObject var manager: RCCycleManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // Widget Header Area
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Release Candidate".uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.cyan)
                        .tracking(1.5)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Activo")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
                }
                
                Text(manager.activeCycle.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(formatDate(manager.activeCycle.startDate)) - \(formatDate(manager.activeCycle.endDate))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(manager.activeCycle.durationDays) días")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                }
            }
            .padding(16)
            
            // Linear Progress Bar section
            VStack(spacing: 8) {
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(manager.progress)), height: 8)
                            .shadow(color: Color.cyan.opacity(0.4), radius: 3)
                    }
                }
                .frame(height: 8)
                
                // Days elapsed and time remaining
                HStack {
                    Text("Día \(manager.daysElapsed) de \(manager.activeCycle.durationDays)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(manager.timeRemainingText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // List of interactive actions
            VStack(spacing: 4) {
                // Toggle Desktop Widget
                Button(action: {
                    withAnimation {
                        manager.showDesktopWidget.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: manager.showDesktopWidget ? "desktopcomputer" : "macwindow")
                            .frame(width: 16)
                        Text(manager.showDesktopWidget ? "Ocultar Widget de Escritorio" : "Mostrar Widget de Escritorio")
                        Spacer()
                        if manager.showDesktopWidget {
                            Image(systemName: "checkmark")
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
                
                // Manual Rollover
                Button(action: {
                    manager.forceSkipToNextCycle()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.to.line.compact")
                            .frame(width: 16)
                        Text("Forzar Siguiente Ciclo (Rollover)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
                
                // Open full dashboard settings
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 16)
                        Text("Abrir Dashboard de Configuración")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 2)
                
                // Exit app
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                            .frame(width: 16)
                            .foregroundColor(.red.opacity(0.8))
                        Text("Salir de RCWidget")
                            .foregroundColor(.red.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
            }
            .padding(6)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM, yyyy"
        return formatter.string(from: date)
    }
}

struct MenuBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
    }
}

// MARK: - 6. DASHBOARD & SETTINGS VIEW

struct DashboardView: View {
    @ObservedObject var manager: RCCycleManager
    
    // Editing States
    @State private var editTitle: String = ""
    @State private var editStartDate: Date = Date()
    @State private var editEndDate: Date = Date()
    @State private var hasUnsavedChanges: Bool = false
    
    init(manager: RCCycleManager) {
        self.manager = manager
        // We will synchronize initial editing states on appear, to keep it modular.
    }
    
    var computedDuration: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: editStartDate)
        let end = calendar.startOfDay(for: editEndDate)
        if end < start { return 1 }
        let components = calendar.dateComponents([.day], from: start, to: end)
        return (components.day ?? 0) + 1
    }
    
    var body: some View {
        HSplitView {
            // LEFT COLUMN: Controls & Editing Form
            VStack(alignment: .leading, spacing: 20) {
                // Header Title
                HStack(alignment: .center) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 26))
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RCWidget")
                            .font(.system(size: 20, weight: .black))
                        Text("Control y Monitoreo del Ciclo de Release Candidates")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 5)
                
                // Card for Active Status Summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CICLO ACTIVO")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.cyan.opacity(0.8))
                            .tracking(1)
                        Spacer()
                        Text("En curso")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(5)
                    }
                    
                    Text(manager.activeCycle.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    // Linear Progress Indicator
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * CGFloat(manager.progress)), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text("Día \(manager.daysElapsed) de \(manager.activeCycle.durationDays)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(manager.timeRemainingText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text("Rango: \(formatFullDate(manager.activeCycle.startDate)) al \(formatFullDate(manager.activeCycle.endDate))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                
                // Form: Edit Current Active Cycle
                VStack(alignment: .leading, spacing: 14) {
                    Text("CONFIGURACIÓN DEL CICLO")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre / Texto del Ciclo")
                            .font(.system(size: 11, weight: .bold))
                        TextField("Ej: RC 1", text: $editTitle)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editTitle) { _ in checkForChanges() }
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fecha Inicio")
                                .font(.system(size: 11, weight: .bold))
                            DatePicker("", selection: $editStartDate, displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: editStartDate) { _ in checkForChanges() }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fecha Término")
                                .font(.system(size: 11, weight: .bold))
                            DatePicker("", selection: $editEndDate, displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: editEndDate) { _ in checkForChanges() }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Duración")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(computedDuration) días")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                        .padding(.top, 16)
                    }
                    
                    HStack {
                        Button(action: {
                            manager.updateActiveCycle(
                                title: editTitle,
                                startDate: editStartDate,
                                endDate: editEndDate
                            )
                            hasUnsavedChanges = false
                        }) {
                            Text("Guardar Cambios")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasUnsavedChanges)
                        
                        if hasUnsavedChanges {
                            Button(action: {
                                syncFieldsFromManager()
                            }) {
                                Text("Revertir")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            manager.forceSkipToNextCycle()
                            syncFieldsFromManager()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.to.line.compact")
                                Text("Forzar Siguiente RC")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
                .background(Color.white.opacity(0.02))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                
                // Section: App Preferences
                VStack(alignment: .leading, spacing: 10) {
                    Text("PREFERENCIAS DE LA APLICACIÓN")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    
                    Toggle(isOn: $manager.showDesktopWidget) {
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .foregroundColor(.secondary)
                            Text("Mostrar Widget interactivo en el escritorio")
                        }
                    }
                    .toggleStyle(.checkbox)
                    
                    Toggle(isOn: $manager.menuBarOnly) {
                        HStack {
                            Image(systemName: "macwindow.on.rectangle")
                                .foregroundColor(.secondary)
                            Text("Ejecutar sólo en barra de menús (ocultar icono de Dock)")
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.horizontal, 4)
                
                Spacer()
                
                // Diagnostic Tools footer
                HStack {
                    Button(action: {
                        manager.resetAll()
                        syncFieldsFromManager()
                    }) {
                        Text("Resetear Ciclos")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red.opacity(0.6))
                    
                    Spacer()
                    
                    Text("v1.0.0 • Hecho en macOS")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .frame(minWidth: 420, maxWidth: 500, maxHeight: .infinity)
            
            // RIGHT COLUMN: History Panel
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Historial de Ciclos")
                            .font(.system(size: 16, weight: .bold))
                        Text("Release Candidates completados")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !manager.pastCycles.isEmpty {
                        Button(action: {
                            manager.clearHistory()
                        }) {
                            Text("Limpiar")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                    }
                }
                
                if manager.pastCycles.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Sin Historial")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Los ciclos pasados se archivarán aquí automáticamente al completarse.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(manager.pastCycles.reversed()) { cycle in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green.opacity(0.8))
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(cycle.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("\(formatShortDate(cycle.startDate)) - \(formatShortDate(cycle.endDate))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(cycle.durationDays) días")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(6)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .padding(24)
            .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.08))
        }
        .onAppear {
            syncFieldsFromManager()
            
            // Register notifications listener to bring window front
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenDashboardWindow"),
                object: nil,
                queue: .main
            ) { _ in
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "RC Dashboard" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    private func syncFieldsFromManager() {
        editTitle = manager.activeCycle.title
        editStartDate = manager.activeCycle.startDate
        editEndDate = manager.activeCycle.endDate
        hasUnsavedChanges = false
    }
    
    private func checkForChanges() {
        let calendar = Calendar.current
        let hasTitleChanged = editTitle != manager.activeCycle.title
        let hasStartChanged = calendar.startOfDay(for: editStartDate) != calendar.startOfDay(for: manager.activeCycle.startDate)
        
        let cleanedEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: editEndDate) ?? editEndDate
        let hasEndChanged = calendar.startOfDay(for: cleanedEnd) != calendar.startOfDay(for: manager.activeCycle.endDate)
        
        hasUnsavedChanges = hasTitleChanged || hasStartChanged || hasEndChanged
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter.string(from: date)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - 7. COMPATIBILITY DEFAULT VIEW

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Esta es una app nativa con un widget de barra de menús.")
                .font(.headline)
            Text("Por favor, abre el Dashboard desde la Barra de Menús en la parte superior derecha de tu pantalla.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

// MARK: - PREVIEWS

#Preview {
    ContentView()
}
