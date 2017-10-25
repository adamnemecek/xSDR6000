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
    var frequencyLegendHeight               : CGFloat = 20          // height of legend

    var rootLayer                           : CALayer!              // layers
    var panadapterLayer                     : PanadapterLayer!
    var frequencyLayer                      : FrequencyLayer!
    var dbLayer                             : DbLayer!
    var tnfLayer                            : TnfLayer!
    var sliceLayer                          : SliceLayer!

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panLeft                : NSPanGestureRecognizer!   // gestures
    fileprivate var _clickLeft              : NSClickGestureRecognizer!
    fileprivate var _clickRight             : NSClickGestureRecognizer!
    
    fileprivate var _minY                   : CAConstraint!         // layer constraints
    fileprivate var _minX                   : CAConstraint!
    fileprivate var _maxY                   : CAConstraint!
    fileprivate var _maxX                   : CAConstraint!
    fileprivate var _aboveFrequencyLegendY  : CAConstraint!

    // constants
    fileprivate let kRootLayer              = "root"                // layer names
    fileprivate let kPanadapterLayer        = "panadapter"
    fileprivate let kFrequencyLayer         = "frequency"
    fileprivate let kDbLayer                = "db"
    fileprivate let kTnfLayer               = "tnf"
    fileprivate let kSliceLayer             = "slice"
    fileprivate let kLeftButton             = 0x01                  // button masks
    fileprivate let kRightButton            = 0x02

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        createLayers()
    }

    public override func viewDidEndLiveResize() {
        
        // alert the controller to a resize
        delegate.didResize()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        // draw in the requested layer
        switch layer {
        case frequencyLayer:
            frequencyLayer.drawLayer(in: ctx)
        
        case dbLayer:
            dbLayer.drawLayer(in: ctx)
        
        case sliceLayer:
            sliceLayer.drawLayer(in: ctx)
        
        case tnfLayer:
            tnfLayer.drawLayer(in: ctx)
        
        default:
            break
        }
    }
    
    
    
    /// Create a Slice Flag
    ///
    func createFlagView() -> FlagViewController {
        
        // get the Storyboard containing a Flag View Controller
        let sb = NSStoryboard(name: "Panafall", bundle: nil)
        
        // create a Flag View Controller
        let flagVc = sb.instantiateController(withIdentifier: "Flag") as! FlagViewController
        
        delegate.addChildViewController(flagVc)
        
        return flagVc
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
        
        // create a left-click gesture
        _clickLeft = NSClickGestureRecognizer(target: delegate, action: #selector(PanadapterViewController.clickLeft(_:)))
        _clickLeft.buttonMask = kLeftButton
        
        addGestureRecognizer(_clickLeft)
        
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
        dbLayer = DbLayer()
        dbLayer.name = kDbLayer
        dbLayer.addConstraint(_minX)
        dbLayer.addConstraint(_maxX)
        dbLayer.addConstraint(_aboveFrequencyLegendY)
        dbLayer.addConstraint(_maxY)
        dbLayer.delegate = self
        dbLayer.compositingFilter = compositingFilter
        
        // ***** Frequency Legend layer *****
        frequencyLayer = FrequencyLayer()
        frequencyLayer.name = kFrequencyLayer
        frequencyLayer.addConstraint(_minX)
        frequencyLayer.addConstraint(_maxX)
        frequencyLayer.addConstraint(_minY)
        frequencyLayer.addConstraint(_maxY)
        frequencyLayer.delegate = self
        frequencyLayer.compositingFilter = compositingFilter
        frequencyLayer.legendHeight = frequencyLegendHeight
        
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
        rootLayer.addSublayer(frequencyLayer)
        rootLayer.addSublayer(dbLayer)
        rootLayer.addSublayer(tnfLayer)
        rootLayer.addSublayer(sliceLayer)
    }
}
