import { SoundTrack } from './types';
import { SOUND_TRACKS } from './constants';

export class SoundManager {
  ctx: AudioContext | null = null;
  masterGain: GainNode | null = null;
  activeNodes: AudioNode[] = [];
  activeAudioEl: HTMLAudioElement | null = null;
  fadeInterval: number | null = null;
  
  isPlaying: boolean = false;
  currentTrackId: string | null = null;

  init() {
    if (!this.ctx) {
      this.ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
      this.masterGain = this.ctx.createGain();
      this.masterGain.connect(this.ctx.destination);
      this.masterGain.gain.value = 0;
    }
  }

  setVolume(val: number, fadeTime: number = 0) {
    const now = this.ctx?.currentTime || 0;
    
    // 1. Handle Web Audio Synth Volume
    if (this.ctx && this.masterGain) {
      this.masterGain.gain.cancelScheduledValues(now);
      this.masterGain.gain.linearRampToValueAtTime(val, now + fadeTime);
    }

    // 2. Handle HTML5 Audio Element Volume (Manual Fade)
    if (this.activeAudioEl) {
       // Clear any existing manual fade
       if (this.fadeInterval) {
         window.clearInterval(this.fadeInterval);
         this.fadeInterval = null;
       }

       const startVol = this.activeAudioEl.volume;
       const endVol = val;
       const duration = fadeTime * 1000; // ms
       const stepTime = 50;
       const steps = duration / stepTime;
       let currentStep = 0;

       if (duration === 0) {
         this.activeAudioEl.volume = endVol;
         return;
       }

       this.fadeInterval = window.setInterval(() => {
         currentStep++;
         const progress = currentStep / steps;
         const newVol = startVol + (endVol - startVol) * progress;
         
         if (this.activeAudioEl) {
            this.activeAudioEl.volume = Math.max(0, Math.min(1, newVol));
         }

         if (currentStep >= steps) {
            if (this.fadeInterval) window.clearInterval(this.fadeInterval);
            this.fadeInterval = null;
         }
       }, stepTime);
    }
  }

  play(trackId: string, customUrl?: string) {
    this.init();
    if (!this.ctx) return; // Should not happen

    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }

    // If already playing this track, do nothing
    if (this.isPlaying && this.currentTrackId === trackId) return;

    // Fade out old
    this.setVolume(0, 0.5);

    setTimeout(() => {
        this.stopSources();
        
        if (trackId === 'custom' && customUrl) {
            this.createAudioElement(customUrl);
        } else {
            const track = SOUND_TRACKS.find(t => t.id === trackId) || SOUND_TRACKS[0];
            
            if (track.type === 'synth-drone') {
                this.createDrone();
            } else if (track.type === 'synth-noise') {
                this.createNoise(track.config);
            } else if (track.type === 'audio-file' && track.url) {
                this.createAudioElement(track.url);
            }
        }

        this.currentTrackId = trackId;
        this.isPlaying = true;
        this.setVolume(0.5, 2); // Fade in
    }, 550);
  }

  stop() {
    if (!this.isPlaying) return;
    this.setVolume(0, 2); // Fade out
    this.isPlaying = false;
    this.currentTrackId = null;
    
    setTimeout(() => {
        this.stopSources();
    }, 2000);
  }

  stopSources() {
    // Stop Web Audio Nodes
    this.activeNodes.forEach(node => {
        try { 
            if (node instanceof OscillatorNode || node instanceof AudioBufferSourceNode) {
                node.stop();
            }
            node.disconnect(); 
        } catch (e) { /* ignore */ }
    });
    this.activeNodes = [];

    // Stop HTML5 Audio Element
    if (this.activeAudioEl) {
      this.activeAudioEl.pause();
      this.activeAudioEl.src = '';
      this.activeAudioEl = null;
    }
    
    if (this.fadeInterval) {
      clearInterval(this.fadeInterval);
      this.fadeInterval = null;
    }
  }

  // --- Generators ---

  createAudioElement(url: string) {
    const audio = new Audio(url);
    audio.loop = true;
    audio.volume = 0; // Start silent for fade in
    audio.crossOrigin = "anonymous";
    
    const playPromise = audio.play();
    if (playPromise !== undefined) {
      playPromise.catch(error => {
        console.warn("Audio playback failed:", error);
      });
    }
    this.activeAudioEl = audio;
  }

  createDrone() {
    if (!this.ctx || !this.masterGain) return;
    const freqs = [110, 164.81, 196.00]; // A2, E3, G3
    freqs.forEach(freq => {
       const osc = this.ctx!.createOscillator();
       osc.type = 'sine';
       osc.frequency.value = freq;
       osc.detune.value = (Math.random() - 0.5) * 15;
       
       const gain = this.ctx!.createGain();
       gain.gain.value = 0.15;
       
       osc.connect(gain);
       gain.connect(this.masterGain!);
       osc.start();
       
       this.activeNodes.push(osc, gain);
    });
  }

  createNoise(config: any) {
    if (!this.ctx || !this.masterGain) return;

    // Create White Noise Buffer (5 seconds is enough to loop)
    const bufferSize = this.ctx.sampleRate * 5;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
        data[i] = Math.random() * 2 - 1;
    }

    const noise = this.ctx.createBufferSource();
    noise.buffer = buffer;
    noise.loop = true;

    // Create Filter
    const filter = this.ctx.createBiquadFilter();
    filter.type = config.filterType || 'lowpass';
    filter.frequency.value = config.freq || 500;
    filter.Q.value = config.q || 1;

    // Filter Modulation (LFO) for "Waves" effect
    if (config.modDepth > 0) {
        const lfo = this.ctx.createOscillator();
        lfo.type = 'sine';
        lfo.frequency.value = config.modSpeed || 0.1;
        
        const lfoGain = this.ctx.createGain();
        lfoGain.gain.value = config.modDepth;

        lfo.connect(lfoGain);
        lfoGain.connect(filter.frequency);
        lfo.start();
        this.activeNodes.push(lfo, lfoGain);
    }

    // Connect
    // Noise -> Filter -> Master
    noise.connect(filter);
    filter.connect(this.masterGain);
    noise.start();

    this.activeNodes.push(noise, filter);
  }
}

export const soundManager = new SoundManager();