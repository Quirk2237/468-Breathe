import SwiftUI

// MARK: - Control Widget View (Timer & Breathing Control)
struct ControlWidgetView: View {
    @ObservedObject var windowManager: WindowManager
    
    @State private var isHovering = false
    @State private var showContextMenu = false
    
    private var timerManager: TimerManager {
        windowManager.timerManager
    }
    
    private var session: BreathingSession {
        windowManager.breathingSession
    }
    
    private let ringColor = Color.orange
    private let ringThickness: CGFloat = 4
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12))
            
            if windowManager.isPanelOpen {
                breathingControlContent
            } else {
                timerContent
            }
        }
        .frame(width: 100, height: 100)
        .background(Color.clear)
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
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
        .help(windowManager.isPanelOpen ? "Click to focus breathing panel" : "Click to start/pause timer\nRight-click for options")
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
            
            VStack(spacing: 4) {
                Image(systemName: "lungs.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.orange)
                
                if isHovering {
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
    }
    
    // MARK: - Breathing Control Content
    private var breathingControlContent: some View {
        Image(systemName: "lungs.fill")
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(Color.orange)
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
        .frame(width: 120, height: 120)
        .background(.black)
}

