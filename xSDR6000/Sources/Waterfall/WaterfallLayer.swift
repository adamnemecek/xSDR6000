//
//  WaterfallLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import MetalKit
import xLib6000
import SwiftyUserDefaults

public final class WaterfallLayer: CAMetalLayer, CALayerDelegate, WaterfallStreamHandler {
    
    //  NOTE:
    //
    //  As input, the stream handler expects an array of UInt16 intensity values. The intensity
    //  values are scaled by the radio to be between zero and UInt16.max. The intensity values
    //  are converted to color values using a gradient. The converted values are written into
    //  the current line of the texture (i.e. the "top" of the waterfall display). As each new line
    //  arrives from the Radio the previous screen content (the texture) is scrolled down one line.
    //
    //  The Waterfall sends an array of size ??? (larger than frame.width). Only the usable portion
    //  is displayed because of the clip space conversion (values outside of -1 to +1 are ignored).
    //
    
    struct Vertex {
        var coord                               : float2                // waterfall coordinates
        var texCoord                            : float2                // texture coordinates
    }
    
    struct Uniforms {
        var numberOfBins                        : Float                 // # of bins in stream width
        var numberOfDisplayBins                 : Float                 // # of bins in display width
        var halfBinWidth                        : Float                 // clip space x offset (half of a bin)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    var params                                  : Params!               // Radio & Panadapter references
    var gradient                                = Gradient(0)           // color gradient
    var autoBlackLevel                          : UInt32 = 0            // black level calculated by the Radio

    // ----------------------------------------------------------------------------
    // MARK: - Private properties    

    fileprivate var _radio                      : Radio { return params.radio }
    fileprivate var _panadapter                 : Panadapter? { return params.panadapter }
    fileprivate var _waterfall                  : Waterfall? { return params.radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _center                     : Int {return _panadapter!.center }
    fileprivate var _bandwidth                  : Int { return _panadapter!.bandwidth }
    fileprivate var _start                      : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                        : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit                  : CGFloat { return CGFloat(_end - _start) / self.frame.width }

    //  Vertices    v1  (-1, 1)     |     ( 1, 1)  v3       Texture     v1  ( 0, 1) |           ( 1, 1)  v3
    //  (-1 to +1)                  |                       (0 to 1)                |
    //                          ----|----                                           |
    //                              |                                               |
    //              v0  (-1,-1)     |     ( 1,-1)  v2                   v0  ( 0, 0) |---------  ( 1, 0)  v2
    //
    fileprivate var _waterfallVertices          : [Vertex] = [
        Vertex(coord: float2(-1.0, -1.0), texCoord: float2( 0.0, 0.0)), // v0 - bottom left
        Vertex(coord: float2(-1.0,  1.0), texCoord: float2( 0.0, 1.0)), // v1 - top    left
        Vertex(coord: float2( 1.0, -1.0), texCoord: float2( 1.0, 0.0)), // v2 - bottom right
        Vertex(coord: float2( 1.0,  1.0), texCoord: float2( 1.0, 1.0))  // v3 - top    right
    ]
    fileprivate var _waterfallPipelineState     :MTLRenderPipelineState!
    
    fileprivate var _uniforms                   :Uniforms!
    fileprivate var _uniformsBuffer             :MTLBuffer?
    fileprivate var _texture                    :MTLTexture!
    fileprivate var _samplerState               :MTLSamplerState!
    fileprivate var _commandQueue               :MTLCommandQueue!
    fileprivate var _clearColor                 :MTLClearColor?
    
    fileprivate var _numberOfBins               : Int = 0
    fileprivate var _binWidthHz                 : CGFloat = 0.0
    fileprivate var _firstPass                  = true
    
    fileprivate var _texDuration                = 0                     // seconds
    fileprivate var _waterfallDuration          = 0                     // seconds
    fileprivate var _lineDuration               = 0                     // milliseconds
    fileprivate var _textureIndex               = 0                     // current "top" line
    
    fileprivate var _yIncrement                 : Float = 0.0           // tex vertical increment
    fileprivate var _startingBinNumber          = 0                     // first bin to display (left)
    fileprivate var _endingBinNumber            = 0                     // last bin to display (right)
    
    fileprivate var _currentLine = [UInt32](repeating: WaterfallLayer.kBlackRGBA, count: WaterfallLayer.kTextureWidth)
    
    // constants
    fileprivate let _log                        = (NSApp.delegate as! AppDelegate)
    fileprivate let kWaterfallVertex            = "waterfall_vertex"
    fileprivate let kWaterfallFragment          = "waterfall_fragment"
    
    static let kTextureWidth                    = 4096                  // must be >= max number of Bins
    static let kTextureHeight                   = 2048                  // must be >= max number of lines
    static let kBlackRGBA                       : UInt32 = 0xFF000000   // Black color in RGBA format
    static let kRedRGBA                         : UInt32 = 0xFF0000FF   // Red color in RGBA format
    static let kGreenRGBA                       : UInt32 = 0xFF00FF00   // Green color in RGBA format
    static let kBlueRGBA                        : UInt32 = 0xFFFF0000   // Blue color in RGBA format
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw in a Metal layer
    ///
    public func render() {
        
        // obtain a drawable
        guard let drawable = nextDrawable() else { return }
        
        // create a command buffer
        let cmdBuffer = _commandQueue.makeCommandBuffer()
        
        // setup a render pass descriptor
        let renderPassDesc = MTLRenderPassDescriptor()
        renderPassDesc.colorAttachments[0].texture = drawable.texture
        renderPassDesc.colorAttachments[0].loadAction = .clear
        
        // Create a render encoder
        let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)
        
        encoder.pushDebugGroup("Waterfall")
        
        // use the Waterfall pipeline state
        encoder.setRenderPipelineState(_waterfallPipelineState)
        
        // bind the bytes containing the Waterfall vertices (position 0)
        let size = MemoryLayout.stride(ofValue: _waterfallVertices[0])
        encoder.setVertexBytes(&_waterfallVertices, length: size * _waterfallVertices.count, at: 0)
        
        // bind the Waterfall texture for the Fragment shader
        encoder.setFragmentTexture(_texture, at: 0)
        
        // bind the sampler state for the Fragment shader
        encoder.setFragmentSamplerState(_samplerState, at: 0)
        
        // bind the buffer containing the Uniforms (position 1)
        encoder.setVertexBuffer(_uniformsBuffer, offset: 0, at: 1)
        
        // Draw as a Line
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: _waterfallVertices.count)
        
        encoder.popDebugGroup()
        
        // finish using this encoder
        encoder.endEncoding()
        
        // add a final command to present the drawable to the screen
        cmdBuffer.present(drawable)
        
        // finalize rendering & push the command buffer to the GPU
        cmdBuffer.commit()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
//    func updateTexCoords(binCount: Int) {
//
//        // is it the first pass?
//        if _firstPass {
//
//            // YES, reset the flag
//            _firstPass = false
//
//            // calculate texture duration (seconds)
//            _texDuration = (_lineDuration * WaterfallLayer.kTextureHeight) / 1_000
//
//            // calculate waterfall duration (seconds)
//            _waterfallDuration = Int( (CGFloat(_lineDuration) * frame.height ) / 1_000 )
//
//            // set lower y coordinates of the texture to initial values
//            //      (upper values are set in property declarations)
//            let bottomSide = 1.0 - Float(frame.height - 1) / Float(WaterfallLayer.kTextureHeight - 1)
//            _waterfallVertices[2].texCoord.y = bottomSide
//            _waterfallVertices[0].texCoord.y = bottomSide
//
//            // calculate how much to move the texture vertically for each line drawn
//            _yIncrement = Float( 1.0 / (Float(WaterfallLayer.kTextureHeight) - 1.0))
//
//            // set the right & left texture x coordinates
//            let leftSide = Float(_startingBinNumber) / Float(WaterfallLayer.kTextureWidth - 1)
//            let rightSide = Float(_endingBinNumber) / Float(WaterfallLayer.kTextureWidth - 1)
//            _waterfallVertices[3].texCoord.x = rightSide
//            _waterfallVertices[2].texCoord.x = rightSide
//            _waterfallVertices[1].texCoord.x = leftSide
//            _waterfallVertices[0].texCoord.x = leftSide
//
//        } else {
//
//            // NO, update the upper & lower y coordinates of the texture
//            _waterfallVertices[3].texCoord.y += _yIncrement
//            _waterfallVertices[2].texCoord.y += _yIncrement
//            _waterfallVertices[1].texCoord.y += _yIncrement
//            _waterfallVertices[0].texCoord.y += _yIncrement
//        }
//    }
    /// Load a Texture from an asset
    ///
    func loadTexture() {
        
        // load the texture from a resource
        let loader = MTKTextureLoader(device: device!)
        let texURL = Bundle.main.urlForImageResource("BlackTexture.png")!
        _texture = try! loader.newTexture(withContentsOf: texURL)
    }
    /// Populate Uniform values
    ///
    func populateUniforms(numberOfBins: Int, numberOfDisplayBins: Int, halfBinWidthCS: Float) {
        
        // set the uniforms
        _uniforms = Uniforms(numberOfBins: Float(numberOfBins),
                             numberOfDisplayBins: Float(numberOfDisplayBins),
                             halfBinWidth: halfBinWidthCS)
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
    /// Setup State
    ///
    func setupState() {
        
        // get the Library (contains all compiled .metal files in this project)
        let library = device!.newDefaultLibrary()!
        
        // create a Render Pipeline Descriptor for the Spectrum
        let waterfallPipelineDesc = MTLRenderPipelineDescriptor()
        waterfallPipelineDesc.vertexFunction = library.makeFunction(name: kWaterfallVertex)
        waterfallPipelineDesc.fragmentFunction = library.makeFunction(name: kWaterfallFragment)
        waterfallPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // create and save the Render Pipeline State object
        _waterfallPipelineState = try! device!.makeRenderPipelineState(descriptor: waterfallPipelineDesc)
        
        // create and save a Command Queue object
        _commandQueue = device!.makeCommandQueue()
        
        // create a Sampler Descriptor & set its parameters
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        
        // create the Sampler State
        _samplerState = device!.makeSamplerState(descriptor: samplerDescriptor)
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
    func redraw() {
        
        DispatchQueue.main.async {
            self.render()
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - WaterfallStreamHandler protocol methods
    //
    
    //  dataFrame Struct Layout: (see xLib6000 WaterfallFrame)
    //
    //  public var firstBinFreq: CGFloat                        // Frequency of first Bin in Hz
    //  public var binBandwidth: CGFloat                        // Bandwidth of a single bin in Hz
    //  public var lineDuration: Int                            // Duration of this line in ms (1 to 100)
    //  public var lineHeight: Int                              // Height of frame in pixels
    //  public var autoBlackLevel: UInt32                       // Auto black level
    //  public var numberOfBins: Int                            // Number of bins
    //  public var bins: [UInt16]                               // Array of bin values
    //
    
    /// Process the UDP Stream Data for the Waterfall (called on the waterfallQ)
    ///
    /// - Parameter dataFrame:  a waterfall dataframe struct
    ///
    public func waterfallStreamHandler(_ dataFrame: WaterfallFrame ) {
        
        autoBlackLevel = dataFrame.autoBlackLevel
        
        // YES, reset the flag
        _firstPass = false
        
        // calc the levels
        gradient.calcLevels(autoBlackEnabled: _waterfall!.autoBlackEnabled, autoBlackLevel: autoBlackLevel, blackLevel: _waterfall!.blackLevel, colorGain: _waterfall!.colorGain)
        
        // save the line duration
        _lineDuration = dataFrame.lineDuration
        
        // calculate texture duration (seconds)
        _texDuration = (_lineDuration * WaterfallLayer.kTextureHeight) / 1_000
        
        // calculate waterfall duration (seconds)
        _waterfallDuration = Int( (CGFloat(_lineDuration) * frame.height ) / 1_000 )
        
        // calculate the starting & ending bin numbers
        _startingBinNumber = Int( (CGFloat(_start) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
        _endingBinNumber = Int( (CGFloat(_end) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
        
        // set the right & left texture x coordinates
        let leftSide = Float(_startingBinNumber) / Float(WaterfallLayer.kTextureWidth)
        let rightSide = Float(_endingBinNumber) / Float(WaterfallLayer.kTextureWidth)
        _waterfallVertices[3].texCoord.x = rightSide
        _waterfallVertices[2].texCoord.x = rightSide
        _waterfallVertices[1].texCoord.x = leftSide
        _waterfallVertices[0].texCoord.x = leftSide
        
        let yOffset = Float(_textureIndex) / Float(WaterfallLayer.kTextureHeight - 1)
        let stepValue = 1.0 / Float(WaterfallLayer.kTextureHeight - 1)
        let heightPercent = Float(_waterfallDuration) / Float(_texDuration)

        // set lower y coordinates of the texture to initial values
        _waterfallVertices[3].texCoord.y = yOffset + 1 - stepValue
        _waterfallVertices[2].texCoord.y = yOffset + 1 - heightPercent
        _waterfallVertices[1].texCoord.y = yOffset + 1 - stepValue
        _waterfallVertices[0].texCoord.y = yOffset + 1 - heightPercent

        // lookup the intensities in the Gradient
        let binsPtr = UnsafePointer<UInt16>(dataFrame.bins)
        for i in 0..<dataFrame.numberOfBins {
            _currentLine[i] = gradient.value(binsPtr.advanced(by: i).pointee)
        }
        // copy the current line into the texture
        let region = MTLRegionMake2D(0, _textureIndex, dataFrame.numberOfBins, 1)
        let uint8Ptr = UnsafeRawPointer(_currentLine).bindMemory(to: UInt8.self, capacity: dataFrame.numberOfBins * 4)
        _texture.replace(region: region, mipmapLevel: 0, withBytes: uint8Ptr, bytesPerRow: dataFrame.numberOfBins * 4)

        // increment the texture position
        _textureIndex = (_textureIndex + 1) % WaterfallLayer.kTextureHeight

        // interact with the UI
        DispatchQueue.main.async { [unowned self] in            
            autoreleasepool {
                
                // draw
                self.render()
            }
        }
    }
}
