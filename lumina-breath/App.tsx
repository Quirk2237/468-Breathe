import React, { useState, useEffect, useRef, useCallback } from 'react';
import BubbleShader from './components/BubbleShader';
import { BreathState, BreathSettings } from './types';
import { PHASE_CONFIG, DEFAULT_SETTINGS, SOUND_TRACKS } from './constants';
import { soundManager } from './audio';
import { Play, Pause, RefreshCw, Settings, X, Volume2, VolumeX, Music, Check, Upload } from 'lucide-react';

const App: React.FC = () => {
  // State
  const [breathState, setBreathState] = useState<BreathState>(BreathState.IDLE);
  const [isActive, setIsActive] = useState(false);
  const [elapsedTime, setElapsedTime] = useState(0);
  const [cycleCount, setCycleCount] = useState(0);
  const [showSettings, setShowSettings] = useState(false);
  
  // Settings
  const [settings, setSettings] = useState<BreathSettings>(DEFAULT_SETTINGS);
  
  // File Input Ref
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Refs for animation loop
  const requestRef = useRef<number | undefined>(undefined);
  const previousTimeRef = useRef<number | undefined>(undefined);

  // Derived Values
  const currentConfig = PHASE_CONFIG[breathState];
  
  // Handle Sound
  useEffect(() => {
    if (isActive && settings.enableSound) {
      soundManager.play(settings.soundTrack, settings.customSound?.url);
    } else {
      soundManager.stop();
    }
    
    // Cleanup on unmount handled by global instance
    return () => {
      if (isActive) soundManager.stop();
    };
  }, [isActive, settings.enableSound, settings.soundTrack, settings.customSound]);

  // Handle File Upload
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const url = URL.createObjectURL(file);
      setSettings(prev => ({
        ...prev,
        soundTrack: 'custom',
        customSound: {
          name: file.name.length > 20 ? file.name.substring(0, 18) + '...' : file.name,
          url: url
        }
      }));
    }
  };

  const triggerFileUpload = () => {
    fileInputRef.current?.click();
  };

  // Helpers
  const nextPhase = useCallback((current: BreathState): BreathState => {
    switch (current) {
      case BreathState.IDLE: return BreathState.INHALE;
      case BreathState.INHALE: return BreathState.HOLD_FULL;
      case BreathState.HOLD_FULL: return BreathState.EXHALE;
      case BreathState.EXHALE: 
        if (settings.includeHoldEmpty) return BreathState.HOLD_EMPTY;
        return BreathState.INHALE; // Loop back if no hold empty
      case BreathState.HOLD_EMPTY: return BreathState.INHALE;
      default: return BreathState.IDLE;
    }
  }, [settings.includeHoldEmpty]);

  // Main Loop
  const animate = useCallback((time: number) => {
    if (previousTimeRef.current !== undefined) {
      const deltaTime = (time - previousTimeRef.current) / 1000;
      
      if (isActive && breathState !== BreathState.COMPLETED) {
        setElapsedTime(prev => {
          const newElapsed = prev + deltaTime;
          
          // Phase Completion Check
          if (newElapsed >= currentConfig.duration) {
            const next = nextPhase(breathState);
            
            // Check for Cycle Completion
            if (next === BreathState.INHALE) {
              setCycleCount(c => {
                 const newCount = c + 1;
                 if (newCount >= settings.cycles) {
                     setBreathState(BreathState.COMPLETED);
                     setIsActive(false);
                     return newCount;
                 }
                 return newCount;
              });
              
              if (cycleCount < settings.cycles - 1) { 
                 setBreathState(next);
              }
            } else {
               setBreathState(next);
            }
            return 0; // Reset timer for next phase
          }
          
          return newElapsed;
        });
      }
    }
    previousTimeRef.current = time;
    requestRef.current = requestAnimationFrame(animate);
  }, [isActive, breathState, currentConfig.duration, nextPhase, cycleCount, settings.cycles]);

  useEffect(() => {
    requestRef.current = requestAnimationFrame(animate);
    return () => {
      if (requestRef.current) cancelAnimationFrame(requestRef.current);
    };
  }, [animate]);

  // Controls
  const toggleActive = () => {
    if (breathState === BreathState.COMPLETED) {
      reset();
      setBreathState(BreathState.INHALE);
      setIsActive(true);
    } else if (breathState === BreathState.IDLE) {
      setBreathState(BreathState.INHALE);
      setIsActive(true);
    } else {
      setIsActive(!isActive);
    }
  };

  const reset = () => {
    setIsActive(false);
    setBreathState(BreathState.IDLE);
    setElapsedTime(0);
    setCycleCount(0);
  };

  // Visual Calculation
  const calculateExpansion = () => {
    if (breathState === BreathState.IDLE || breathState === BreathState.COMPLETED) return 0.1;
    
    const progress = Math.min(elapsedTime / currentConfig.duration, 1);
    
    switch (breathState) {
      case BreathState.INHALE:
        // Easing out sine
        return Math.sin((progress * Math.PI) / 2); 
      case BreathState.HOLD_FULL:
        return 1.0;
      case BreathState.EXHALE:
        // Easing in out cosine-ish
        return 1.0 - Math.sin((progress * Math.PI) / 2); 
      case BreathState.HOLD_EMPTY:
        return 0.0;
      default:
        return 0.0;
    }
  };

  const expansion = calculateExpansion();

  return (
    <div className="relative w-full h-screen overflow-hidden flex flex-col items-center justify-center text-white select-none">
      
      {/* Background/Shader */}
      <BubbleShader 
        expansion={expansion} 
        color={currentConfig.color} 
        speed={isActive ? 1.0 : 0.4} // Always animating, slightly slower when idle
      />

      {/* Main Content Area */}
      <main className="z-10 flex flex-col items-center gap-8 px-4 text-center max-w-md w-full">
        
        {/* Status Indicators (Only visible when Active or Completed) */}
        <div className={`transition-opacity duration-500 flex flex-col items-center gap-2 ${isActive || breathState === BreathState.COMPLETED ? 'opacity-100' : 'opacity-0'}`}>
          <div className="text-sm font-medium tracking-widest uppercase opacity-60">
             {breathState === BreathState.COMPLETED 
               ? 'Session Finished' 
               : `Cycle ${Math.min(cycleCount + 1, settings.cycles)} / ${settings.cycles}`}
          </div>
          <h1 className="text-4xl md:text-5xl font-light tracking-tight h-16 flex items-center justify-center">
            {currentConfig.label}
          </h1>
          <p className="text-lg opacity-80 h-8 font-light">
             {currentConfig.instruction}
          </p>
        </div>

      </main>

      {/* Centered Start Button Overlay */}
      {breathState === BreathState.IDLE && (
        <div className="absolute inset-0 z-30 flex items-center justify-center">
          <button 
            onClick={toggleActive}
            className="group relative flex items-center justify-center w-24 h-24 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 hover:bg-white/20 transition-all duration-300 shadow-xl shadow-blue-900/20"
            aria-label="Start Breathing Session"
          >
            <Play className="w-8 h-8 fill-white ml-1" />
            <div className="absolute inset-0 rounded-full border border-white/30 scale-110 opacity-0 group-hover:scale-125 group-hover:opacity-100 transition-all duration-500"></div>
          </button>
        </div>
      )}

      {/* Footer Controls */}
      <footer className="absolute bottom-8 z-20 flex items-center gap-6">
        {breathState !== BreathState.IDLE && (
           <>
            <button 
              onClick={reset}
              className="p-3 rounded-full bg-white/5 hover:bg-white/10 backdrop-blur-md transition-colors"
              aria-label="Reset"
            >
              <RefreshCw className="w-5 h-5 opacity-80" />
            </button>

            <button 
              onClick={toggleActive}
              className="p-4 rounded-full bg-white text-slate-900 hover:scale-105 transition-transform shadow-lg shadow-white/10"
              aria-label={isActive ? "Pause" : "Resume"}
            >
              {breathState === BreathState.COMPLETED ? (
                <RefreshCw className="w-6 h-6" /> 
              ) : isActive ? (
                <Pause className="w-6 h-6 fill-current" />
              ) : (
                <Play className="w-6 h-6 fill-current ml-0.5" />
              )}
            </button>

             <button 
              onClick={() => setShowSettings(true)}
              className="p-3 rounded-full bg-white/5 hover:bg-white/10 backdrop-blur-md transition-colors"
              aria-label="Settings"
            >
              <Settings className="w-5 h-5 opacity-80" />
            </button>
           </>
        )}
        
        {breathState === BreathState.IDLE && (
           <button 
             onClick={() => setShowSettings(true)}
             className="absolute bottom-4 opacity-50 hover:opacity-100 transition-opacity p-2"
           >
             <Settings className="w-6 h-6" />
           </button>
        )}
      </footer>

      {/* Settings Modal */}
      {showSettings && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-slate-900/90 border border-white/10 rounded-2xl p-6 w-full max-w-sm shadow-2xl overflow-y-auto max-h-[90vh]">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-medium">Settings</h2>
              <button onClick={() => setShowSettings(false)} className="p-1 hover:bg-white/10 rounded-full">
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <div className="space-y-6">
              {/* Cycle Count */}
              <div className="space-y-3">
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Number of Cycles</span>
                  <span className="font-mono">{settings.cycles}</span>
                </div>
                <input 
                  type="range" 
                  min="1" 
                  max="10" 
                  value={settings.cycles}
                  onChange={(e) => setSettings({...settings, cycles: parseInt(e.target.value)})}
                  className="w-full h-1 bg-slate-700 rounded-full appearance-none cursor-pointer accent-blue-500"
                />
              </div>

              {/* Sound Settings */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex flex-col">
                    <span className="text-sm flex items-center gap-2">
                      {settings.enableSound ? <Volume2 className="w-4 h-4"/> : <VolumeX className="w-4 h-4"/>} 
                      Calming Sound
                    </span>
                    <span className="text-xs opacity-50">Ambient nature sounds</span>
                  </div>
                  <button 
                    onClick={() => setSettings(s => ({...s, enableSound: !s.enableSound}))}
                    className={`w-12 h-6 rounded-full transition-colors relative ${settings.enableSound ? 'bg-blue-600' : 'bg-slate-700'}`}
                  >
                    <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${settings.enableSound ? 'left-7' : 'left-1'}`} />
                  </button>
                </div>

                {/* Track Selector */}
                {settings.enableSound && (
                  <div className="grid grid-cols-1 gap-2 pt-2 animate-in slide-in-from-top-2 duration-200">
                     {SOUND_TRACKS.map(track => (
                        <button
                          key={track.id}
                          onClick={() => setSettings(s => ({...s, soundTrack: track.id}))}
                          className={`flex items-center justify-between p-3 rounded-xl text-sm transition-all text-left ${
                            settings.soundTrack === track.id 
                              ? 'bg-blue-600/20 border border-blue-500/50 shadow-sm' 
                              : 'bg-white/5 border border-transparent hover:bg-white/10'
                          }`}
                        >
                          <div className="flex items-center gap-3">
                             {/* Simple visual indicator of type */}
                             <div className={`w-2 h-2 rounded-full ${settings.soundTrack === track.id ? 'bg-blue-400' : 'bg-white/20'}`} />
                             <span>{track.label}</span>
                          </div>
                          {settings.soundTrack === track.id && <Check className="w-4 h-4 text-blue-400" />}
                        </button>
                     ))}

                     {/* Custom Track Button (If exists) */}
                     {settings.customSound && (
                        <button
                          onClick={() => setSettings(s => ({...s, soundTrack: 'custom'}))}
                          className={`flex items-center justify-between p-3 rounded-xl text-sm transition-all text-left ${
                            settings.soundTrack === 'custom'
                              ? 'bg-blue-600/20 border border-blue-500/50 shadow-sm' 
                              : 'bg-white/5 border border-transparent hover:bg-white/10'
                          }`}
                        >
                           <div className="flex items-center gap-3">
                             <div className={`w-2 h-2 rounded-full ${settings.soundTrack === 'custom' ? 'bg-blue-400' : 'bg-white/20'}`} />
                             <span className="truncate max-w-[150px]">{settings.customSound.name}</span>
                          </div>
                          {settings.soundTrack === 'custom' && <Check className="w-4 h-4 text-blue-400" />}
                        </button>
                     )}

                     {/* Upload Button */}
                     <input 
                       type="file" 
                       ref={fileInputRef} 
                       onChange={handleFileUpload} 
                       accept="audio/*" 
                       className="hidden" 
                     />
                     <button
                        onClick={triggerFileUpload}
                        className="flex items-center justify-center gap-2 p-3 rounded-xl text-sm transition-all border border-dashed border-white/20 hover:bg-white/5 hover:border-white/40 text-white/70 mt-1"
                     >
                        <Upload className="w-4 h-4" />
                        <span>Upload Custom MP3</span>
                     </button>
                  </div>
                )}
              </div>

              {/* Hold Empty Toggle */}
              <div className="flex items-center justify-between pt-2">
                <div className="flex flex-col">
                  <span className="text-sm">Hold Empty</span>
                  <span className="text-xs opacity-50">Additional 4s hold after exhale</span>
                </div>
                <button 
                  onClick={() => setSettings(s => ({...s, includeHoldEmpty: !s.includeHoldEmpty}))}
                  className={`w-12 h-6 rounded-full transition-colors relative ${settings.includeHoldEmpty ? 'bg-blue-600' : 'bg-slate-700'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${settings.includeHoldEmpty ? 'left-7' : 'left-1'}`} />
                </button>
              </div>

              <div className="pt-4 border-t border-white/10">
                 <p className="text-xs opacity-40 leading-relaxed">
                   The 4-6-8 technique acts as a natural tranquilizer for the nervous system. 
                   Practice at least twice a day.
                 </p>
              </div>
            </div>
            
            <button 
              onClick={() => setShowSettings(false)}
              className="w-full mt-6 py-3 bg-white text-slate-900 font-medium rounded-xl hover:bg-slate-100 transition-colors"
            >
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;