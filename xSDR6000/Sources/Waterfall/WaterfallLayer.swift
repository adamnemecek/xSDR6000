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
    var heightPercent                           : Float = 0.0
    var updateNeeded                            = true
    
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
    
    fileprivate var _texture                    :MTLTexture!
    fileprivate var _samplerState               :MTLSamplerState!
    fileprivate var _commandQueue               :MTLCommandQueue!
    fileprivate var _clearColor                 :MTLClearColor?
    
    fileprivate var _textureIndex               = 0                     // current "top" line
    
    fileprivate var _yIncrement                 : Float = 0.0           // tex vertical increment
    fileprivate var _stepValue                  =                       // texture clip space between lines
        1.0 / Float(WaterfallLayer.kTextureHeight - 1)

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

    static let kBlackBGRA                       : UInt32 = 0xFF000000   // Black color in RGBA format
    static let kRedBGRA                         : UInt32 = 0xFFFF0000   // Red color in BGRA format
    static let kGreenBGRA                       : UInt32 = 0xFF00FF00   // Green color in BGRA format
    static let kBlueBGRA                        : UInt32 = 0xFF0000FF   // Blue color in BGRA format

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw in a Metal layer
    ///
    public func render() {
        
        // obtain a drawable
        guard let drawable = nextDrawable() else { return }
        
        // create a command buffer
        let cmdBuffer = _commandQueue.makeCommandBuffer()
        
        // create a render pass descriptor
        let renderPassDesc = MTLRenderPassDescriptor()
        renderPassDesc.colorAttachments[0].texture = drawable.texture
        renderPassDesc.colorAttachments[0].loadAction = .clear
        
        // Create a render encoder
        let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)
        
        encoder.pushDebugGroup("Waterfall")
        
        // set the pipeline state
        encoder.setRenderPipelineState(_waterfallPipelineState)
        
        // bind the bytes containing the vertices
        let size = MemoryLayout.stride(ofValue: _waterfallVertices[0])
        encoder.setVertexBytes(&_waterfallVertices, length: size * _waterfallVertices.count, at: 0)
        
        // bind the texture
        encoder.setFragmentTexture(_texture, at: 0)
        
        // bind the sampler state
        encoder.setFragmentSamplerState(_samplerState, at: 0)
        
        // Draw the box (2 triangles) containing the waterfall
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: _waterfallVertices.count)
        
        encoder.popDebugGroup()
        
        // finish using this encoder
        encoder.endEncoding()
        
        // present the drawable to the screen
        cmdBuffer.present(drawable)
        
        // finalize rendering & push the command buffer to the GPU
        cmdBuffer.commit()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Load a Texture from an asset
    ///
    func loadTexture() {
        
        // load the texture from a resource
        let loader = MTKTextureLoader(device: device!)
        let texURL = Bundle.main.urlForImageResource("BlackTexture.png")!
        _texture = try! loader.newTexture(withContentsOf: texURL)
    }
    /// Setup State
    ///
    func setupState() {
        
        // get the Library (contains all compiled .metal files in this project)
        let library = device!.newDefaultLibrary()!
        
        // create a Render Pipeline Descriptor
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
        
        // create and save the Sampler State
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
    /// Force a redraw
    ///
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
        
        if dataFrame.autoBlackLevel != autoBlackLevel {
            
            gradient.calcLevels(autoBlackEnabled: _waterfall!.autoBlackEnabled, autoBlackLevel: dataFrame.autoBlackLevel, blackLevel: _waterfall!.blackLevel, colorGain: _waterfall!.colorGain)
        }
        autoBlackLevel = dataFrame.autoBlackLevel
        
        // recalc values initially or when center/bandwidth changes
        if updateNeeded {
            
            updateNeeded = false
            
            // calculate the starting & ending bin numbers
            let startingBinNumber = Float( (CGFloat(_start) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
            let endingBinNumber = Float( (CGFloat(_end) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
        
            // set the right & left x coordinates of the texture
            let leftSide = startingBinNumber / Float(WaterfallLayer.kTextureWidth)
            let rightSide = endingBinNumber / Float(WaterfallLayer.kTextureWidth)
            _waterfallVertices[3].texCoord.x = rightSide
            _waterfallVertices[2].texCoord.x = rightSide
            _waterfallVertices[1].texCoord.x = leftSide
            _waterfallVertices[0].texCoord.x = leftSide
        }
        
        let yOffset = Float(_textureIndex) / Float(WaterfallLayer.kTextureHeight - 1)

        // set lower y coordinates of the texture
        _waterfallVertices[3].texCoord.y = yOffset + 1 - _stepValue
        _waterfallVertices[2].texCoord.y = yOffset + 1 - heightPercent
        _waterfallVertices[1].texCoord.y = yOffset + 1 - _stepValue
        _waterfallVertices[0].texCoord.y = yOffset + 1 - heightPercent

        // translate the intensities into colors
        let binsPtr = UnsafePointer<UInt16>(dataFrame.bins)
        for i in 0..<dataFrame.numberOfBins {
            _currentLine[i] = gradient.value( binsPtr.advanced(by: i).pointee )            
        }

        // copy the colors into the texture
        let region = MTLRegionMake2D(0, _textureIndex, dataFrame.numberOfBins, 1)
        let uint8Ptr = UnsafeRawPointer(_currentLine).bindMemory(to: UInt8.self, capacity: dataFrame.numberOfBins * 4)
        _texture.replace(region: region, mipmapLevel: 0, withBytes: uint8Ptr, bytesPerRow: dataFrame.numberOfBins * 4)

        // increment the index (the texture line that is currently the "top" line on the display)
        _textureIndex = (_textureIndex + 1) % WaterfallLayer.kTextureHeight

        // render
        self.render()
    }
}
