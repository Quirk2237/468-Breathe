import SwiftUI
import Combine

// MARK: - Exercise Panel View
struct ExercisePanelView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var isHovering = false
    @State private var pulseAnimation: Float = 0.5
    @State private var pulseTime: Double = 0
    
    private var session: ExerciseSession {
        windowManager.exerciseSession
    }
    
    private var exerciseColor: Color {
        let color = session.exerciseColor
        return Color(red: Double(color.x), green: Double(color.y), blue: Double(color.z))
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12))
            
            MetalBubbleView(
                expansion: calculatePulseExpansion(),
                color: session.exerciseColor,
                speed: session.state == .active ? 1.0 : 0.6,
                isMini: false
            )
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        windowManager.closeExercisePanel()
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
                
                Image(systemName: session.exerciseIcon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(.bottom, 8)
                
                Text(session.exerciseName)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                
                Text("\(session.targetReps) reps")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(.top, 4)
                
                Text(session.exerciseInstruction)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(.top, 8)
                
                Button {
                    if session.state == .completed {
                        windowManager.closeExercisePanel()
                    } else if session.state == .active {
                        session.complete()
                    } else {
                        session.start()
                    }
                } label: {
                    HStack {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(buttonText)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 44)
                    .background(.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
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
        .onAppear {
            startPulseAnimation()
        }
        .onDisappear {
            stopPulseAnimation()
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            if session.state != .completed {
                pulseTime += 0.05
            }
        }
    }
    
    private var buttonIcon: String {
        switch session.state {
        case .idle:
            return "play.fill"
        case .active:
            return "checkmark"
        case .completed:
            return "xmark"
        }
    }
    
    private var buttonText: String {
        switch session.state {
        case .idle:
            return "Start"
        case .active:
            return "Done"
        case .completed:
            return "Close"
        }
    }
    
    private func calculatePulseExpansion() -> Float {
        let pulse = sin(pulseTime * 2.0) * 0.2 + 0.5
        return Float(pulse)
    }
    
    private func startPulseAnimation() {
        pulseTime = 0
    }
    
    private func stopPulseAnimation() {
    }
}

// MARK: - Preview
#Preview {
    let windowManager = WindowManager()
    windowManager.exerciseSession.configure(exerciseType: .pushups, repCount: 15)
    return ExercisePanelView(windowManager: windowManager)
        .background(.black)
}

