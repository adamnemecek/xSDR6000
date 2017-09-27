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
//  The Panadapter sends an array of size Panadapter.xPixels (same as frame.width).
// 
    
    // Style of the drawing
    enum Style {
        case line
        case fill
        case fillWithTexture
    }
    // layout of a spectrum Vertex
    struct SpectrumVertex {
        var i                   :ushort                 // intensity
    }
    // layout of a Tnf Vertex
    struct TnfVertex {
        var coord               :float2                 // x,y coordinates
        var color               :float4                 // color
    }
    // layout of a Grid, Slice or Frequency Line Vertex
    struct StdVertex {
        var coord               :float2                 // x,y coordinates
    }
    // layout of the Uniforms
    struct Uniforms {
        var delta               :Float                  // distance between x coordinates
        var height              :Float                  // height of view (yPixels)
        var spectrumColor       :float4                 // spectrum color
        var gridColor           :float4                 // grid color
        var tnfInactiveColor    :float4                 // inactive Tnf color
        var textureEnable       :Bool                   // texture enabled
    }
    
    static let kMaxVertexCount  = 3_000
    static let kTextureAsset    = "1x16"

    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    var tnfVertices                                 = [TnfVertex]()
    var uniforms                                    :Uniforms!

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _spectrumVertices               = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxVertexCount * 2)
    fileprivate var _spectrumVerticesCount          = PanadapterRenderer.kMaxVertexCount
    fileprivate var _spectrumVerticesBuffer         :MTLBuffer!
    fileprivate var _spectrumRps                    :MTLRenderPipelineState!
    
    fileprivate var _spectrumIndicesFill            = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxVertexCount * 2)
    fileprivate var _spectrumIndicesBufferFill      :MTLBuffer!
    fileprivate var _spectrumIndicesNoFill          = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxVertexCount)
    fileprivate var _spectrumIndicesBufferNoFill    :MTLBuffer!
    
    fileprivate var _gridVertices                   :[StdVertex]!
    fileprivate var _gridVerticesBuffer             :MTLBuffer!
    fileprivate var _gridIndexBuffer                :MTLBuffer!
    fileprivate var _stdRps                         :MTLRenderPipelineState!
    
    fileprivate var _sliceVertices                  :[StdVertex]!
    fileprivate var _sliceVerticesBuffer            :MTLBuffer!

    fileprivate var _tnfVerticesBuffer              :MTLBuffer?
    fileprivate var _tnfRps                         :MTLRenderPipelineState!
    
    fileprivate var _uniformsBuffer                 :MTLBuffer?

    fileprivate var _texture                        :MTLTexture!
    fileprivate var _samplerState                   :MTLSamplerState!

    fileprivate let _device                         :MTLDevice?
    fileprivate weak var _view                      :MTKView!
    fileprivate var _commandQueue                   :MTLCommandQueue!
    fileprivate var _clearColor                     :MTLClearColor!
    fileprivate var _spectrumColor                  :float4!
    fileprivate var _gridColor                      :float4!

    fileprivate var _style                          :Style!
    
    fileprivate var _gridIncrementX                 :Float = 0.0
    fileprivate var _gridOffsetX                    :Float = 0.0
    fileprivate var _gridIncrementY                 :Float = 0.0
    fileprivate var _gridOffsetY                    :Float = 0.0
        
    fileprivate let kxLowIndex                      = 0
    fileprivate let kxHighIndex                     = 4

    
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
        _style = Style.line
        
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
        
        // setup the Uniforms
        populateUniforms()
        updateUniformsBuffer()

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
            
            // *** DRAW the Grid ***
            drawGrid( encoder: renderEncoder )
            
            // *** DRAW the Tnf(s) ***
//            drawTnfs( encoder: renderEncoder )
            
            // *** DRAW the Slice Outline(s) ***
//            drawSlices( encoder: renderEncoder )

            // *** DRAW the Slice Frequency Line(s) ***
//            drawFrequencyLines( encoder: renderEncoder )

            // *** DRAW the Spectrum ***
            drawSpectrum( encoder: renderEncoder )
            
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

        let adjSize = _view.convertFromBacking(size)

        // update the height & width
        uniforms.height = Float(adjSize.height)
        
        // calculate delta
        uniforms.delta = Float( 1.0 / (adjSize.width - 1.0) )

        // copy the values to the Uniforms buffer
        updateUniformsBuffer()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
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
    /// Update the Tnf values
    ///
    func updateTnfs() {
        
        if tnfVertices.count != 0 {
            
            // create a Buffer for Tnf Vertices
            let tnfDataSize = tnfVertices.count * MemoryLayout.stride(ofValue: tnfVertices[0])
            _tnfVerticesBuffer = _device!.makeBuffer(bytes: tnfVertices, length: tnfDataSize)
        
        } else {
            
            _tnfVerticesBuffer = nil
        }
    }
    /// Populate uniform values
    ///
    func populateUniforms() {
        
        // get the color for the Spectrum
        var color = Defaults[.spectrum]
        let spectrumColor = float4(Float(color.redComponent),
                                   Float(color.greenComponent),
                                   Float(color.blueComponent),
                                   Float(color.alphaComponent))
        
        // get the color for the Grid Lines
        color = Defaults[.gridLines]
        let gridColor = float4(Float(color.redComponent),
                               Float(color.greenComponent),
                               Float(color.blueComponent),
                               Float(color.alphaComponent))
        
        // get the color for the Inactive Tnf
        color = Defaults[.tnfInactive]
        let tnfInactiveColor = float4(Float(color.redComponent),
                                      Float(color.greenComponent),
                                      Float(color.blueComponent),
                                      Float(color.alphaComponent))
        

        // populate the uniforms
        
        let adjSize = _view.convertFromBacking(_view.drawableSize)
        
        uniforms = Uniforms(delta: Float(1.0 / (adjSize.width - 1.0)),
                            height: Float(adjSize.height),
                            spectrumColor: spectrumColor,
                            gridColor: gridColor,
                            tnfInactiveColor: tnfInactiveColor,
                            textureEnable: _style != .line)
    }
    
    func updateUniformsBuffer() {
        
        let uniformSize = MemoryLayout.stride(ofValue: uniforms)

        // has the Uniforms buffer been created?
        if _uniformsBuffer == nil {

            // NO, create one
            _uniformsBuffer = _device!.makeBuffer(length: uniformSize)
        }
        
        // update the Uniforms buffer
        let bufferPtr = _uniformsBuffer!.contents()
        memcpy(bufferPtr, &uniforms, uniformSize)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Draw the Grid
    ///
    /// - Parameter encoder:        a Render Encoder
    ///
    private func drawGrid(encoder: MTLRenderCommandEncoder) {
        
        encoder.pushDebugGroup("Grid")
        
        // use the Grid pipeline state
        encoder.setRenderPipelineState(_stdRps)
        
        // bind the buffer containing the Grid vertices (position 0)
        encoder.setVertexBuffer(_gridVerticesBuffer, offset: 0, at: 0)
        
        // bind the buffer containing the uniforms (position 1)
        encoder.setVertexBuffer(_uniformsBuffer, offset: 0, at: 1)
        
        // draw
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: _gridVertices.count)
        
        encoder.popDebugGroup()
    }
    /// Draw the Tnf's (if any)
    ///
    /// - Parameter encoder:        a Render Encoder
    ///
    private func drawTnfs(encoder: MTLRenderCommandEncoder) {
        
//        if _tnfVerticesBuffer != nil {
//
//            encoder.pushDebugGroup("Tnf")
//
//            // use the Tnf pipeline state
//            encoder.setRenderPipelineState(_tnfRps)
//
//            // bind the buffer containing the Tnf vertices (position 0)
//            encoder.setVertexBuffer(_tnfVerticesBuffer, offset: 0, at: 0)
//
//            // draw
//            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: tnfVertices.count)
//
//            encoder.popDebugGroup()
//        }
    }
    /// Draw the Slices (if any)
    ///
    /// - Parameter encoder:        a Render Encoder
    ///
    private func drawSlices(encoder: MTLRenderCommandEncoder) {
        
//        encoder.pushDebugGroup("Slice")
//        
//        // use the Slice pipeline state
//        encoder.setRenderPipelineState(_stdRps)
//        
//        // bind the buffer containing the Slice vertices (position 0)
//        encoder.setVertexBuffer(_sliceVerticesBuffer, offset: 0, at: 0)
//        
//        // draw
//        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: _sliceVertices.count)
//        
//        encoder.popDebugGroup()
    }
    /// Draw the Slice Frequency lines (if any)
    ///
    /// - Parameter encoder:        a Render Encoder
    ///
    private func drawFrequencyLines(encoder: MTLRenderCommandEncoder) {
        
//        encoder.pushDebugGroup("Slice")
//        
//        // use the Slice pipeline state
//        encoder.setRenderPipelineState(_stdRps)
//        
//        // bind the buffer containing the Slice vertices (position 0)
//        encoder.setVertexBuffer(_sliceVerticesBuffer, offset: 0, at: 0)
//        
//        // draw
//        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: _sliceVertices.count)
//        
//        encoder.popDebugGroup()
    }
    /// Draw the Spectrum
    ///
    /// - Parameter encoder:        a Render Encoder
    ///
    private func drawSpectrum(encoder: MTLRenderCommandEncoder) {
        
        encoder.pushDebugGroup("Spectrum")
        
        // use the Spectrum pipeline state
        encoder.setRenderPipelineState(_spectrumRps)
        
        // bind the buffer containing the Spectrum vertices (position 0)
        encoder.setVertexBuffer(_spectrumVerticesBuffer, offset: 0, at: 0)
        
        // bind the Spectrum texture for the Fragment shader
        encoder.setFragmentTexture(_texture, at: 0)
        
        // bind the sampler state for the Fragment shader
        encoder.setFragmentSamplerState(_samplerState, at: 0)
        
        // Line or Fill style?
        if _style == .line {
            
            // Draw as a Line
            encoder.drawIndexedPrimitives(type: .lineStrip, indexCount: _spectrumVerticesCount, indexType: .uint16, indexBuffer: _spectrumIndicesBufferNoFill, indexBufferOffset: 0)
            
        } else {
            
            // Draw filled (with or without Texture)
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: _spectrumVerticesCount * 2, indexType: .uint16, indexBuffer: _spectrumIndicesBufferFill, indexBufferOffset: 0)
        }
        encoder.popDebugGroup()
    }
    /// Setup RenderPipeline, Texture & Sampler state
    ///
    /// - Parameters:
    ///   - device:         the Metal device
    ///   - view:           the Metal Kit view
    ///
    private func setupState(device: MTLDevice, view: MTKView) {
        
        // create the command queue
        _commandQueue = device.makeCommandQueue()
        
        // Compile the functions and other state into a pipeline object.
        guard let spectrumRps =  try? PanadapterRenderer.renderPipeline(forDevice: device, view: view, vertexShader: "pan_vertex", fragmentShader: "pan_fragment") else {
            fatalError("Unable to compile render pipeline state on \(String(describing: device.name))")
        }
        _spectrumRps = spectrumRps
        
        // Compile the functions and other state into a pipeline object.
        guard let tnfRps =  try? PanadapterRenderer.renderPipeline(forDevice: device, view: view, vertexShader: "tnf_vertex", fragmentShader: "tnf_fragment") else {
            fatalError("Unable to compile render pipeline state on \(String(describing: device.name))")
        }
        _tnfRps = tnfRps

        // Compile the functions and other state into a pipeline object.
        guard let stdRps =  try? PanadapterRenderer.renderPipeline(forDevice: device, view: view, vertexShader: "std_vertex", fragmentShader: "std_fragment") else {
            fatalError("Unable to compile render pipeline state on \(String(describing: device.name))")
        }
        _stdRps = stdRps
        
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
    private func setupIndices() {
        
        // populate the indices used for style == .line
        for i in 0..<PanadapterRenderer.kMaxVertexCount {
            // 0,1,2...n-1
            _spectrumIndicesNoFill[i] = UInt16(i)
        }
        
        // populate the indices used for style == .fill || style == .fillWithTexture
        for i in 0..<PanadapterRenderer.kMaxVertexCount {
            // n,0,n+1,1,...2n-1,n-1
            _spectrumIndicesFill[2 * i] = UInt16(PanadapterRenderer.kMaxVertexCount + i)
            _spectrumIndicesFill[(2 * i) + 1] = UInt16(i)
        }
    }
    /// Create & Populate the MTLBuffers
    ///
    /// - Parameter device:     the MTLDevice
    ///
    private func setupBuffers(device: MTLDevice) {
        
        // create a Buffer for Spectrum Vertices
        let dataSize = _spectrumVertices.count * MemoryLayout.stride(ofValue: _spectrumVertices[0])
        _spectrumVerticesBuffer = device.makeBuffer(bytes: _spectrumVertices, length: dataSize)
        
        // create a Buffer for Indices for non-filled drawing (lineStrip)
        var indexSize = _spectrumIndicesNoFill.count * MemoryLayout.stride(ofValue: _spectrumIndicesNoFill[0])
        _spectrumIndicesBufferNoFill = device.makeBuffer(bytes: _spectrumIndicesNoFill, length: indexSize)
        
        // create a Buffer for Indices for filled drawing (triangleStrip)
        indexSize = _spectrumIndicesFill.count * MemoryLayout.stride(ofValue: _spectrumIndicesFill[0])
        _spectrumIndicesBufferFill = device.makeBuffer(bytes: _spectrumIndicesFill, length: indexSize)
        
        // create a Buffer for Grid Vertices
        let gridDataSize = _gridVertices.count * MemoryLayout.stride(ofValue: _gridVertices[0])
        _gridVerticesBuffer = device.makeBuffer(bytes: _gridVertices, length: gridDataSize)
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
    private func makeGrid(xOffset: Float, xIncrement: Float, yOffset: Float, yIncrement: Float) -> [StdVertex] {
        var grid = [StdVertex]()
        
        // calculate the starting x location
        var xLocation: Float = -1.0 + xOffset
        
        // create vertical lines
        while xLocation <= 1.0 {
            grid.append(StdVertex(coord: float2(x: xLocation, y: -1.0)))
            grid.append(StdVertex(coord: float2(x: xLocation, y:  1.0)))
            xLocation += xIncrement
        }
        // calculate the starting y location
        var yLocation: Float = -1.0 + yOffset
        
        // create horizontal lines
        while yLocation <= 1.0 {
            grid.append(StdVertex(coord: float2(x: -1.0, y: yLocation)))
            grid.append(StdVertex(coord: float2(x:  1.0, y: yLocation)))
            yLocation += yIncrement
        }
        return grid
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
        
        // setup blending
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .destinationAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .destinationAlpha
        
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
        
        // dataFrame.numberOfBins is the number of horizontal pixels in the spectrum waveform
        //      (same as the frame.width & the panadapter.xPixels)
        _spectrumVerticesCount = dataFrame.numberOfBins
        
        // the dataFrame.bins contain the y-values (vertical) for the spectrum waveform
        // put them into the Vertex Buffer
        //      see the NOTE at the top of this class
        _spectrumVerticesBuffer.contents().copyBytes(from: dataFrame.bins, count: _spectrumVerticesCount * MemoryLayout<ushort>.stride)
        DispatchQueue.main.async {
            
            autoreleasepool {
                
                // force a redraw
                self._view.needsDisplay = true
            }
        }
    }
}
