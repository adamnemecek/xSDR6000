//
//  ViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000
import MetalKit

class PanadapterViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _params: Params { return representedObject as! Params }
    
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
//
//    fileprivate var _start: Int { return _panadapter!.center - (_panadapter!.bandwidth/2) }
//    fileprivate var _end: Int  { return _panadapter!.center + (_panadapter!.bandwidth/2) }
//    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / view.frame.width }
//
//    fileprivate var _minY: CAConstraint!
//    fileprivate var _minX: CAConstraint!
//    fileprivate var _maxY: CAConstraint!
//    fileprivate var _maxX: CAConstraint!
//
//    fileprivate var _rootLayer: CALayer!                                // layers
//    
//    fileprivate let _renderQ = DispatchQueue(label: "renderQ")
//    
//    fileprivate var _dataFrame: PanadapterFrame?
//    
//
//    var device: MTLDevice!                      // the GPU
//    var metalLayer: CAMetalLayer!               // the Metal CALayer
//    let vertexData: [Float] = [                 // the vertices
////        -0.5, 0.5, 0.0,
////        -0.5, -0.5, 0.0,
////        0.0, 0.5, 0.0,
////        0.0, -0.5, 0.0,
////        0.5, 0.5, 0.0,
////        0.5, -0.5, 0.0
//        -0.4, -0.4, 0.0,
//        0.0, 0.4, 0.0,
//        0.4, -0.4, 0.0
////        -1.0, -1.0, 0.0
////        1.0, 0.0, 0.0,
////        -1.0, 1.0, 0,0,
////        -1.0, -1.0, 0.0
//    ]
//    
//    var vertexBuffer: MTLBuffer!                // buffer accessible to the GPU
//    var pipelineState: MTLRenderPipelineState!
//    var viewport: MTLViewport!
//    var commandQueue: MTLCommandQueue!          // queue for drawing commands
//
//    fileprivate let kRootLayer = "root"                                 // layer names
    
    
    private var _view: MTKView!
    private var _renderer: PanadapterRenderer!

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()

        _view = self.view as! MTKView
        _view.device = MTLCreateSystemDefaultDevice()
        
        guard _view.device != nil else {
            fatalError("Metal is not supported on this device")
        }
        
        _renderer = PanadapterRenderer(mtkView: _view, panadapter: _panadapter!)
        
        guard _renderer != nil else {
            fatalError("Renderer failed initialization")
        }
        
        _view.delegate = _renderer
        _view.preferredFramesPerSecond = 30
        
        
//        // create layer constraints
//        _minY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY)
//        _maxY = CAConstraint(attribute: .maxY, relativeTo: "superlayer", attribute: .maxY)
//        _minX = CAConstraint(attribute: .minX, relativeTo: "superlayer", attribute: .minX)
//        _maxX = CAConstraint(attribute: .maxX, relativeTo: "superlayer", attribute: .maxX)
//        
//        // create layers
//        _rootLayer = view.layer!                                      // ***** Root layer *****
//        _rootLayer.name = kRootLayer
//        _rootLayer.layoutManager = CAConstraintLayoutManager()
//        _rootLayer.frame = view.frame
//        view.layerUsesCoreImageFilters = true
//        
//        // select a compositing filter
//        // possible choices - CIExclusionBlendMode, CIDifferenceBlendMode, CIMaximumCompositing
//        guard let compositingFilter = CIFilter(name: "CIDifferenceBlendMode") else {
//            fatalError("Unable to create compositing filter")
//        }
//        
//        // create a Metal device
//        device = MTLCreateSystemDefaultDevice()
//        guard device != nil else {
//            
//            fatalError("Current environment does not support Metal")
//        }
//        
//        // create & configure the Layer
//        metalLayer = CAMetalLayer()
//        metalLayer.device = device              // uses the GPU
//        metalLayer.pixelFormat = .bgra8Unorm    // layout of pixels
//        metalLayer.framebufferOnly = true
//        metalLayer.frame = _rootLayer.frame     // size matches the root layer's size
//        
//        metalLayer.addConstraint(_minX)
//        metalLayer.addConstraint(_maxX)
//        metalLayer.addConstraint(_minY)
//        metalLayer.addConstraint(_maxY)
//        
//        
//        view.layer!.addSublayer(metalLayer)     // add it as a sublayer
//        view.layer!.needsDisplayOnBoundsChange = true
//        
//        
//        viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.frame.width), height: Double(view.frame.height), znear: 0, zfar: 1.0 )
//        
//        // create a Vertex Buffer of the required size
//        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])         // size in bytes
//        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize)
//        
//        // use the Default Library to make shader variables
//        let defaultLibrary = device.newDefaultLibrary()!
//        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")           // fragment shader
//        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")               // vertex shader
//        
//        // describe the rendering pipeline
//        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
//        pipelineStateDescriptor.vertexFunction = vertexProgram                              // assign the vertex shader to this pipeline
//        pipelineStateDescriptor.fragmentFunction = fragmentProgram                          // assign the fragment shader to this pipeline
//        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm               // configure the pixel format of the colorAttachment
//        
//        // create the pipeline state
//        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
//        
//        // create a Command queue
//        commandQueue = device.makeCommandQueue()
//        
//        _panadapter!.delegate = self
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Render the view
    ///
//    func render() {
//        
////        Swift.print("x=\(_rootLayer.frame.origin.x), y=\(_rootLayer.frame.origin.y), w=\(_rootLayer.frame.width), h=\(_rootLayer.frame.height)")
//        
////        viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(_rootLayer.frame.width), height: Double(_rootLayer.frame.height), znear: 0, zfar: 1.0 )
//
//        // get the background color
//        let background = Defaults[.spectrumBackground]
//        
//        // obtain a drawable for the layer
//        guard let drawable = metalLayer?.nextDrawable() else { return }
//        
//        // describe the Render Pass
//        let renderPassDescriptor = MTLRenderPassDescriptor()
//        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
//        renderPassDescriptor.colorAttachments[0].loadAction = .clear
//        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: Double(background.redComponent),
//                                                                            green: Double(background.greenComponent),
//                                                                            blue: Double(background.blueComponent),
//                                                                            alpha: Double(background.alphaComponent))
//        
//        // get a Command Buffer from the Command Queue
//        let commandBuffer = commandQueue.makeCommandBuffer()
//        
//        // get a Render Encoder from the Command Buffer using the Render Pass Descriptor
//        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
//        
//        // configure the Render Encoder
//        renderEncoder.setRenderPipelineState(pipelineState)                                                 // state
//        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)                                       // vertices
//        renderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(_rootLayer.frame.width), height: Double(_rootLayer.frame.height), znear: 0, zfar: 1.0 ))
//        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 3, instanceCount: 1)     // draw
//        renderEncoder.endEncoding()                                                                         // close out
//        
//        // draw
//        commandBuffer.present(drawable)         
//        commandBuffer.commit()                  // commit to execute asap
//    }

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
    
//    //
//    // Process the UDP Stream Data for the Panadapter
//    //
//    func panadapterStreamHandler(_ dataFrame: PanadapterFrame) {
//
//        DispatchQueue.main.async {
//            
//            autoreleasepool {
//                
//                self._dataFrame = dataFrame
//                
//                self.render()
//            }
//        }
//    }
}

