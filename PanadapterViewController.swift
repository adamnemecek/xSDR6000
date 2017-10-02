//
//  PanadapterViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/13/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

typealias BandwidthParamTuple = (high: Int, low: Int, spacing: Int, format: String)

// --------------------------------------------------------------------------------
// MARK: - Panadapter View Controller class implementation
// --------------------------------------------------------------------------------

final class PanadapterViewController : NSViewController, NSGestureRecognizerDelegate {

    static let kBandwidthParams: [BandwidthParamTuple] =    // spacing & format vs Bandwidth
        [   //      Bandwidth               Legend
            //  high         low      spacing   format
            (15_000_000, 10_000_000, 1_000_000, "%0.0f"),           // 15.00 -> 10.00 Mhz
            (10_000_000,  5_000_000,   400_000, "%0.1f"),           // 10.00 ->  5.00 Mhz
            ( 5_000_000,   2_000_000,  200_000, "%0.1f"),           //  5.00 ->  2.00 Mhz
            ( 2_000_000,   1_000_000,  100_000, "%0.1f"),           //  2.00 ->  1.00 Mhz
            ( 1_000_000,     500_000,   50_000, "%0.2f"),           //  1.00 ->  0.50 Mhz
            (   500_000,     400_000,   40_000, "%0.2f"),           //  0.50 ->  0.40 Mhz
            (   400_000,     200_000,   20_000, "%0.2f"),           //  0.40 ->  0.20 Mhz
            (   200_000,     100_000,   10_000, "%0.2f"),           //  0.20 ->  0.10 Mhz
            (   100_000,      40_000,    4_000, "%0.3f"),           //  0.10 ->  0.04 Mhz
            (    40_000,      20_000,    2_000, "%0.3f"),           //  0.04 ->  0.02 Mhz
            (    20_000,      10_000,    1_000, "%0.3f"),           //  0.02 ->  0.01 Mhz
            (    10_000,       5_000,      500, "%0.4f"),           //  0.01 ->  0.005 Mhz
            (    5_000,            0,      400, "%0.4f")            //  0.005 -> 0 Mhz
    ]

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var frequencyLegendHeight: CGFloat = 20                         // height of the Frequency Legend layer
    var markerHeight: CGFloat = 0.6                                 // height % for band markers
    var dbLegendWidth: CGFloat = 40
    var dbLegendFont = NSFont(name: "Monaco", size: 12.0)
    var frequencyLegendFont = NSFont(name: "Monaco", size: 12.0)

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _params                 : Params { return representedObject as! Params }
    fileprivate var _radio                  : Radio { return _params.radio }
    fileprivate var _panadapter             : Panadapter? { return _params.panadapter }
    
    fileprivate var _center                 : Int {return _panadapter!.center }
    fileprivate var _bandwidth              : Int { return _panadapter!.bandwidth }
    fileprivate var _start                  : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                    : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit              : CGFloat { return CGFloat(_end - _start) / view.frame.width }
    
    fileprivate var _rootLayer              : CALayer!              // layers
    fileprivate var _spectrumLayer          : SpectrumLayer!
    fileprivate var _frequencyLegendLayer   : FrequencyLegendLayer!
    fileprivate var _dbLegendLayer          : DbLegendLayer!
    fileprivate var _tnfLayer               : TnfLayer!
    fileprivate var _sliceLayer             : SliceLayer!

    fileprivate var _minY                   : CAConstraint!
    fileprivate var _minX                   : CAConstraint!
    fileprivate var _maxY                   : CAConstraint!
    fileprivate var _maxX                   : CAConstraint!
    fileprivate var _aboveFrequencyLegendY  : CAConstraint!

    fileprivate var _panLeft                : NSPanGestureRecognizer!
    fileprivate var _clickRight             : NSClickGestureRecognizer!

    //    fileprivate var _startPosition: CGFloat = 0
    fileprivate var _newCursor              : NSCursor!
    fileprivate var _startPercent           : CGFloat = 0.0
    fileprivate var _startFreq              : CGFloat = 0.0
    fileprivate var _previousPosition       = NSPoint(x: 0.0, y: 0.0)
    fileprivate var _originalPosition       = NSPoint(x: 0.0, y: 0.0)
    fileprivate var _dbmTop                 = false

    fileprivate var _spacings               = [String]()            // db legend spacing choices

    // constants
    fileprivate let _log                    = (NSApp.delegate as! AppDelegate)
    
    fileprivate let _dbLegendFormat         = " %4.0f"
    fileprivate let _dbLegendWidth          : CGFloat = 40          // width of Db Legend layer
    fileprivate let _frequencyLineWidth     : CGFloat = 3.0
    fileprivate let kRootLayer              = "root"                // layer names
    fileprivate let kSpectrumLayer          = "spectrum"
    fileprivate let kFrequencyLegendLayer   = "frequency"
    fileprivate let kDbLegendLayer          = "legend"
    fileprivate let kTnfLayer               = "tnf"
    fileprivate let kSliceLayer             = "slice"
    fileprivate let kLeftButton             = 0x01                  // button masks
    fileprivate let kRightButton            = 0x02

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()

        // create Spectrum, frequencyLegend & dbLegend layesr
        setupLayers()
        
        _spectrumLayer.spectrumStyle = .line
        
        // get the default Metal device
        _spectrumLayer.device = MTLCreateSystemDefaultDevice()
        guard _spectrumLayer.device != nil else {
            fatalError("Metal is not supported on this device")
        }

        // setup buffers
        _spectrumLayer.setup()
        
        // setup the spectrum background color
        _spectrumLayer.setClearColor(Defaults[.spectrumBackground])

        // setup Uniforms
        _spectrumLayer.populateUniforms(size: view.frame.size)
        _spectrumLayer.updateUniformsBuffer()
        
        // direct spectrum data to the spectrum layer
        _panadapter?.delegate = _spectrumLayer

        // Pan (Left Button)
        _panLeft = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
        _panLeft.buttonMask = kLeftButton
        view.addGestureRecognizer(_panLeft)
        
        // get the list of possible spacings
        _spacings = Defaults[.dbLegendSpacings]
        
        // Click (Right Button)
        _clickRight = NSClickGestureRecognizer(target: self, action: #selector(clickRight(_:)))
        _clickRight.buttonMask = kRightButton
        _clickRight.delegate = self
        view.addGestureRecognizer(_clickRight)

        // capture existing Tnfs
        captureInitialTnfs()

        // capture existing Slices
        captureInitialSlices()
        
        // begin observations
        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
        observations(_panadapter!, paths: _panadapterKeyPaths)
        observations(_radio, paths: _radioKeyPaths)

        // add notification subscriptions
        addNotifications()

        _frequencyLegendLayer.redraw()
        _dbLegendLayer.redraw()
        _tnfLayer.redraw()
        _sliceLayer.redraw()
    }
    /// View did layout
    ///
    override func viewDidLayout() {
        
        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: view.frame.width, height: view.frame.height)
        
        // update the spectrum layer
        _spectrumLayer.populateUniforms(size: view.frame.size)
        _spectrumLayer.updateUniformsBuffer()
    }

    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Setup any Tnf's present at viewDidLoad time
    ///
    func captureInitialTnfs() {
        
        for (_, tnf) in _radio.tnfs {
            // add observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths)
        }
    }
    /// Setup any Slices present at viewDidLoad time
    ///
    func captureInitialSlices() {
        
        for (_, slice) in _radio.slices {
            // add observations of this Slice
            observations(slice, paths: _sliceKeyPaths)
        }
    }
    /// Establish the Layers and their relationships to each other
    ///
    fileprivate func setupLayers() {
        
        // create layer constraints
        _minY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY)
        _maxY = CAConstraint(attribute: .maxY, relativeTo: "superlayer", attribute: .maxY)
        _minX = CAConstraint(attribute: .minX, relativeTo: "superlayer", attribute: .minX)
        _maxX = CAConstraint(attribute: .maxX, relativeTo: "superlayer", attribute: .maxX)
        _aboveFrequencyLegendY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY, offset: frequencyLegendHeight)
        
        // create layers
        _rootLayer = CALayer()                                      // ***** Root layer *****
        _rootLayer.name = kRootLayer
        _rootLayer.layoutManager = CAConstraintLayoutManager()
        _rootLayer.frame = view.frame
        view.layerUsesCoreImageFilters = true
        
        // make this a layer-hosting view
        view.layer = _rootLayer
        view.wantsLayer = true
        
        // select a compositing filter
        // possible choices - CIExclusionBlendMode, CIDifferenceBlendMode, CIMaximumCompositing
        guard let compositingFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            fatalError("Unable to create compositing filter")
        }
        
        _spectrumLayer = SpectrumLayer()                            // ***** Panadapter Spectrum layer *****
        _spectrumLayer.name = kSpectrumLayer
        _spectrumLayer.frame = CGRect(x: 0, y: frequencyLegendHeight, width: _rootLayer.frame.width, height: _rootLayer.frame.height - frequencyLegendHeight)
        _rootLayer.frame = view.frame
        _spectrumLayer.addConstraint(_minX)                             // constraints
        _spectrumLayer.addConstraint(_maxX)
        _spectrumLayer.addConstraint(_aboveFrequencyLegendY)
        _spectrumLayer.addConstraint(_minY)
        _spectrumLayer.addConstraint(_maxY)
        _spectrumLayer.pixelFormat = .bgra8Unorm
        _spectrumLayer.framebufferOnly = true
        _spectrumLayer.delegate = _spectrumLayer                        // delegate
        
        _dbLegendLayer = DbLegendLayer(params: _params)                 // ***** Db Legend layer *****
        _dbLegendLayer.name = kDbLegendLayer
        _dbLegendLayer.addConstraint(_minX)                             // constraints
        _dbLegendLayer.addConstraint(_maxX)
        _dbLegendLayer.addConstraint(_aboveFrequencyLegendY)
        _dbLegendLayer.addConstraint(_maxY)
        _dbLegendLayer.delegate = _dbLegendLayer                        // delegate
        _dbLegendLayer.compositingFilter = compositingFilter

        _frequencyLegendLayer = FrequencyLegendLayer(params: _params)   // ***** Frequency Legend layer *****
        _frequencyLegendLayer.name = kFrequencyLegendLayer
        _frequencyLegendLayer.addConstraint(_minX)                      // constraints
        _frequencyLegendLayer.addConstraint(_maxX)
        _frequencyLegendLayer.addConstraint(_minY)
        _frequencyLegendLayer.addConstraint(_maxY)
        _frequencyLegendLayer.delegate = _frequencyLegendLayer          // delegate
        _frequencyLegendLayer.compositingFilter = compositingFilter
        _frequencyLegendLayer.height = frequencyLegendHeight
        
        _tnfLayer = TnfLayer(params: _params)                           // ***** Tnf layer *****
        _tnfLayer.name = kTnfLayer
        _tnfLayer.addConstraint(_minX)                                  // constraints
        _tnfLayer.addConstraint(_maxX)
        _tnfLayer.addConstraint(_aboveFrequencyLegendY)
        _tnfLayer.addConstraint(_maxY)
        _tnfLayer.delegate = _tnfLayer                                  // delegate
        _tnfLayer.compositingFilter = compositingFilter

        _sliceLayer = SliceLayer(params: _params)                       // ***** Slice layer *****
        _sliceLayer.name = kSliceLayer
        _sliceLayer.addConstraint(_minX)                                // constraints
        _sliceLayer.addConstraint(_maxX)
        _sliceLayer.addConstraint(_aboveFrequencyLegendY)
        _sliceLayer.addConstraint(_maxY)
        _sliceLayer.delegate = _sliceLayer                                // delegate
        _sliceLayer.compositingFilter = compositingFilter

        // setup the layer hierarchy
        _rootLayer.addSublayer(_spectrumLayer)
        _rootLayer.addSublayer(_frequencyLegendLayer)
        _rootLayer.addSublayer(_dbLegendLayer)
        _rootLayer.addSublayer(_tnfLayer)
        _rootLayer.addSublayer(_sliceLayer)

        // add notification subscriptions
//        addNotifications()
    }
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeft(_ gr: NSPanGestureRecognizer) {
        
        // get the current position
        let currentPosition = gr.location(in: view)

        // ----------------------------------------------------------------------------
        // Start of Nested methods & enums
        
        enum UpdateType {
            case center
            case bandwidth
            case dbm
        }
        // function to perform dragging
        func drag(type: UpdateType, cursor: NSCursor) {
            // **** LEFT button drag RIGHT/LEFT in FREQ LEGEND ****
            switch gr.state {
                
            case .began:
                // set the cursor
                cursor.push()

                // save the starting coordinate
                _previousPosition = currentPosition
                
                // calculate start's percent of width & it's frequency (only used by freq legend)
                _startPercent = currentPosition.x / view.frame.width
                _startFreq = (_startPercent * CGFloat(_bandwidth)) + CGFloat(_start)
                
            case .changed:
                // update the panadapter params
                update(type, _previousPosition, currentPosition)
                
                // use the current (intermediate) location as the start
                _previousPosition = currentPosition

            case .ended:
                // update the panadapter params
                update(type, _previousPosition, currentPosition)
                
                // restore the previous cursor
                NSCursor.pop()

            default:
                // ignore other states
                break
            }
        }
        // function to update panadapter center, center & bandwidth or db legend
        func update(_ type: UpdateType, _ previous: NSPoint, _ current: NSPoint) {
            
            switch type {
            case .center:
                // adjust the center
                _panadapter!.center = _panadapter!.center - Int( (current.x - previous.x) * _hzPerUnit)

                // redraw the frequency legend
                _frequencyLegendLayer.redraw()

            case .bandwidth:
                // CGFloat versions of params
                let end = CGFloat(_end)                     // end frequency (Hz)
                let start = CGFloat(_start)                 // start frequency (Hz)
                let bandwidth = CGFloat(_bandwidth)         // bandwidth (hz)
                
                // calculate the % change, + = greater bw, - = lesser bw
                let delta = ((previous.x - current.x) / view.frame.width)
                
                // calculate the new bandwidth (Hz)
                let newBandwidth = (1 + delta) * bandwidth
                
                // calculate adjustments to start & end
                let adjust = (newBandwidth - bandwidth) / 2.0
                let newStart = start - adjust
                let newEnd = end + adjust
                
                // calculate adjustment to the center
                let newStartPercent = (_startFreq - newStart) / newBandwidth
                let freqError = (newStartPercent - _startPercent) * newBandwidth
                let newCenter = (newStart + freqError) + (newEnd - newStart) / 2.0
                
                // adjust the center & bandwidth values (Hz)
                _panadapter!.center = Int(newCenter)
                _panadapter!.bandwidth = Int(newBandwidth)

                // redraw the frequency legend
                _frequencyLegendLayer.redraw()

            case .dbm:
                // Upper half of the db legend?
                if _originalPosition.y > view.frame.height/2 {
                    // YES, update the max value
                    _panadapter!.maxDbm += (previous.y - current.y)
                } else {
                    // NO, update the min value
                    _panadapter!.minDbm += (previous.y - current.y)
                }
                // redraw the db legend
                _dbLegendLayer.redraw()
            }
        }

        // ----------------------------------------------------------------------------
        // End of Nested methods & enums
        
        // save the starting position
        if gr.state == .began { _originalPosition = currentPosition }
        
        // decide what type of drag this is
        switch _originalPosition.y {
        case 0..<frequencyLegendHeight:
            drag(type: .bandwidth, cursor: NSCursor.resizeLeftRight())      // frequency legend drag
            
        case frequencyLegendHeight...:
            
            switch _originalPosition.x {
            case (view.frame.width - dbLegendWidth)...:
                drag(type: .dbm, cursor: NSCursor.resizeUpDown())           // db legend drag
                
            default:
                drag(type: .center, cursor: NSCursor.resizeLeftRight())     // spectrum drag
            }
        default:                                                            // should never occur
            break
        }
    }
    /// Prevent the Right Click recognizer from responding when the mouse is not over the Legend
    ///
    /// - Parameters:
    ///   - gr: the Gesture Recognizer
    ///   - event: the Event
    /// - Returns: True = allow, false = ignore
    ///
    func gestureRecognizer(_ gr: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        
        // is it a right click?
        if gr == _clickRight {
            // YES, if not over the legend, push it
            return view.convert(event.locationInWindow, from: nil).x >= view.frame.width - _dbLegendWidth
        } else {
            // not right click, process it
            return true
        }
    }
    /// respond to Right Click gesture
    ///     NOTE: will only receive events in db legend, see previous method
    ///
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc fileprivate func clickRight(_ gr: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        
        // get the "click" coordinates and convert to this View
        let location = gr.location(in: view)
        
        // create the Spacings popup menu
        let menu = NSMenu(title: "Spacings")
        
        // populate the popup menu of Spacings
        for i in 0..<_spacings.count {
            item = menu.insertItem(withTitle: "\(_spacings[i]) dbm", action: #selector(legendSpacing(_:)), keyEquivalent: "", at: i)
            item.tag = Int(_spacings[i]) ?? 0
            item.target = self
        }
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: location, in: view)
    }
    /// respond to the Context Menu selection
    ///
    /// - Parameter sender:     the Context Menu
    ///
    @objc fileprivate func legendSpacing(_ sender: NSMenuItem) {
        
        // set the Db Legend spacing
        Defaults[.dbLegendSpacing] = String(sender.tag, radix: 10)
        
        // redraw the db legend
        _dbLegendLayer.redraw()
        
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _defaultsKeyPaths = [               // Defaults keypaths to observe
        "gridLines",
        "spectrum",
        "spectrumBackground",
        "tnfInactive",
        "tnfNormal",
        "tnfDeep",
        "tnfVeryDeep",
        "sliceActive",
        "sliceInactive",
        "sliceFilter"
    ]
    
    fileprivate let _tnfKeyPaths = [                    // Tnf keypaths to observe
        #keyPath(Tnf.frequency),
        #keyPath(Tnf.depth),
        #keyPath(Tnf.width),
        ]
    
    fileprivate let _radioKeyPaths = [                  // Radio keypaths to observe
        #keyPath(Radio.tnfEnabled)
    ]
    
    fileprivate let _panadapterKeyPaths = [             // Panadapter keypaths to observe
        #keyPath(Panadapter.bandwidth),
        #keyPath(Panadapter.center)
    ]

    fileprivate let _sliceKeyPaths = [
        #keyPath(xLib6000.Slice.frequency),
        #keyPath(xLib6000.Slice.filterLow),
        #keyPath(xLib6000.Slice.filterHigh)
    ]
    
    /// Add / Remove property observations
    ///
    /// - Parameters:
    ///   - object:         the object of the observations
    ///   - paths:          an array of KeyPaths
    ///   - add:            add / remove (defaults to add)
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
    ///   - keyPath:        the registered KeyPath
    ///   - object:         object containing the KeyPath
    ///   - change:         dictionary of values
    ///   - context:        context (if any)
    ///
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case "gridLines", "spectrum", "tnfInactive":
            _spectrumLayer.populateUniforms(size: view.frame.size)
            _spectrumLayer.updateUniformsBuffer()
            
        case "gridLines":
            _frequencyLegendLayer.redraw()
            _dbLegendLayer.redraw()
            
        case "spectrumBackground":
            _spectrumLayer.setClearColor(Defaults[.spectrumBackground])
            
        case "sliceInactive", "sliceActive", "sliceFilter":
            _sliceLayer.redraw()
            
        case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
            _sliceLayer.redraw()
            _frequencyLegendLayer.redraw()
            fallthrough
            
        case #keyPath(Radio.tnfEnabled):
            fallthrough
            
        case "tnfInactive", "tnfNormal", "tnfDeep", "tnfVeryDeep":
            fallthrough
            
        case #keyPath(Tnf.frequency), #keyPath(Tnf.depth), #keyPath(Tnf.width):
            _tnfLayer.redraw()
            
        case #keyPath(xLib6000.Slice.frequency), #keyPath(xLib6000.Slice.filterLow), #keyPath(xLib6000.Slice.filterHigh):
            _sliceLayer.redraw()
        
        default:
            _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    fileprivate func addNotifications() {
        
        NC.makeObserver(self, with: #selector(sliceHasBeenAdded(_:)), of: .sliceHasBeenAdded, object: nil)
        
        NC.makeObserver(self, with: #selector(sliceWillBeRemoved(_:)), of: .sliceWillBeRemoved, object: nil)

        NC.makeObserver(self, with: #selector(tnfHasBeenAdded(_:)), of: .tnfHasBeenAdded, object: nil)
        
        NC.makeObserver(self, with: #selector(tnfWillBeRemoved(_:)), of: .tnfWillBeRemoved, object: nil)
        
        NC.makeObserver(self, with: #selector(panadapterWillBeRemoved(_:)), of: .panadapterWillBeRemoved, object: nil)
    }
    /// Process .panadapterWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func panadapterWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Panadapter object?
        if let panadapter = note.object as? Panadapter {
            
            // YES, is it this panadapter
            if panadapter == _panadapter! {
                
                // YES, remove Defaults property observers
                observations(Defaults, paths: _defaultsKeyPaths, remove: true)
                
                // remove Radio property observers
                observations(_radio, paths: _radioKeyPaths, remove: true)
                
                // remove Panadapter property observers
                observations(panadapter, paths: _panadapterKeyPaths, remove: true)
            }
        }
    }
    /// Process .sliceHasBeenAdded Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func sliceHasBeenAdded(_ note: Notification) {
        
        // does the Notification contain a SLice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, add observations of this Slice
            observations(slice, paths: _sliceKeyPaths)
            
            // force a redraw
            _sliceLayer.redraw()
        }
    }
    /// Process .sliceWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func sliceWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Slice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, remove observations of this Slice
            observations(slice, paths: _sliceKeyPaths, remove: true)
            
            // force a redraw
            _sliceLayer.redraw()
        }
    }
    /// Process .tnfHasBeenAdded Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func tnfHasBeenAdded(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? Tnf {
            
            // YES, add observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths)

            // force a redraw
            _tnfLayer.redraw()
        }
    }
    /// Process .tnfWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func tnfWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? Tnf {
            
            // YES, remove observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths, remove: true)
            
            // force a redraw
            _tnfLayer.redraw()
        }
    }
}
