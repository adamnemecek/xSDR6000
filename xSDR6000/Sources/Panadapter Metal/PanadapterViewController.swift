//
//  ViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import Metal

class PanadapterViewController: NSViewController, PanadapterStreamHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _params: Params { return representedObject as! Params }
    
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
    
    fileprivate var _start: Int { return _panadapter!.center - (_panadapter!.bandwidth/2) }
    fileprivate var _end: Int  { return _panadapter!.center + (_panadapter!.bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / view.frame.width }
    
    var device: MTLDevice!                      // the GPU
    var metalLayer: CAMetalLayer!               // the Metal CALayer
    let vertexData: [Float] = [                 // the vertices
//        -0.5, 0.5, 0.0,
//        -0.5, -0.5, 0.0,
//        0.0, 0.5, 0.0,
//        0.0, -0.5, 0.0,
//        0.5, 0.5, 0.0,
//        0.5, -0.5, 0.0
        -0.4, -0.4, 0.0,
        0.4, -0.4, 0.0,
        0.0, 0.4, 0.0
//        -1.0, -1.0, 0.0
//        1.0, 0.0, 0.0,
//        -1.0, 1.0, 0,0,
//        -1.0, -1.0, 0.0
    ]
    
    var vertexBuffer: MTLBuffer!                // buffer accessible to the GPU
    var pipelineState: MTLRenderPipelineState!
    var viewport: MTLViewport!
    var commandQueue: MTLCommandQueue!          // queue for drawing commands
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()

        // create a Metal device
        device = MTLCreateSystemDefaultDevice()
        guard device != nil else {
            
            fatalError("Current environment does not support Metal")
        }
        
        // create & configure the Layer
        metalLayer = CAMetalLayer()
        metalLayer.device = device              // uses the GPU
        metalLayer.pixelFormat = .bgra8Unorm    // layout of pixels
        metalLayer.framebufferOnly = true
        metalLayer.frame = (view.layer?.frame)! // size matches the view's size
        view.layer?.addSublayer(metalLayer)     // add it as a sublayer
        
        viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.frame.width), height: Double(view.frame.height), znear: 0, zfar: 1.0 )
        
        // create a Vertex Buffer of the required size
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])         // size in bytes
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize)
        
        // use the Default Library to make shader variables
        let defaultLibrary = device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")           // fragment shader
        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")               // vertex shader
        
        // describe the rendering pipeline
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram                              // assign the vertex shader to this pipeline
        pipelineStateDescriptor.fragmentFunction = fragmentProgram                          // assign the fragment shader to this pipeline
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm               // configure the pixel format of the colorAttachment
        
        // create the pipeline state
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        // create a Command queue
        commandQueue = device.makeCommandQueue()
        
        _panadapter!.delegate = self
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Render the view
    ///
    func render() {
        
        // obtain a drawable for the layer
        guard let drawable = metalLayer?.nextDrawable() else { return }
        
        // describe the Render Pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 104.0/255.0, blue: 5.0/255.0, alpha: 1.0)
        
        // get a Command Buffer from the Command Queue
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // get a Render Encoder from the Command Buffer using the Render Pass Descriptor
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        // configure the Render Encoder
        renderEncoder.setRenderPipelineState(pipelineState)                                                 // state
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)                                       // vertices
        renderEncoder.setViewport(viewport)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)     // draw
        renderEncoder.endEncoding()                                                                         // close out
        
        // draw
        commandBuffer.present(drawable)         
        commandBuffer.commit()                  // commit to execute asap
    }

    /// Render loop
    ///
    func renderLoop() {
        autoreleasepool {
            self.render()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
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
    func panadapterStreamHandler(_ dataFrame: PanadapterFrame) {
        
        renderLoop()
    }
}

