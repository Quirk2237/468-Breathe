export enum BreathState {
  IDLE = 'IDLE',
  INHALE = 'INHALE',
  HOLD_FULL = 'HOLD_FULL',
  EXHALE = 'EXHALE',
  HOLD_EMPTY = 'HOLD_EMPTY',
  COMPLETED = 'COMPLETED'
}

export interface BreathPhaseConfig {
  label: string;
  duration: number; // in seconds
  instruction: string;
  color: [number, number, number]; // RGB 0-1
}

export interface BreathSettings {
  includeHoldEmpty: boolean;
  cycles: number;
  enableSound: boolean;
  soundTrack: string;
  customSound?: {
    name: string;
    url: string;
  };
}

export interface SoundTrack {
  id: string;
  label: string;
  type: 'synth-drone' | 'synth-noise' | 'audio-file';
  config?: any;
  url?: string;
}