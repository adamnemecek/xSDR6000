//
//  PanadapterRenderer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/2/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import xLib6000
import simd
import MetalKit
import Cocoa

public final class PanadapterRenderer : NSObject, MTKViewDelegate, PanadapterStreamHandler {
    
    enum Style {
        case line
        case fill
        case fillWithTexture
    }
    
    struct Vertex {
        var y:  ushort
        //        var texCoord: float2
    }
    
    struct Uniforms {
        var delta:          Float
        var height:         Float
        var color:          float4
        var textureEnable:  Bool
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _vertices: [ushort] =  [ushort](repeating: 0, count: 6000)
    
    fileprivate var _verticesCount = 0
    
    fileprivate var _indicesNoFill = [UInt16](repeating: 0, count: 3000)
    
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
    
    fileprivate var _verticesNumber = 0
    
//    fileprivate var _style = Style.line
//    fileprivate var _style = Style.fill
    fileprivate var _style = Style.fillWithTexture
    
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
        
        _view.enableSetNeedsDisplay = true
        
        // populate the indices used for style == .line
        for i in 0..<_indicesNoFill.count {
            _indicesNoFill[i] = UInt16(( 2 * i) + 1)
        }
        
        // set the uniforms
        //      delta is derived from the number of "real" vertices
        //      height is the height (pixels) of the view
        //      color is the line / fill color
        _uniforms = Uniforms( delta: 2.0/(Float(_view.frame.width) - 1.0), height: Float(_view.frame.height), color: [0.7, 0.7, 0.0, 0.7], textureEnable: _style == .fillWithTexture )
        
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
            let dataSize = _vertices.count * MemoryLayout.stride(ofValue: _vertices[0])
            _vertexBuffer = device.makeBuffer(bytes: _vertices, length: dataSize)
            
            // create a Vertex Buffer for Uniforms
            let uniformSize = MemoryLayout.stride(ofValue: _uniforms)
            _uniformBuffer = device.makeBuffer(bytes: &_uniforms, length: uniformSize)
            
            // create an Index Buffer of the required size & type (Fill or NoFill)
            let indexSize = _indicesNoFill.count * MemoryLayout.stride(ofValue: _indicesNoFill[0])
            _indexBuffer = device.makeBuffer(bytes: _indicesNoFill, length: indexSize)
            
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
            
            renderEncoder.pushDebugGroup("Draw LineStrip")
            
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
            
            // use the aappropriate draw method
            if _style == .line {
                
                // Line drawing
                renderEncoder.drawIndexedPrimitives(type: .lineStrip, indexCount: _verticesCount, indexType: .uint16, indexBuffer: _indexBuffer, indexBufferOffset: 0)
                
            } else {
                
                // Filled line (with or without Texture)
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: _verticesCount * 2)
            }
            
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

        _uniforms = Uniforms( delta: 2.0/(Float(_view.frame.width) - 1.0), height: Float(_view.frame.height), color: [0.7, 0.7, 0.0, 0.7], textureEnable: _style == .fillWithTexture )

        // re-create a Vertex Buffer for Uniforms
        let uniformSize = MemoryLayout.stride(ofValue: _uniforms)
        _uniformBuffer = _device!.makeBuffer(bytes: &_uniforms, length: uniformSize)

        Swift.print("\(_view.frame.width),\(_view.frame.height)")
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
    
    // ----------------------------------------------------------------------------
    // MARK: - PanadapterStreamHandler protocol methods
    //
    //  DataFrame Layout: (see xLib6000 PanadapterFrame)
    //
    //  public var startingBinIndex: Int                    // Index of first bin
    //  public var numberOfBins: Int                        // Number of bins
    //  public var binSize: Int                             // Bin size in bytes
    //  public var frameIndex: Int                          // Frame index
    //  public var bins: [UInt16]                           // Array of bin values
    //
    
    //
    // Process the UDP Stream Data for the Panadapter
    //
    public func panadapterStreamHandler(_ dataFrame: PanadapterFrame) {
        
        // dataFrame.numberOfBins is the number of points (horizontal) for the spectrum waveform
        _verticesCount = dataFrame.numberOfBins
        
        Swift.print("bins = \(_verticesCount)")
        
        // the dataFrame.bins contain the y-values (vertical) for the spectrum waveform
        // put them into the Vertex Buffer
        //      * 2 because of the synthetic points on the 0 axis to allow .fill or .fillWithTexture style
        _vertexBuffer.contents().copyBytes(from: dataFrame.bins, count: _verticesCount * 2 * MemoryLayout<ushort>.stride)
        
        DispatchQueue.main.async {
            
            autoreleasepool {
                
                // force a redraw
                self._view.needsDisplay = true
            }
        }
    }
}
