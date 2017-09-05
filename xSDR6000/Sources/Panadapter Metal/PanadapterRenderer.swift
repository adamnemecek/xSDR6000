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
import xLib6000
import SwiftyUserDefaults

public final class PanadapterRenderer : NSObject, MTKViewDelegate, PanadapterStreamHandler {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
        
    fileprivate var _mtkView: MTKView!
    fileprivate var _device: MTLDevice!
    fileprivate var _commandQueue: MTLCommandQueue!
    
    fileprivate var _dataFrame: PanadapterFrame?

    fileprivate let _vertexData: [Float] = [                 // the vertices
        -1.0, -1.0, 0.0,
        0.0, 1.0, 0.0,
        1.0, -1.0, 0.0
    ]
    fileprivate var _vertexBuffer: MTLBuffer!                // buffer accessible to the GPU
    fileprivate var _pipelineState: MTLRenderPipelineState!

    fileprivate var _clearColor: MTLClearColor!
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(mtkView: MTKView, panadapter: Panadapter) {
        super.init()
        
        _mtkView = mtkView
        _mtkView.enableSetNeedsDisplay = true
        
        _device = mtkView.device
        _commandQueue = _device.makeCommandQueue()
        
        // create a Vertex Buffer of the required size
        let dataSize = _vertexData.count * MemoryLayout.size(ofValue: _vertexData[0])       // size in bytes
        _vertexBuffer = _device.makeBuffer(bytes: _vertexData, length: dataSize)

        // use the Default Library to make shader variables
        let defaultLibrary = _device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")           // fragment shader
        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")               // vertex shader
        
        // describe the rendering pipeline
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram                              // assign the vertex shader to this pipeline
        pipelineStateDescriptor.fragmentFunction = fragmentProgram                          // assign the fragment shader to this pipeline
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm               // configure the pixel format of the colorAttachment
        
        // create the pipeline state
        _pipelineState = try! _device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        // get the background color
         let background = Defaults[.spectrumBackground]
        _mtkView.clearColor = MTLClearColor(red: Double(background.redComponent),
                                            green: Double(background.greenComponent),
                                            blue: Double(background.blueComponent),
                                            alpha: Double(background.alphaComponent))

        panadapter.delegate = self
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw in a Metal Kit view
    ///
    /// - Parameter view: the MTKView
    ///
    public func draw(in view: MTKView) {
        
        // Create a new command buffer for each renderpass to the current drawable
        let commandBuffer = _commandQueue.makeCommandBuffer()
        commandBuffer.label = "MyCommand"
        
        // Obtain a renderPassDescriptor generated from the view's drawable textures
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll
        //   skip any rendering this frame because we have no drawable to draw to
        if renderPassDescriptor != nil
        {
            
            // use a render command encoder to tell Metal to draw our objects,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
            
            renderEncoder.label = "MyRenderEncoder"
            
            renderEncoder.setRenderPipelineState(_pipelineState)                                                 // state
            renderEncoder.setVertexBuffer(_vertexBuffer, offset: 0, at: 0)                                       // vertices
            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 3, instanceCount: 1)     // draw
            
            // indicate we're finished using this encoder
            renderEncoder.endEncoding()
            
            // Add a final command to present the drawable to the screen
            commandBuffer.present(view.currentDrawable!)
        }
        
        // Finalize rendering here & push the command buffer to the GPU
        commandBuffer.commit()
    }
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - view:       an MTKView
    ///   - size:       the new size
    ///
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//        Swift.print("Resized -> \(_mtkView.frame.origin.x), \(_mtkView.frame.origin.y), \(_mtkView.frame.width), \(_mtkView.frame.height)")
        
//        _viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(_mtkView.frame.width), height: Double(_mtkView.frame.height), znear: 0, zfar: 1.0 )
    }
    //
    // Process the UDP Stream Data for the Panadapter
    //
    public func panadapterStreamHandler(_ dataFrame: PanadapterFrame) {
        
        DispatchQueue.main.async {
            
            self._dataFrame = dataFrame
            autoreleasepool {
                
                self._mtkView.needsDisplay = true
            }
        }
    }
}
