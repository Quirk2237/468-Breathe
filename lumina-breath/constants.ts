import { BreathState, BreathPhaseConfig, SoundTrack } from './types';

export const DEFAULT_SETTINGS = {
  includeHoldEmpty: false,
  cycles: 4,
  enableSound: false,
  soundTrack: 'ocean',
  customSound: undefined,
};

export const SOUND_TRACKS: SoundTrack[] = [
  { id: 'drone', label: 'Zen Drone', type: 'synth-drone' },
  { id: 'ocean', label: 'Ocean Waves', type: 'synth-noise', config: { filterType: 'lowpass', freq: 300, modDepth: 400, modSpeed: 0.15, q: 1 } },
  { id: 'rain', label: 'Gentle Rain', type: 'synth-noise', config: { filterType: 'lowpass', freq: 800, modDepth: 50, modSpeed: 0.05, q: 0 } },
  { id: 'stream', label: 'Flowing Stream', type: 'synth-noise', config: { filterType: 'lowpass', freq: 400, modDepth: 100, modSpeed: 2.0, q: 3 } },
  { 
    id: 'forest', 
    label: 'Forest Birds', 
    type: 'audio-file', 
    // Using a reliable high-quality creative commons source since the provided link was a webpage
    url: 'https://cdn.pixabay.com/download/audio/2021/08/09/audio_8ed5403529.mp3?filename=forest-with-small-river-birds-and-nature-field-recording-6735.mp3' 
  },
];

export const PHASE_CONFIG: Record<BreathState, BreathPhaseConfig> = {
  [BreathState.IDLE]: {
    label: 'Ready',
    duration: 0,
    instruction: 'Tap to start',
    color: [0.2, 0.6, 1.0],
  },
  [BreathState.INHALE]: {
    label: 'Inhale',
    duration: 4,
    instruction: 'Inhale quietly through nose',
    color: [0.4, 0.8, 1.0], // Cyan/Blue
  },
  [BreathState.HOLD_FULL]: {
    label: 'Hold',
    duration: 6,
    instruction: 'Hold your breath',
    color: [0.6, 0.5, 1.0], // Purple
  },
  [BreathState.EXHALE]: {
    label: 'Exhale',
    duration: 8,
    instruction: 'Exhale slowly through mouth',
    color: [1.0, 0.4, 0.6], // Pink/Orange
  },
  [BreathState.HOLD_EMPTY]: {
    label: 'Rest',
    duration: 4,
    instruction: 'Hold empty (Optional)',
    color: [0.2, 0.3, 0.5], // Dark Blue/Grey
  },
  [BreathState.COMPLETED]: {
    label: 'Done',
    duration: 0,
    instruction: 'Routine Complete',
    color: [0.2, 0.8, 0.4], // Green
  },
};