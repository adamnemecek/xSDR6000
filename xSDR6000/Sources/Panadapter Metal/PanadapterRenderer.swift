//
//  PanadapterRenderer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/2/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import xLib6000
import MetalKit
import Cocoa
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - PanadapterRenderer class implementation
// --------------------------------------------------------------------------------

public final class PanadapterRenderer : NSObject, MTKViewDelegate, PanadapterStreamHandler {
    
//  NOTE:
//
//  As input, the renderer expects an array of UInt16 intensity values. The intensity values are
//  scaled by the radio to be between zero and Panadapter.yPixels. The values are inverted
//  i.e. the value of Panadapter.yPixels is zero intensity and a value of zero is maximum intensity.
//  The Panadapter sends an array of size Panadapter.xPixels.
// 
    
    // Style of the drawing
    enum Style {
        case line
        case fill
        case fillWithTexture
    }
    // layout of a spectrum Vertex
    struct Vertex {
        var y:  ushort
    }
    // layout of a Grid Vertex
    struct GridVertex {
        var coord: float2
    }
    // layout of the Uniforms
    struct Uniforms {
        var delta:          Float
        var height:         Float
        var spectrumColor:  float4
        var gridColor:      float4
        var textureEnable:  Bool
    }
    
    static let kMaxVertexCount  = 3_000
    static let kTextureAsset    = "1x16"
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _vertices               = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxVertexCount * 2)
    fileprivate var _indicesNoFill          = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxVertexCount)
    fileprivate var _indicesFill            = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxVertexCount * 2)
    fileprivate var _verticesCount          = PanadapterRenderer.kMaxVertexCount
    fileprivate var _gridVertices           :[GridVertex]!
    
    fileprivate let _device                 :MTLDevice?
    fileprivate weak var _view              :MTKView!
    fileprivate var _commandQueue           :MTLCommandQueue!
    fileprivate var _spectrumRps            :MTLRenderPipelineState!
    fileprivate var _gridRps                :MTLRenderPipelineState!
    fileprivate var _vertexBuffer           :MTLBuffer!
    fileprivate var _gridVertexBuffer       :MTLBuffer!
    fileprivate var _uniformBuffer          :MTLBuffer!
    fileprivate var _indexBufferNoFill      :MTLBuffer!
    fileprivate var _indexBufferFill        :MTLBuffer!
    fileprivate var _gridIndexBuffer        :MTLBuffer!
    fileprivate var _clearColor             :MTLClearColor!
    fileprivate var _samplerState           :MTLSamplerState!
    fileprivate var _texture                :MTLTexture!

    fileprivate var _uniforms               :Uniforms!
    fileprivate var _style                  :Style!
    
    fileprivate var _spectrumColor          :float4!
    fileprivate var _gridColor              :float4!
    
    fileprivate var _gridIncrementX         :Float = 0.0
    fileprivate var _gridOffsetX            :Float = 0.0
    fileprivate var _gridIncrementY         :Float = 0.0
    fileprivate var _gridOffsetY            :Float = 0.0
    

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init?(mtkView: MTKView) {
        
        // get the Metal device i.e. the GPU
        guard let device = mtkView.device else {
            
            // initialization failed
            return nil
        }
        _device = device
        
        super.init()
        
        _view = mtkView
        
        // choose a drawing style
        _style = Style.fillWithTexture
        
        // redraw whenever needsDisplay is set
        _view.enableSetNeedsDisplay = true
        
        // use the RGBA format.
        _view.colorPixelFormat = .bgra8Unorm
        
        setupState(device: device, view: _view)
        
        // set the clear color
        setClearColor()
        
        // setup indices for indexed drawing
        setupIndices()
        
        // populate the Grid Vertices
        _gridVertices = makeGrid(xOffset: 0, xIncrement: 0.1, yOffset: 0, yIncrement: 0.2)
        
        // create & populate the needed MTLBuffers
        setupBuffers(device: device)

        // load all of the Uniforms
        updateUniforms()
        
        // set this renderer as the view's delegate
        _view.delegate = self
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
        commandBuffer.label = "Panadapter"
        
        // Ask the view for a configured render pass descriptor
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        if let renderPassDescriptor = renderPassDescriptor {
            
            // Create a render encoder
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder.pushDebugGroup("Spectrum")
            
            // Set the pipeline state
            renderEncoder.setRenderPipelineState(_spectrumRps)
            
            // Bind the buffer containing the vertices (position 0)
            renderEncoder.setVertexBuffer(_vertexBuffer, offset: 0, at: 0)
            
            // Bind the buffer containing the uniforms (position 1)
            renderEncoder.setVertexBuffer(_uniformBuffer, offset: 0, at: 1)

            // Bind the texture for the Fragment shader
            renderEncoder.setFragmentTexture(_texture, at: 0)
            
            // Bind the sampler state for the Fragment shader
            renderEncoder.setFragmentSamplerState(_samplerState, at: 0)

            // ----------------------------------------------------------------------------
            // *** DRAW the Spectrum ***
            
            // Line or Fill style?
            if _style == .line {
                
                // Line
                renderEncoder.drawIndexedPrimitives(type: .lineStrip, indexCount: _verticesCount, indexType: .uint16, indexBuffer: _indexBufferNoFill, indexBufferOffset: 0)
                
            } else {
                
                // Fill (with or without Texture)
                renderEncoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: _verticesCount * 2, indexType: .uint16, indexBuffer: _indexBufferFill, indexBufferOffset: 0)
            }
            renderEncoder.popDebugGroup()
            
            // ----------------------------------------------------------------------------
            // *** DRAW the Grid ***
            renderEncoder.pushDebugGroup("Grid")

            // Set the pipeline state
            renderEncoder.setRenderPipelineState(_gridRps)
            
            // Bind the buffer containing the Grid vertices (position 0)
            renderEncoder.setVertexBuffer(_gridVertexBuffer, offset: 0, at: 0)
            
            renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: _gridVertices.count)
            
            renderEncoder.popDebugGroup()
            
            // ----------------------------------------------------------------------------

            // finish using this encoder
            renderEncoder.endEncoding()
            
            // add a final command to present the drawable to the screen
            commandBuffer.present(view.currentDrawable!)
            
            // finalize rendering & push the command buffer to the GPU
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

        // update all of the uniform values
        updateUniforms()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Setup RenderPipeline, Texture & Sampler state
    ///
    /// - Parameters:
    ///   - device: <#device description#>
    ///   - view: <#view description#>
    func setupState(device: MTLDevice, view: MTKView) {
        
        // create the command queue
        _commandQueue = device.makeCommandQueue()
        
        // Compile the functions and other state into a pipeline object.
        guard let spectrumRps =  try? PanadapterRenderer.renderPipeline(forDevice: device, view: view, vertexShader: "pan_vertex", fragmentShader: "pan_fragment") else {
            fatalError("Unable to compile render pipeline state on \(String(describing: device.name))")
        }
        _spectrumRps = spectrumRps
        
        // Compile the functions and other state into a pipeline object.
        guard let gridRps =  try? PanadapterRenderer.renderPipeline(forDevice: device, view: view, vertexShader: "grid_vertex", fragmentShader: "grid_fragment") else {
            fatalError("Unable to compile render pipeline state on \(String(describing: device.name))")
        }
        _gridRps = gridRps
        
        // create a texture
        guard let texture =  try? PanadapterRenderer.texture(forDevice: device, asset: PanadapterRenderer.kTextureAsset) else {
            fatalError("Unable to load texture (\(PanadapterRenderer.kTextureAsset)) from main bundle")
        }
        _texture = texture
        
        // create a texture sampler
        _samplerState = PanadapterRenderer.samplerState(forDevice: device, addressMode: .clampToEdge, filter: .linear)
    }
    
    /// Populate the indexed drawing arrays
    ///
    func setupIndices() {
        
        // populate the indices used for style == .line
        for i in 0..<PanadapterRenderer.kMaxVertexCount {
            // 0,1,2...n-1
            _indicesNoFill[i] = UInt16(i)
        }
        
        // populate the indices used for style == .fill || style == .fillWithTexture
        for i in 0..<PanadapterRenderer.kMaxVertexCount {
            // n,0,n+1,1,...2n-1,n-1
            _indicesFill[2 * i] = UInt16(PanadapterRenderer.kMaxVertexCount + i)
            _indicesFill[(2 * i) + 1] = UInt16(i)
        }
    }
    /// Create & Populate the MTLBuffers
    ///
    /// - Parameter device:     the MTLDevice
    ///
    func setupBuffers(device: MTLDevice) {
        
        // create a Vertex Buffer for Vertices
        let dataSize = _vertices.count * MemoryLayout.stride(ofValue: _vertices[0])
        _vertexBuffer = device.makeBuffer(bytes: _vertices, length: dataSize)
        
        // create a Vertex Buffer for Uniforms
        let uniformSize = MemoryLayout.stride(ofValue: _uniforms)
        _uniformBuffer = device.makeBuffer(length: uniformSize)
        
        // create an Index Buffer
        var indexSize = _indicesNoFill.count * MemoryLayout.stride(ofValue: _indicesNoFill[0])
        _indexBufferNoFill = device.makeBuffer(bytes: _indicesNoFill, length: indexSize)
        
        // create an Index Buffer
        indexSize = _indicesFill.count * MemoryLayout.stride(ofValue: _indicesFill[0])
        _indexBufferFill = device.makeBuffer(bytes: _indicesFill, length: indexSize)
        
        // create a Vertex Buffer for Grid Vertices
        let gridDataSize = _vertices.count * MemoryLayout.stride(ofValue: _gridVertices[0])
        _gridVertexBuffer = device.makeBuffer(bytes: _gridVertices, length: gridDataSize)
    }
    /// Create vertices for a Grid (in normalized clip space coordinates)
    ///
    /// - Parameters:
    ///   - xOffset:        initial offset in x (pixels from left)
    ///   - xIncrement:     x increment between vertical lines (pixels)
    ///   - yOffset:        initial offset in y (pixels from bottom)
    ///   - yIncrement:     y increment between horizontal lines (pixels)
    /// - Returns:          an array of GridVertex (pixels)
    ///
    func makeGrid(xOffset: Float, xIncrement: Float, yOffset: Float, yIncrement: Float) -> [GridVertex] {
        var grid = [GridVertex]()
        
        // calculate the starting x location
        var xLocation: Float = -1.0 + xOffset
        
        // create vertical lines
        while xLocation <= 1.0 {
            grid.append(GridVertex(coord: float2(x: xLocation, y: -1.0)))
            grid.append(GridVertex(coord: float2(x: xLocation, y:  1.0)))
            xLocation += xIncrement
        }
        // calculate the starting y location
        var yLocation: Float = -1.0 + yOffset
        
        // create horizontal lines
        while yLocation <= 1.0 {
            grid.append(GridVertex(coord: float2(x: -1.0, y: yLocation)))
            grid.append(GridVertex(coord: float2(x:  1.0, y: yLocation)))
            yLocation += yIncrement
        }
        return grid
    }
    /// Set the Clear Color with the value from the Preferences
    ///
    func setClearColor() {
        
        // get & set the clear color
        let color = Defaults[.spectrumBackground]
        _view.clearColor = MTLClearColor(red: Double(color.redComponent),
                                         green: Double(color.greenComponent),
                                         blue: Double(color.blueComponent),
                                         alpha: Double(color.alphaComponent))
    }
    /// Update all of the uniform values
    ///
    func updateUniforms() {
        
        // get the color for the Spectrum
        var color = Defaults[.spectrum]
        _spectrumColor = float4(Float(color.redComponent),
                                Float(color.greenComponent),
                                Float(color.blueComponent),
                                Float(color.alphaComponent))
        
        // get the color for the Grid Lines
        color = Defaults[.gridLines]
        _gridColor = float4(Float(color.redComponent),
                            Float(color.greenComponent),
                            Float(color.blueComponent),
                            Float(color.alphaComponent))
        
        // set the uniforms
        _uniforms = Uniforms( delta: 2.0/(Float(_view.frame.width) - 1.0),
                              height: Float(_view.frame.height),
                              spectrumColor: _spectrumColor,
                              gridColor: _gridColor,
                              textureEnable: _style == .fillWithTexture )
        
        // update the Uniforms buffer
        let bufferPtr = _uniformBuffer.contents()
        memcpy(bufferPtr, &_uniforms, MemoryLayout<Uniforms>.size)
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
    class func renderPipeline(forDevice device: MTLDevice, view: MTKView, vertexShader: String, fragmentShader: String) throws -> MTLRenderPipelineState {
        
        // get the default library
        let library = device.newDefaultLibrary()!
        
        // get the functions vertex & fragment functions that were compiled into the library
        let vertexFunction = library.makeFunction(name: vertexShader)
        let fragmentFunction = library.makeFunction(name: fragmentShader)
        
        // create a render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // set its parameters
        pipelineDescriptor.label = "Render Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        // return the Render Pipeline State
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    /// Create a Texture from an image in the Assets.xcassets
    ///
    /// - Parameters:
    ///   - name:       name of the asset
    ///   - device:     a Metal Device
    /// - Returns:      a MTLTexture
    /// - Throws:       Texture loader error
    ///
    class func texture(forDevice device: MTLDevice, asset name: String) throws -> MTLTexture {
        
        // get a Texture loader
        let textureLoader = MTKTextureLoader(device: device)
        
        // identify the asset containing the image
        let asset = NSDataAsset.init(name: name)
        
        if let data = asset?.data {
            
            // if found, create the texture
            return try textureLoader.newTexture(with: data, options: [:])
        } else {
            
            // image not found
            fatalError("Could not load image \(name) from an asset catalog in the main bundle")
        }
    }
    /// Create a Sampler State
    ///
    /// - Parameters:
    ///   - device:         a MTLDevice
    ///   - addressMode:    the desired Sampler address mode
    ///   - filter:         the desired Sampler filtering
    /// - Returns:          a MTLSamplerState
    ///
    class func samplerState(forDevice device: MTLDevice,
                                           addressMode: MTLSamplerAddressMode,
                                           filter: MTLSamplerMinMagFilter) -> MTLSamplerState {
        // create a Sampler Descriptor
        let samplerDescriptor = MTLSamplerDescriptor()
        
        // set its parameters
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        
        // return the Sampler State
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
        
        // dataFrame.numberOfBins is the number of "real" points (horizontal) for the spectrum waveform
        _verticesCount = dataFrame.numberOfBins
        
        // the dataFrame.bins contain the y-values (vertical) for the spectrum waveform
        // put them into the Vertex Buffer
        _vertexBuffer.contents().copyBytes(from: dataFrame.bins, count: _verticesCount * MemoryLayout<ushort>.stride)
        
        DispatchQueue.main.async {
            
            autoreleasepool {
                
                // force a redraw
                self._view.needsDisplay = true
            }
        }
    }
}
