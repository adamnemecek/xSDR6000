//
//  PanadapterLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/30/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import MetalKit
import xLib6000
import SwiftyUserDefaults

public final class PanadapterLayer: CAMetalLayer, CALayerDelegate, PanadapterStreamHandler {
    
    //  NOTE:
    //
    //  As input, the renderer expects an array of UInt16 intensity values. The intensity values are
    //  scaled by the radio to be between zero and Panadapter.yPixels. The values are inverted
    //  i.e. the value of Panadapter.yPixels is zero intensity and a value of zero is maximum intensity.
    //  The Panadapter sends an array of size Panadapter.xPixels (same as frame.width).
    //
    
    enum SpectrumStyle {
        case line                                       // line, no fill
        case fill                                       // line with solid fill
        case fillWithTexture                            // line with textured fill
    }

    struct SpectrumValue {
        var i                   : ushort                // intensity
    }

    struct Uniforms {
        var delta               : Float                 // distance between x coordinates
        var height              : Float                 // height of view (yPixels)
        var spectrumColor       : float4                // spectrum color
        var textureEnable       : Bool                  // texture on / off
    }
    
    static let kMaxIntensities  = 3_072                 // max number of intensity values (bins)
    static let kTextureAsset    = "1x16"                // name of the texture asset
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    var spectrumStyle                               = SpectrumStyle.line
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _spectrumValues                 = [UInt16](repeating: 0, count: PanadapterLayer.kMaxIntensities * 2)
    fileprivate var _spectrumValuesCount            = PanadapterLayer.kMaxIntensities
    fileprivate var _spectrumValuesBuffer           :MTLBuffer!
    fileprivate var _spectrumIndices                = [UInt16](repeating: 0, count: PanadapterLayer.kMaxIntensities * 2)
    fileprivate var _spectrumIndicesBuffer          :MTLBuffer!
    fileprivate var _spectrumPipelineState          :MTLRenderPipelineState!

    fileprivate var _uniforms                       :Uniforms!
    fileprivate var _uniformsBuffer                 :MTLBuffer?
    fileprivate var _texture                        :MTLTexture!
    fileprivate var _samplerState                   :MTLSamplerState!    
    fileprivate var _commandQueue                   :MTLCommandQueue!
    fileprivate var _clearColor                     :MTLClearColor?

    // constants
    fileprivate let _log                            = (NSApp.delegate as! AppDelegate)
    fileprivate let kSpectrumVertex                 = "spectrum_vertex"
    fileprivate let kSpectrumFragment               = "spectrum_fragment"

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw in a Metal layer
    ///
    public func render() {
        
        // obtain a drawable
        guard let drawable = nextDrawable() else { return }
        
        // create a command buffer
        let cmdBuffer = _commandQueue.makeCommandBuffer()
        
        // Draw the Spectrum
        drawSpectrum(with: drawable, cmdBuffer: cmdBuffer)
        
        // add a final command to present the drawable to the screen
        cmdBuffer.present(drawable)
        
        // finalize rendering & push the command buffer to the GPU
        cmdBuffer.commit()
    }
   
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Populate Uniform values
    ///
    func populateUniforms(size: CGSize) {
        
        // populate the uniforms
        _uniforms = Uniforms(delta: Float(1.0 / (size.width - 1.0)),
                             height: Float(size.height),
                             spectrumColor: Defaults[.spectrum].float4Color,
                             textureEnable: spectrumStyle == .fillWithTexture)
    }
    
    /// Copy uniforms data to the Uniforms Buffer (create Buffer if needed)
    ///
    func updateUniformsBuffer() {
        
        let uniformSize = MemoryLayout.stride(ofValue: _uniforms)
        
        // has the Uniforms buffer been created?
        if _uniformsBuffer == nil {
            
            // NO, create one
            _uniformsBuffer = device!.makeBuffer(length: uniformSize)
        }
        
        // update the Uniforms buffer
        let bufferPtr = _uniformsBuffer!.contents()
        memcpy(bufferPtr, &_uniforms, uniformSize)
    }
    /// Setup Buffers & State
    ///
    func setupBuffers() {
        
        // create and save a Buffer for Spectrum Values
        let dataSize = _spectrumValues.count * MemoryLayout.stride(ofValue: _spectrumValues[0])
        _spectrumValuesBuffer = device!.makeBuffer(bytes: _spectrumValues, length: dataSize)
        
        // populate the indices used for style == .fill || style == .fillWithTexture
        for i in 0..<PanadapterLayer.kMaxIntensities {
            // n,0,n+1,1,...2n-1,n-1
            _spectrumIndices[2 * i] = UInt16(PanadapterLayer.kMaxIntensities + i)
            _spectrumIndices[(2 * i) + 1] = UInt16(i)
        }
        // create a Buffer for Indices for filled drawing
        let indexSize = _spectrumIndices.count * MemoryLayout.stride(ofValue: _spectrumIndices[0])
        _spectrumIndicesBuffer = device!.makeBuffer(bytes: _spectrumIndices, length: indexSize)

        // create and save a texture
        guard let texture =  try? PanadapterLayer.texture(forDevice: device!, asset: PanadapterLayer.kTextureAsset) else {
            fatalError("Unable to load texture (\(PanadapterLayer.kTextureAsset)) from main bundle")
        }
        _texture = texture
        
        // create and save a texture sampler
        _samplerState = PanadapterLayer.samplerState(forDevice: device!, addressMode: .clampToEdge, filter: .linear)

        // get the Library (contains all compiled .metal files in this project)
        let library = device!.newDefaultLibrary()!

        // create a Render Pipeline Descriptor for the Spectrum
        let spectrumPipelineDesc = MTLRenderPipelineDescriptor()
        spectrumPipelineDesc.vertexFunction = library.makeFunction(name: kSpectrumVertex)
        spectrumPipelineDesc.fragmentFunction = library.makeFunction(name: kSpectrumFragment)
        spectrumPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // create and save the Render Pipeline State object
        _spectrumPipelineState = try! device!.makeRenderPipelineState(descriptor: spectrumPipelineDesc)
        
        // create and save a Command Queue object
        _commandQueue = device!.makeCommandQueue()
    }
    /// Set the Metal clear color
    ///
    /// - Parameter color:      an NSColor
    ///
    func setClearColor(_ color: NSColor) {
        _clearColor = MTLClearColor(red: Double(color.redComponent),
                                    green: Double(color.greenComponent),
                                    blue: Double(color.blueComponent),
                                    alpha: Double(color.alphaComponent))
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Draw the Spectrum
    ///
    /// - Parameter encoder:        a Render Encoder
    ///
    private func drawSpectrum(with drawable: CAMetalDrawable, cmdBuffer: MTLCommandBuffer) {
        
        // setup a render pass descriptor
        let renderPassDesc = MTLRenderPassDescriptor()
        renderPassDesc.colorAttachments[0].texture = drawable.texture
        renderPassDesc.colorAttachments[0].loadAction = .clear
        renderPassDesc.colorAttachments[0].clearColor = _clearColor!
        
        // Create a render encoder
        let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)
        
        encoder.pushDebugGroup("Spectrum")
        
        // use the Spectrum pipeline state
        encoder.setRenderPipelineState(_spectrumPipelineState)
        
        // bind the buffer containing the Spectrum vertices (position 0)
        encoder.setVertexBuffer(_spectrumValuesBuffer, offset: 0, at: 0)
        
        // bind the Spectrum texture for the Fragment shader
        encoder.setFragmentTexture(_texture, at: 0)
        
        // bind the sampler state for the Fragment shader
        encoder.setFragmentSamplerState(_samplerState, at: 0)
        
        // bind the buffer containing the Uniforms (position 1)
        encoder.setVertexBuffer(_uniformsBuffer, offset: 0, at: 1)
        
        if spectrumStyle == .line {
            // Draw as a Line
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: _spectrumValuesCount)
            
        } else {
            // Draw filled (with or without Texture)
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: _spectrumValuesCount * 2, indexType: .uint16, indexBuffer: _spectrumIndicesBuffer, indexBufferOffset: 0)
        }
        encoder.popDebugGroup()
        
        // finish using this encoder
        encoder.endEncoding()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Class methods
    
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
        _spectrumValuesCount = dataFrame.numberOfBins
        
        // the dataFrame.bins contain the y-values (vertical) for the spectrum waveform
        // put them into the Vertex Buffer
        //      see the NOTE at the top of this class
        _spectrumValuesBuffer.contents().copyBytes(from: dataFrame.bins, count: _spectrumValuesCount * MemoryLayout<ushort>.stride)
        DispatchQueue.main.async {
            
            autoreleasepool {
                
                // draw
                self.render()
            }
        }
    }
}
