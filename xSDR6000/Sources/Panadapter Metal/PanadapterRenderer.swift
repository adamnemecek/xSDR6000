//
//  PanadapterRenderer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/2/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import simd
import MetalKit
import Cocoa

public final class PanadapterRenderer : NSObject, MTKViewDelegate {
    
    let kFill = false
    
    struct Vertex {
        var coord: vector_uint2
        var texCoord: float2
    }
    
    struct Uniforms {
        var maxValue: Float
        var numberOfPoints: Float
        var color: float3
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _vertices: [Vertex] =
        [
            Vertex(coord: vector_uint2(  0, 15_000), texCoord: float2(0.0, 0.0)),    // 0
            Vertex(coord: vector_uint2(  1, 28_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  2, 60_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  3, 30_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  4, 42_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  5, 37_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  6, 12_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  7, 14_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  8, 34_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2(  9, 29_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2( 10,  9_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2( 11,      0), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2( 12, 14_000), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2( 13, 22_500), texCoord: float2(0.0, 0.0)),
            Vertex(coord: vector_uint2( 14, 10_000), texCoord: float2(0.0, 0.0)),   // 14
            
            Vertex(coord: vector_uint2(  0,      0), texCoord: float2(0.0, 1.0)),   // 15
            Vertex(coord: vector_uint2(  1,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  2,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  3,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  4,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  5,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  6,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  7,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  8,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2(  9,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2( 10,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2( 11,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2( 12,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2( 13,      0), texCoord: float2(0.0, 1.0)),
            Vertex(coord: vector_uint2( 14,      0), texCoord: float2(0.0, 1.0))    // 29
    ]
    
    fileprivate var _indicesNoFill: [UInt16] =
        [
            0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
    ]
    
    fileprivate var _indicesFill: [UInt16] =
        [
            15,0,16,1,17,2,18,3,19,4,20,5,21,6,22,7,23,8,24,9,25,10,26,11,27,12,28,13,29,14
    ]
    
    fileprivate var _uniforms: Uniforms!
    
    fileprivate weak var _view              :MTKView!
    fileprivate let _device                 :MTLDevice?
    fileprivate let _commandQueue           :MTLCommandQueue
    fileprivate let _renderPipelineState    :MTLRenderPipelineState
    fileprivate var _vertexBuffer           :MTLBuffer!
    fileprivate var _uniformBuffer          :MTLBuffer!
    fileprivate var _indexBuffer            :MTLBuffer!
    fileprivate var _clearColor             :MTLClearColor!
    fileprivate let _samplerState           :MTLSamplerState
    fileprivate let _texture                :MTLTexture
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init?(mtkView: MTKView) {
        
        _view = mtkView
        
        // use the RGBA format.
        _view.colorPixelFormat = .bgra8Unorm
        
        // get the clear color
        let background = NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        _view.clearColor = MTLClearColor(red: Double(background.redComponent),
                                         green: Double(background.greenComponent),
                                         blue: Double(background.blueComponent),
                                         alpha: Double(background.alphaComponent))
        
        //        _view.enableSetNeedsDisplay = true
        
        _uniforms = Uniforms(maxValue: 60_000.0, numberOfPoints: Float(_indicesNoFill.count), color: [0.7, 0.7, 0.0])
        
        // Ask for the default Metal device; this represents our GPU.
        _device = MTLCreateSystemDefaultDevice()
        if let device = _device {
            
            // Create the command queue we will be using to submit work to the GPU.
            _commandQueue = device.makeCommandQueue()
            
            // Compile the functions and other state into a pipeline object.
            do {
                _renderPipelineState = try PanadapterRenderer.buildRenderPipelineWithDevice(device, view: mtkView)
            }
            catch {
                fatalError("Unable to compile render pipeline state")
            }
            
            do {
                _texture = try PanadapterRenderer.buildTexture(name: "1x16", device)
            }
            catch {
                fatalError("Unable to load texture from main bundle")
            }
            
            // Make a texture sampler that wraps in both directions and performs bilinear filtering
            _samplerState = PanadapterRenderer.buildSamplerStateWithDevice(device, addressMode: .clampToEdge, filter: .linear)
            
            super.init()
            
            // create a Vertex Buffer for Vertices
            let dataSize = _vertices.count * MemoryLayout.size(ofValue: _vertices[0])
            _vertexBuffer = device.makeBuffer(bytes: _vertices, length: dataSize)
            
            // create a Vertex Buffer for Uniforms
            let uniformSize = MemoryLayout.size(ofValue: _uniforms)
            _uniformBuffer = device.makeBuffer(bytes: &_uniforms, length: uniformSize)
            
            // create an Index Buffer of the required size & type (Fill or NoFill)
            let indexSize = _indicesFill.count * MemoryLayout.size(ofValue: _indicesFill[0])
            _indexBuffer = device.makeBuffer(bytes: _indicesFill, length: indexSize)
            
            // set this renderer as the view's delegate
            _view.delegate = self
            
            // set the view's device
            _view.device = _device
            
        } else {
            
            fatalError("Metal is not supported")
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw in a Metal Kit view
    ///
    /// - Parameter view: the MTKView
    ///
    public func draw(in view: MTKView) {
        
        // create a command buffer
        let commandBuffer = _commandQueue.makeCommandBuffer()
        commandBuffer.label = "MyCommand"
        
        // Ask the view for a configured render pass descriptor
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        if let renderPassDescriptor = renderPassDescriptor {
            
            // Create a render encoder
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder.pushDebugGroup("Draw TriangleStrip")
            
            // Set the pipeline state
            renderEncoder.setRenderPipelineState(_renderPipelineState)
            
            // Bind the buffer containing the vertices
            renderEncoder.setVertexBuffer(_vertexBuffer, offset: 0, at: 0)
            
            // Bind the buffer containing the uniforms
            renderEncoder.setVertexBuffer(_uniformBuffer, offset: 0, at: 1)
            
            // Bind our texture so we can sample from it in the fragment shader
            renderEncoder.setFragmentTexture(_texture, at: 0)
            
            // Bind our sampler state so we can use it to sample the texture in the fragment shader
            renderEncoder.setFragmentSamplerState(_samplerState, at: 0)
            
            //            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: _vertices.count)
            
            // draw the points as a filled line
            renderEncoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: _indicesFill.count, indexType: .uint16, indexBuffer: _indexBuffer, indexBufferOffset: 0)
            
            renderEncoder.popDebugGroup()
            
            // indicate we're finished using this encoder
            renderEncoder.endEncoding()
            
            // Add a final command to present the drawable to the screen
            commandBuffer.present(view.currentDrawable!)
            
            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
    }
    /// Respond to changes in view size
    ///
    /// - Parameters:
    ///   - view:       an MTKView
    ///   - size:       the new size
    ///
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Class methods
    
    /// Build a render Pipeline State
    ///
    /// - Parameters:
    ///   - device:         the MTLDevice
    ///   - view:           the MTKView
    /// - Returns:          an MTLRenderPipelineState
    /// - Throws:           an error creating the return value
    ///
    class func buildRenderPipelineWithDevice(_ device: MTLDevice, view: MTKView) throws -> MTLRenderPipelineState {
        // The default library contains all of the shader functions that were compiled into our app bundle
        let library = device.newDefaultLibrary()!
        
        // Retrieve the functions that will comprise our pipeline
        let vertexFunction = library.makeFunction(name: "pan_vertex")
        let fragmentFunction = library.makeFunction(name: "pan_fragment")
        
        // A render pipeline descriptor describes the configuration of our programmable pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Render Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    class func buildTexture(name: String, _ device: MTLDevice) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        let asset = NSDataAsset.init(name: name)
        if let data = asset?.data {
            return try textureLoader.newTexture(with: data, options: [:])
        } else {
            fatalError("Could not load image \(name) from an asset catalog in the main bundle")
        }
    }
    
    class func buildSamplerStateWithDevice(_ device: MTLDevice,
                                           addressMode: MTLSamplerAddressMode,
                                           filter: MTLSamplerMinMagFilter) -> MTLSamplerState
    {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        return device.makeSamplerState(descriptor: samplerDescriptor)
    }
}
