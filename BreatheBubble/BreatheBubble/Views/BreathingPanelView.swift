import SwiftUI

// MARK: - Breathing Panel View (Main UI)
struct BreathingPanelView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var showSettings = false
    @State private var isHovering = false
    
    private var session: BreathingSession {
        windowManager.breathingSession
    }
    
    private var settings: AppSettings {
        windowManager.settings
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12))
            
            MetalBubbleView(
                expansion: session.expansion,
                color: session.currentColor,
                speed: session.isActive ? 1.0 : 0.4,
                isMini: false
            )
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        windowManager.closeBreathingPanel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1 : 0)
                }
                .padding(16)
                
                Spacer()
                
                if session.breathState != .idle && session.breathState != .completed {
                    Text("\(min(session.cycleCount + 1, session.totalCycles)) / \(session.totalCycles)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .padding(.bottom, 4)
                }
                
                Text(session.currentConfig.label)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                
                Text(session.currentConfig.instruction)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                
                Button {
                    if session.breathState == .completed {
                        session.reset()
                        session.start()
                    } else {
                        session.toggle()
                    }
                } label: {
                    Image(systemName: playButtonIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .opacity(isHovering ? 1 : 0)
                
                Spacer()
            }
        }
        .frame(width: 340, height: 340)
        .clipShape(Circle())
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, audioManager: windowManager.audioManager, session: session)
        }
    }
    
    private var playButtonIcon: String {
        switch session.breathState {
        case .idle:
            return "play.fill"
        case .completed:
            return "arrow.counterclockwise"
        default:
            return session.isActive ? "pause.fill" : "play.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    let windowManager = WindowManager()
    return BreathingPanelView(windowManager: windowManager)
        .background(.black)
}

