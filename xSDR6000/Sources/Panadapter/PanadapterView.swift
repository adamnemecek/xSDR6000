//
//  PanadapterView.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/4/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa

final public class PanadapterView: NSView, CALayerDelegate {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var delegate                            : PanadapterViewController!
    {
        didSet { createGestures() }
    }
    var frequencyLegendHeight               : CGFloat = 20          // frequency height

    var rootLayer                           : CALayer!              // layers
    var panadapterLayer                     : PanadapterLayer!
    var frequencyLegendLayer                : FrequencyLegendLayer!
    var dbLegendLayer                       : DbLegendLayer!
    var tnfLayer                            : TnfLayer!
    var sliceLayer                          : SliceLayer!

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panLeft                : NSPanGestureRecognizer!
    fileprivate var _clickRight             : NSClickGestureRecognizer!
    
    fileprivate var _minY                   : CAConstraint!
    fileprivate var _minX                   : CAConstraint!
    fileprivate var _maxY                   : CAConstraint!
    fileprivate var _maxX                   : CAConstraint!
    fileprivate var _aboveFrequencyLegendY  : CAConstraint!

    // constants
    fileprivate let kLeftButton             = 0x01                  // button masks
    fileprivate let kRightButton            = 0x02
    fileprivate let kRootLayer              = "root"                // layer names
    fileprivate let kPanadapterLayer        = "panadapter"
    fileprivate let kFrequencyLegendLayer   = "frequency"
    fileprivate let kDbLegendLayer          = "legend"
    fileprivate let kTnfLayer               = "tnf"
    fileprivate let kSliceLayer             = "slice"

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
                
            case kFrequencyLegendLayer:
                frequencyLegendLayer.draw(layer, in: ctx)
                
            case kDbLegendLayer:
                dbLegendLayer.draw(layer, in: ctx)
                
            case kSliceLayer:
                sliceLayer.draw(layer, in: ctx)
                
            case kTnfLayer:
                tnfLayer.draw(layer, in: ctx)
                
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
        
        // create a left button pan gesture
        _panLeft = NSPanGestureRecognizer(target: delegate, action: #selector(PanadapterViewController.panLeft(_:)))
        _panLeft.buttonMask = kLeftButton
        
        addGestureRecognizer(_panLeft)
        
        // create a right-click gesture
        _clickRight = NSClickGestureRecognizer(target: delegate, action: #selector(PanadapterViewController.clickRight(_:)))
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
        _aboveFrequencyLegendY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY, offset: frequencyLegendHeight)
        
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
        // ***** Panadapter Spectrum layer *****
        panadapterLayer = PanadapterLayer()
        
        // get the Metal device
        panadapterLayer.device = MTLCreateSystemDefaultDevice()
        guard panadapterLayer.device != nil else {
            fatalError("Metal is not supported on this Mac")
        }
        panadapterLayer.name = kPanadapterLayer
        panadapterLayer.frame = CGRect(x: 0, y: frequencyLegendHeight, width: rootLayer.frame.width, height: rootLayer.frame.height - frequencyLegendHeight)
        panadapterLayer.addConstraint(_minX)
        panadapterLayer.addConstraint(_maxX)
        panadapterLayer.addConstraint(_minY)
        panadapterLayer.addConstraint(_maxY)
        panadapterLayer.pixelFormat = .bgra8Unorm
        panadapterLayer.framebufferOnly = true
        panadapterLayer.delegate = panadapterLayer

        // ***** Db Legend layer *****
        dbLegendLayer = DbLegendLayer()
        dbLegendLayer.name = kDbLegendLayer
        dbLegendLayer.addConstraint(_minX)
        dbLegendLayer.addConstraint(_maxX)
        dbLegendLayer.addConstraint(_aboveFrequencyLegendY)
        dbLegendLayer.addConstraint(_maxY)
        dbLegendLayer.delegate = self
        dbLegendLayer.compositingFilter = compositingFilter
        
        // ***** Frequency Legend layer *****
        frequencyLegendLayer = FrequencyLegendLayer()
        frequencyLegendLayer.name = kFrequencyLegendLayer
        frequencyLegendLayer.addConstraint(_minX)
        frequencyLegendLayer.addConstraint(_maxX)
        frequencyLegendLayer.addConstraint(_minY)
        frequencyLegendLayer.addConstraint(_maxY)
        frequencyLegendLayer.delegate = self
        frequencyLegendLayer.compositingFilter = compositingFilter
        frequencyLegendLayer.height = frequencyLegendHeight
        
        // ***** Tnf layer *****
        tnfLayer = TnfLayer()
        tnfLayer.name = kTnfLayer
        tnfLayer.addConstraint(_minX)
        tnfLayer.addConstraint(_maxX)
        tnfLayer.addConstraint(_aboveFrequencyLegendY)
        tnfLayer.addConstraint(_maxY)
        tnfLayer.delegate = self
        tnfLayer.compositingFilter = compositingFilter
        
        // ***** Slice layer *****
        sliceLayer = SliceLayer()
        sliceLayer.name = kSliceLayer
        sliceLayer.addConstraint(_minX)
        sliceLayer.addConstraint(_maxX)
        sliceLayer.addConstraint(_aboveFrequencyLegendY)
        sliceLayer.addConstraint(_maxY)
        sliceLayer.delegate = self
        sliceLayer.compositingFilter = compositingFilter
        
        // layer hierarchy
        rootLayer.addSublayer(panadapterLayer)
        rootLayer.addSublayer(frequencyLegendLayer)
        rootLayer.addSublayer(dbLegendLayer)
        rootLayer.addSublayer(tnfLayer)
        rootLayer.addSublayer(sliceLayer)
    }
}
