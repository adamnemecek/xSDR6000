
//  WaterfallView.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/26/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//


import Cocoa
import xLib6000
import Quartz
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Waterfall View implementation
//
//          setup layers for the Waterfall legend and the Waterfall display
//          draw the Waterfall legend
//
// --------------------------------------------------------------------------------

final class WaterfallView: NSView, CALayerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    var params: Params!                                         // Radio & Panadapter references

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    fileprivate var _radio: Radio { return params.radio }       // values derived from Params
    fileprivate var _panadapter: Panadapter? { return params.panadapter }
    fileprivate var _waterfall: Waterfall? { return _radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _lineDuration: Int { return (_waterfall?.lineDuration) ?? 100 }
    
    fileprivate var _rootLayer: CALayer!                        // Layers
    fileprivate var _spectrumLayer: WaterfallLayer!
    fileprivate var _legendLayer: CALayer!
    
    fileprivate var _legendAttributes = [String:AnyObject]()    // Font & Size for the Legend
    fileprivate var _numberOfLegends = 0                        // Number of legend marks
    fileprivate var _increment = 0                              // Seconds between marks

    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)
    fileprivate let kTimeLegendWidth: CGFloat = 40              // width of legend layer
    fileprivate let kXPosition: CGFloat = 4                     // x-position of legend
    fileprivate let kRootlayer = "rootLayer"
    fileprivate let kLegendlayer = "legendLayer"
    fileprivate let kWaterfalllayer = "waterfallLayer"

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        
//        // create the Waterfall layers
//        setupLayers()
//    }
    /// Awake from nib
    ///
    override func awakeFromNib() {
        
        // create the Waterfall layers
        setupLayers()

        // setup the Legend font & size
        _legendAttributes[NSFontAttributeName] = NSFont(name: "Monaco", size: 12.0)
        
        // give the Waterfall layer a reference to the Params
        _spectrumLayer.params = params
        
        // add notification subscriptions
        addNotifications()

        // setup observations of Waterfall
        observations(_waterfall!, paths: _waterfallKeyPaths)
    }
    /// The view is about to begin resizing
    ///
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        
        // freeze the spectrum waveform
        _spectrumLayer.liveResize = true
    }
    /// The view's resizing has ended
    ///
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        
        // resume drawing the spectrum waveform
        _spectrumLayer.liveResize = false
        
        // reconfigure the Time legend
        calcLegendParams()
        redrawLegend()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    /// Cause the Time legend to be redrawn
    ///
    func redrawLegend() {
        
        // interact with the UI
        DispatchQueue.main.async { [unowned self] in
            self._legendLayer.setNeedsDisplay()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Create the CALayers for the Waterfall display
    ///
    fileprivate func setupLayers() {
        
        // create layer constraints
        let minY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY)
        let maxY = CAConstraint(attribute: .maxY, relativeTo: "superlayer", attribute: .maxY)
        let minX = CAConstraint(attribute: .minX, relativeTo: "superlayer", attribute: .minX)
        let maxX = CAConstraint(attribute: .maxX, relativeTo: "superlayer", attribute: .maxX)
        
        // Root layer
        _rootLayer = CALayer()                                      // ***** Root layer *****
        _rootLayer.name = kRootlayer
        _rootLayer.layoutManager = CAConstraintLayoutManager()
        _rootLayer.bounds = NSRectToCGRect(bounds)
        layerUsesCoreImageFilters = true
        
        // make this a layer-hosting view
        layer = _rootLayer
        wantsLayer = true

        // Spectrum layer
        _spectrumLayer = WaterfallLayer()                           // ***** Waterfall layer *****
        _spectrumLayer.name = kWaterfalllayer
        _spectrumLayer.frame = _rootLayer.frame
        _spectrumLayer.addConstraint(minY)                          // constraints
        _spectrumLayer.addConstraint(maxY)
        _spectrumLayer.addConstraint(minX)
        _spectrumLayer.addConstraint(maxX)
        _spectrumLayer.delegate = _spectrumLayer                    // delegate

        // Legend layer
        _legendLayer = CALayer()                                    // ***** Time Legend layer *****
        _legendLayer.name = kLegendlayer
        _legendLayer.frame = CGRect(x: _rootLayer.frame.width - kTimeLegendWidth, y: 0, width: kTimeLegendWidth, height: _rootLayer.frame.height)
        _legendLayer.addConstraint(minY)                            // constraints
        _legendLayer.addConstraint(maxY)
        _legendLayer.addConstraint(maxX)
        _legendLayer.delegate = self                                // delegate

        // select a compositing filter
        // possible choices - CIExclusionBlendMode, CIDifferenceBlendMode, CIMaximumCompositing
        if let compositingFilter = CIFilter(name: "CIDifferenceBlendMode") {
            _legendLayer.compositingFilter = compositingFilter
        }
        // setup the layer hierarchy
        _rootLayer.addSublayer(_spectrumLayer)
        _rootLayer.addSublayer(_legendLayer)
    }
    /// Calculate the number & spacing of the Time legends
    ///
    private func calcLegendParams() {

        DispatchQueue.main.async { [unowned self] in
            
            // calc the height in seconds of the waterfall
            let maxDuration = Int(self.frame.height * CGFloat(self._lineDuration) / 1_000.0)
            
            // calc the number of legends and the spacing between them
            switch maxDuration {
            case 0..<10 :
                self._numberOfLegends = 3
            case 10..<30 :
                self._numberOfLegends = 6
            case 30..<60 :
                self._numberOfLegends = 9
            default:
                self._numberOfLegends = 12
            }
            // calc the "seconds" between legends
            self._increment = maxDuration / (self._numberOfLegends + 1)
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation methods

    fileprivate let _waterfallKeyPaths =              // Waterfall keypaths to observe
        [
            #keyPath(Waterfall.lineDuration)
        ]
    /// Add / Remove property observations
    ///
    /// - Parameters:
    ///   - object: the object of the observations
    ///   - paths: an array of KeyPaths
    ///   - add: add / remove (defaults to add)
    ///
    fileprivate func observations<T: NSObject>(_ object: T, paths: [String], remove: Bool = false) {
        
        // for each KeyPath Add / Remove observations
        for keyPath in paths {
            
            if remove { object.removeObserver(self, forKeyPath: keyPath, context: nil) }
            else { object.addObserver(self, forKeyPath: keyPath, options: [.initial, .new], context: nil) }
        }
    }
    /// Observe properties
    ///
    /// - Parameters:
    ///   - keyPath: the registered KeyPath
    ///   - object: object containing the KeyPath
    ///   - change: dictionary of values
    ///   - context: context (if any)
    ///
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
        
        case #keyPath(Waterfall.lineDuration):
            
            // recalc the Legend params & refresh the display
            calcLegendParams()
            redrawLegend()
            
        default:
            _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    fileprivate func addNotifications() {
        
        NC.makeObserver(self, with: #selector(waterfallWillBeRemoved(_:)), of: .waterfallWillBeRemoved, object: nil)
    }
    /// Process .waterfallWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Waterfall object?
        if let waterfall = note.object as? Waterfall {
            
            // is it this waterfall
            if waterfall == _waterfall! {
                
                // YES, remove Waterfall property observers
                observations(waterfall, paths: _waterfallKeyPaths, remove: true)

                _log.msg("Observation removed - waterfall \(waterfall), paths \(_waterfallKeyPaths)", level: .debug, function: #function, file: #file, line: #line)
            }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - CALayerDelegate methods
    
    /// Draw the Waterfall Legend layer
    ///
    /// - Parameters:
    ///   - layer:      the Layer
    ///   - ctx:        the CGContext
    ///
    func draw(_ layer: CALayer, in ctx: CGContext) {
        
        // set the legend color
        _legendAttributes[NSForegroundColorAttributeName] = Defaults[.dbLegend]
        
        // draw the Waterfall Legend
        if layer.name == kLegendlayer {
            
            // setup the graphics context
            let context = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.setCurrent(context)
            
            // FIXME: Legend values during line duration change???
            
            for i in 0..<_numberOfLegends {
                
                // calc the y position of the legend
                let yPosition: CGFloat = frame.height - ( (frame.height / CGFloat(_numberOfLegends)) * CGFloat(i) )
                
                // format the legend String & draw it
                let timeLegend = NSString.localizedStringWithFormat("- % 2ds", _increment * i)
                timeLegend.draw(at: NSMakePoint( kXPosition, yPosition), withAttributes: _legendAttributes)
            }
        }
        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
}
