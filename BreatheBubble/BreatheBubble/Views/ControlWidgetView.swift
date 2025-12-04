import SwiftUI

// MARK: - Control Widget View (Timer & Breathing Control)
struct ControlWidgetView: View {
    @ObservedObject var windowManager: WindowManager
    
    @State private var isHoveringWidget = false
    @State private var isHoveringCircle = false
    @State private var showContextMenu = false
    
    private var timerManager: TimerManager {
        windowManager.timerManager
    }
    
    private var session: BreathingSession {
        windowManager.breathingSession
    }
    
    private var settings: AppSettings {
        windowManager.settings
    }
    
    private var widgetSize: CGFloat {
        settings.widgetSize.dimension
    }
    
    private var widgetWindowSize: CGFloat {
        settings.widgetSize.windowSize
    }
    
    private let ringColor = Color.orange
    private let ringThickness: CGFloat = 4
    private let hoverInset: CGFloat = 12
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main circle content
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))
                
                if windowManager.isPanelOpen {
                    breathingControlContent
                } else {
                    timerContent
                }
            }
            .frame(width: widgetSize, height: widgetSize)
            .contentShape(Circle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringCircle = hovering
                }
            }
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                showContextMenu = true
            }
            .contextMenu {
                contextMenuContent
            }
            
            if isHoveringWidget {
                settingsButton
                    .offset(x: 8, y: -8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: widgetWindowSize, height: widgetWindowSize)
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringWidget = hovering
            }
        }
        .help(windowManager.isPanelOpen ? "Click to focus breathing panel" : "Click to start/pause timer\nRight-click for options")
    }
    
    // MARK: - Settings Button
    private var settingsButton: some View {
        Button {
            windowManager.openSettings()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color(white: 0.2))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
        .help("Open Settings")
    }
    
    private var timerFontSize: CGFloat {
        switch settings.widgetSize {
        case .small: return 20
        case .medium: return 26
        case .large: return 32
        }
    }
    
    private var iconFontSize: CGFloat {
        switch settings.widgetSize {
        case .small: return 18
        case .medium: return 24
        case .large: return 30
        }
    }
    
    // MARK: - Timer Content
    private var timerContent: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.3), lineWidth: ringThickness)
                .padding(ringThickness / 2)
            
            Circle()
                .trim(from: 0, to: 1.0 - timerManager.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringThickness, lineCap: .round))
                .padding(ringThickness / 2)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: timerManager.progress)
            
            // Time remaining display
            Text(timerManager.formattedTimeShort)
                .font(.system(size: timerFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.orange)
                .monospacedDigit()
            
            if isHoveringCircle {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .padding(hoverInset)
                
                Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: iconFontSize, weight: .medium))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHoveringCircle)
    }
    
    // MARK: - Breathing Control Content
    private var breathingControlContent: some View {
        Text(timerManager.formattedTimeShort)
            .font(.system(size: timerFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.orange)
            .monospacedDigit()
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            windowManager.openBreathingPanel()
        } label: {
            Label("Start Breathing", systemImage: "wind")
        }
        
        Divider()
        
        Button {
            timerManager.toggle()
        } label: {
            Label(
                timerManager.isRunning ? "Pause Timer" : "Resume Timer",
                systemImage: timerManager.isRunning ? "pause" : "play"
            )
        }
        
        Button {
            timerManager.skip()
        } label: {
            Label("Skip Timer", systemImage: "forward.end")
        }
        
        Button {
            timerManager.reset()
        } label: {
            Label("Reset Timer", systemImage: "arrow.counterclockwise")
        }
        
        Divider()
        
        Menu("Set Interval") {
            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                Button("\(minutes) minutes") {
                    windowManager.settings.timerIntervalMinutes = minutes
                    timerManager.intervalMinutes = minutes
                    timerManager.reset()
                    timerManager.start()
                }
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            windowManager.quitApp()
        } label: {
            Label("Quit Breathe Bubble", systemImage: "xmark.circle")
        }
    }
    
    // MARK: - Tap Handler
    private func handleTap() {
        if windowManager.isPanelOpen {
            windowManager.focusBreathingPanel()
        } else {
            // Toggle timer regimen instead of opening breathing panel directly
            timerManager.toggle()
        }
    }
}

// MARK: - Preview
#Preview {
    let windowManager = WindowManager()
    return ControlWidgetView(windowManager: windowManager)
        .frame(width: 130, height: 130)
        .background(.black)
}

