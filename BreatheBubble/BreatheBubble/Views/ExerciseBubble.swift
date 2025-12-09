import SwiftUI

// MARK: - Exercise Bubble
struct ExerciseBubble: View {
    @ObservedObject var windowManager: WindowManager
    @State private var isHovering = false
    
    private var breathingSession: BreathingSession {
        windowManager.breathingSession
    }
    
    private var exerciseSession: ExerciseSession {
        windowManager.exerciseSession
    }
    
    private var settings: AppSettings {
        windowManager.settings
    }
    
    private var activityType: ActivityType {
        windowManager.currentActivityType ?? .breathwork
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12))
            
            if activityType == .breathwork {
                breathworkContent
            } else {
                exerciseContent
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
    }
    
    // MARK: - Breathwork Content
    private var breathworkContent: some View {
        ZStack {
            MetalBubbleView(
                expansion: breathingSession.expansion,
                color: breathingSession.currentColor,
                speed: breathingSession.isActive ? 1.0 : 0.4,
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
                
                if breathingSession.breathState != .idle && breathingSession.breathState != .completed {
                    Text("\(min(breathingSession.cycleCount + 1, breathingSession.totalCycles)) / \(breathingSession.totalCycles)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .padding(.bottom, 4)
                }
                
                Text(breathingSession.currentConfig.label)
                    .id(breathingSession.breathState)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.6), value: breathingSession.breathState)
                
                Text(breathingSession.currentConfig.instruction)
                    .id("\(breathingSession.breathState)-instruction")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.6), value: breathingSession.breathState)
                
                HStack(spacing: 8) {
                    CircularActionButton(
                        icon: "forward.fill",
                        action: {
                            windowManager.closeBreathingPanel()
                        }
                    )
                    
                    CircularActionButton(
                        icon: breathworkPlayButtonIcon,
                        action: {
                            if breathingSession.breathState == .completed {
                                breathingSession.reset()
                                breathingSession.start()
                            } else {
                                breathingSession.toggle()
                            }
                        }
                    )
                }
                .padding(.top, 12)
                .opacity(isHovering ? 1 : 0)
                
                Spacer()
            }
        }
    }
    
    private var breathworkPlayButtonIcon: String {
        switch breathingSession.breathState {
        case .idle:
            return "play.fill"
        case .completed:
            return "arrow.counterclockwise"
        default:
            return breathingSession.isActive ? "pause.fill" : "play.fill"
        }
    }
    
    // MARK: - Exercise Content (Push-ups, Sit-ups)
    private var exerciseContent: some View {
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
            
            Image(systemName: exerciseSession.exerciseIcon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 4)
                .padding(.bottom, 8)
            
            Text(exerciseSession.exerciseName)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            Text("\(exerciseSession.targetReps) reps")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .padding(.top, 4)
            
            Text(exerciseSession.exerciseInstruction)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .padding(.top, 8)
            
            if exerciseSession.state == .idle {
                HStack(spacing: 8) {
                    CircularActionButton(
                        icon: "checkmark",
                        action: {
                            exerciseSession.complete()
                            windowManager.closeExercisePanel()
                        }
                    )
                    
                    CircularActionButton(
                        icon: "forward.fill",
                        action: {
                            windowManager.skipExercise()
                        }
                    )
                }
                .padding(.top, 16)
                .opacity(isHovering ? 1 : 0)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview("Breathwork") {
    let windowManager = WindowManager()
    return ExerciseBubble(windowManager: windowManager)
        .background(.black)
}

#Preview("Exercise") {
    let windowManager = WindowManager()
    windowManager.exerciseSession.configure(exerciseType: .pushups, repCount: 15)
    return ExerciseBubble(windowManager: windowManager)
        .background(.black)
}
