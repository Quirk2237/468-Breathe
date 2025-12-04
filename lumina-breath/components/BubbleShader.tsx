import React, { useEffect, useRef } from 'react';

interface BubbleShaderProps {
  expansion: number; // 0.0 to 1.0 (Size of bubble)
  color: [number, number, number]; // RGB
  speed?: number;
}

const VERTEX_SHADER = `
  attribute vec2 position;
  void main() {
    gl_Position = vec4(position, 0.0, 1.0);
  }
`;

const FRAGMENT_SHADER = `
  precision mediump float;
  
  uniform float u_time;
  uniform float u_expansion;
  uniform vec2 u_resolution;
  uniform vec3 u_color;

  // Simplex 2D noise
  vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

  float snoise(vec2 v){
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
             -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod(i, 289.0);
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
    + i.x + vec3(0.0, i1.x, 1.0 ));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
  }

  void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);
    
    // Dynamic Radius
    float baseRadius = 0.22 + (u_expansion * 0.23);
    
    // Noise Setup
    // Ensure we have movement even when u_expansion is static
    float noiseScale = 1.4; 
    float timeScale = u_time * 0.4;
    float angle = atan(uv.y, uv.x);
    float len = length(uv);
    
    // Calculate noise value
    float n = snoise(vec2(cos(angle) * noiseScale + timeScale, sin(angle) * noiseScale + timeScale));
    
    // Displace radius by noise
    // INCREASED BASE VALUE: 0.04 ensures the bubble ripples significantly even at rest (expansion=0 or 1)
    float displacement = n * (0.04 + 0.03 * u_expansion);
    float r = baseRadius + displacement;
    
    float dist = len - r;
    
    // 1. Core Shape (Soft Edge)
    float alphaShape = smoothstep(0.005, -0.005, dist);
    
    // 2. Inner Glow (Ambient Occlusion feel)
    float innerGlow = smoothstep(-0.3, 0.0, dist) * 0.6;
    
    // 3. Specular Highlight
    vec2 highlightCenter = vec2(-0.15, 0.15);
    float highlightDist = length(uv - highlightCenter);
    float highlightBase = smoothstep(0.25, 0.0, highlightDist); 
    float highlightSpot = smoothstep(0.1, 0.0, highlightDist - 0.02); 
    float highlight = (highlightBase * 0.3) + (highlightSpot * 0.3);
    highlight *= alphaShape;

    // 4. Outer Glow (Aura)
    float outerGlow = exp(-6.0 * max(0.0, dist));
    
    // Compose Colors
    vec3 bubbleColor = u_color;
    
    vec3 finalColor = bubbleColor * (0.4 + 0.6 * innerGlow); // Base + inner glow
    finalColor += vec3(1.0, 1.0, 1.0) * highlight; // Add highlight
    finalColor += bubbleColor * outerGlow * 0.4; // Add outer aura
    
    // Alpha Calculation
    float finalAlpha = alphaShape + (outerGlow * 0.6);
    finalAlpha = clamp(finalAlpha, 0.0, 1.0);
    
    gl_FragColor = vec4(finalColor, finalAlpha);
  }
`;

const BubbleShader: React.FC<BubbleShaderProps> = ({ expansion, color, speed = 1.0 }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const glRef = useRef<WebGLRenderingContext | null>(null);
  const programRef = useRef<WebGLProgram | null>(null);
  const bufferRef = useRef<WebGLBuffer | null>(null);
  const timeRef = useRef<number>(0);
  const requestRef = useRef<number>(0);
  
  // Use a ref to store current props so the animation loop can access them
  // without triggering a re-effect/re-bind cycle every frame.
  const propsRef = useRef({ expansion, color, speed });

  useEffect(() => {
    propsRef.current = { expansion, color, speed };
  }, [expansion, color, speed]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: false });
    if (!gl) return;
    glRef.current = gl;

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    const compileShader = (source: string, type: number) => {
      const shader = gl.createShader(type);
      if (!shader) return null;
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('Shader compile error:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
      }
      return shader;
    };

    const vert = compileShader(VERTEX_SHADER, gl.VERTEX_SHADER);
    const frag = compileShader(FRAGMENT_SHADER, gl.FRAGMENT_SHADER);

    if (!vert || !frag) return;

    const program = gl.createProgram();
    if (!program) return;
    gl.attachShader(program, vert);
    gl.attachShader(program, frag);
    gl.linkProgram(program);
    programRef.current = program;

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      gl.STATIC_DRAW
    );
    bufferRef.current = buffer;

    // Cache locations
    const positionLocation = gl.getAttribLocation(program, 'position');
    const timeLocation = gl.getUniformLocation(program, 'u_time');
    const expansionLocation = gl.getUniformLocation(program, 'u_expansion');
    const resolutionLocation = gl.getUniformLocation(program, 'u_resolution');
    const colorLocation = gl.getUniformLocation(program, 'u_color');

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
      gl.viewport(0, 0, canvas.width, canvas.height);
    };
    window.addEventListener('resize', resize);
    resize();

    // Animation Loop
    const render = () => {
      // Access latest props
      const { expansion, color, speed } = propsRef.current;
      
      timeRef.current += 0.016 * speed;

      gl.useProgram(program);
      gl.bindBuffer(gl.ARRAY_BUFFER, buffer);

      gl.enableVertexAttribArray(positionLocation);
      gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

      gl.uniform1f(timeLocation, timeRef.current);
      gl.uniform1f(expansionLocation, expansion);
      gl.uniform2f(resolutionLocation, canvas.width, canvas.height);
      gl.uniform3f(colorLocation, color[0], color[1], color[2]);

      gl.clearColor(0.0, 0.0, 0.0, 0.0);
      gl.clear(gl.COLOR_BUFFER_BIT);

      gl.drawArrays(gl.TRIANGLES, 0, 6);
      
      requestRef.current = requestAnimationFrame(render);
    };

    render();

    return () => {
      window.removeEventListener('resize', resize);
      if (requestRef.current) cancelAnimationFrame(requestRef.current);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="absolute top-0 left-0 w-full h-full"
      style={{ pointerEvents: 'none' }}
    />
  );
};

export default BubbleShader;