//
//  WaterfallView.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa

final public class WaterfallView: NSView, CALayerDelegate {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var delegate                            : WaterfallViewController!
    {
        didSet { createGestures() }
    }
    var timeLegendWidth                    : CGFloat = 40           // legend width
    
    var rootLayer                           : CALayer!              // layers
    var waterfallLayer                      : WaterfallLayer!
    var timeLegendLayer                     : TimeLegendLayer!
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panLeft                : NSPanGestureRecognizer!
    fileprivate var _clickRight             : NSClickGestureRecognizer!
    
    fileprivate var _minY                   : CAConstraint!
    fileprivate var _minX                   : CAConstraint!
    fileprivate var _maxY                   : CAConstraint!
    fileprivate var _maxX                   : CAConstraint!
    fileprivate var _timeLegendMinX         : CAConstraint!
    
    // constants
    fileprivate let kRightButton            = 0x02
    fileprivate let kRootLayer              = "root"                // layer names
    fileprivate let kWaterfallLayer         = "waterfall"
    fileprivate let kTimeLegendLayer        = "legend"
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        createLayers()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let name = layer.name {
            switch name {
                
            case kTimeLegendLayer:
                timeLegendLayer.draw(layer, in: ctx)
                
            default:
                break
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Create the Gesture Recognizers and set their target/actions
    ///
    fileprivate func createGestures() {
        
        // create a right-click gesture
        _clickRight = NSClickGestureRecognizer(target: delegate, action: #selector(WaterfallViewController.clickRight(_:)))
        _clickRight.buttonMask = kRightButton
        
        // setup a delegate to allow some right clicks to be ignored
        _clickRight.delegate = delegate
        
        addGestureRecognizer(_clickRight)
    }
    /// Create the Layers and setup relationships to each other
    ///
    fileprivate func createLayers() {
        
        // create layer constraints
        _minY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY)
        _maxY = CAConstraint(attribute: .maxY, relativeTo: "superlayer", attribute: .maxY)
        _minX = CAConstraint(attribute: .minX, relativeTo: "superlayer", attribute: .minX)
        _maxX = CAConstraint(attribute: .maxX, relativeTo: "superlayer", attribute: .maxX)
        _timeLegendMinX = CAConstraint(attribute: .minX, relativeTo: "superlayer", attribute: .maxX, offset: -timeLegendWidth)
        
        // create layers
        rootLayer = CALayer()                                      // ***** Root layer *****
        rootLayer.name = kRootLayer
        rootLayer.layoutManager = CAConstraintLayoutManager()
        rootLayer.frame = frame
        layerUsesCoreImageFilters = true
        
        // make this a layer-hosting view
        layer = rootLayer
        wantsLayer = true
        
        // select a compositing filter
        // possible choices - CIExclusionBlendMode, CIDifferenceBlendMode, CIMaximumCompositing
        guard let compositingFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            fatalError("Unable to create compositing filter")
        }
        // ***** Waterfall layer *****
        waterfallLayer = WaterfallLayer()
        
        // get the Metal device
        waterfallLayer.device = MTLCreateSystemDefaultDevice()
        guard waterfallLayer.device != nil else {
            fatalError("Metal is not supported on this Mac")
        }
        waterfallLayer.name = kWaterfallLayer
        waterfallLayer.frame = frame
        waterfallLayer.addConstraint(_minX)
        waterfallLayer.addConstraint(_maxX)
        waterfallLayer.addConstraint(_minY)
        waterfallLayer.addConstraint(_maxY)
        waterfallLayer.pixelFormat = .bgra8Unorm
        waterfallLayer.framebufferOnly = true
        waterfallLayer.delegate = waterfallLayer
        
        // ***** Time Legend layer *****
        timeLegendLayer = TimeLegendLayer()
        timeLegendLayer.name = kTimeLegendLayer
        timeLegendLayer.addConstraint(_timeLegendMinX)
        timeLegendLayer.addConstraint(_maxX)
        timeLegendLayer.addConstraint(_minY)
        timeLegendLayer.addConstraint(_maxY)
        timeLegendLayer.delegate = self
        timeLegendLayer.compositingFilter = compositingFilter
                
        // layer hierarchy
        rootLayer.addSublayer(waterfallLayer)
        rootLayer.addSublayer(timeLegendLayer)
    }
}

