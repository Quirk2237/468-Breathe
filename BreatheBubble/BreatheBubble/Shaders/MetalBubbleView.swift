import SwiftUI
import MetalKit

struct BubbleUniforms {
    var time: Float
    var expansion: Float
    var resolution: SIMD2<Float>
    var color: SIMD4<Float>
    var speed: Float
    var _padding1: Float = 0
    var _padding2: Float = 0
    var _padding3: Float = 0
}

// MARK: - Metal Bubble View (SwiftUI Wrapper)
struct MetalBubbleView: NSViewRepresentable {
    var expansion: Float
    var color: SIMD3<Float>
    var speed: Float
    var isMini: Bool
    var timerProgress: Float? // Optional timer ring
    
    init(expansion: Float, color: SIMD3<Float>, speed: Float = 1.0, isMini: Bool = false, timerProgress: Float? = nil) {
        self.expansion = expansion
        self.color = color
        self.speed = speed
        self.isMini = isMini
        self.timerProgress = timerProgress
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Transparent background
        mtkView.layer?.isOpaque = false
        mtkView.layer?.backgroundColor = .clear
        
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            context.coordinator.setup(device: device, isMini: isMini)
        }
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.expansion = expansion
        context.coordinator.color = color
        context.coordinator.speed = speed
        context.coordinator.timerProgress = timerProgress
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalBubbleView
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var timerPipelineState: MTLRenderPipelineState?
        var vertexBuffer: MTLBuffer?
        
        var expansion: Float = 0.0
        var color: SIMD3<Float> = SIMD3<Float>(0.4, 0.8, 1.0)
        var speed: Float = 1.0
        var timerProgress: Float?
        
        private var startTime: CFTimeInterval = CACurrentMediaTime()
        
        init(_ parent: MetalBubbleView) {
            self.parent = parent
            self.expansion = parent.expansion
            self.color = parent.color
            self.speed = parent.speed
            self.timerProgress = parent.timerProgress
        }
        
        func setup(device: MTLDevice, isMini: Bool) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            // Create vertex buffer (full screen quad)
            let vertices: [Float] = [
                // Position (x, y), TexCoord (u, v)
                -1, -1, 0, 0,
                 1, -1, 1, 0,
                -1,  1, 0, 1,
                 1,  1, 1, 1,
            ]
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
            
            // Load shaders
            guard let library = device.makeDefaultLibrary() else {
                print("Failed to load Metal library")
                return
            }
            
            let vertexFunction = library.makeFunction(name: "bubbleVertex")
            let fragmentFunction = library.makeFunction(name: isMini ? "miniBubbleFragment" : "bubbleFragment")
            
            // Create pipeline descriptor
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            // Enable blending for transparency
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            // Vertex descriptor
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
            
            // Create timer ring pipeline if needed
            if let timerFragmentFunction = library.makeFunction(name: "timerRingFragment") {
                let timerDescriptor = MTLRenderPipelineDescriptor()
                timerDescriptor.vertexFunction = vertexFunction
                timerDescriptor.fragmentFunction = timerFragmentFunction
                timerDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                timerDescriptor.colorAttachments[0].isBlendingEnabled = true
                timerDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                timerDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                timerDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                timerDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                timerDescriptor.vertexDescriptor = vertexDescriptor
                
                timerPipelineState = try? device.makeRenderPipelineState(descriptor: timerDescriptor)
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let pipelineState = pipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let vertexBuffer = vertexBuffer else { return }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            
            // Calculate time
            let currentTime = Float(CACurrentMediaTime() - startTime)
            
            // Create uniforms
            var uniforms = BubbleUniforms(
                time: currentTime,
                expansion: expansion,
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                color: SIMD4<Float>(color.x, color.y, color.z, 1.0),
                speed: speed
            )
            
            // Draw bubble
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BubbleUniforms>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            // Draw timer ring if progress is set
            if let progress = timerProgress, let timerPipeline = timerPipelineState {
                var timerUniforms = BubbleUniforms(
                    time: currentTime,
                    expansion: progress, // Reuse expansion for progress
                    resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                    color: SIMD4<Float>(1.0, 0.6, 0.2, 1.0), // Orange ring
                    speed: 1.0
                )
                
                encoder.setRenderPipelineState(timerPipeline)
                encoder.setFragmentBytes(&timerUniforms, length: MemoryLayout<BubbleUniforms>.size, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Preview
#Preview {
    MetalBubbleView(
        expansion: 0.5,
        color: SIMD3<Float>(0.4, 0.8, 1.0),
        speed: 1.0,
        isMini: false
    )
    .frame(width: 300, height: 300)
}

