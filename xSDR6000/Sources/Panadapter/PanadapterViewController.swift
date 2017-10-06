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

// --------------------------------------------------------------------------------
// MARK: - Panadapter View Controller class implementation
// --------------------------------------------------------------------------------

final class PanadapterViewController : NSViewController, NSGestureRecognizerDelegate {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private var _panadapterView   : PanadapterView!

    fileprivate var _params                 : Params { return representedObject as! Params }
    fileprivate var _radio                  : Radio { return _params.radio }
    fileprivate var _panadapter             : Panadapter? { return _params.panadapter }
    
    fileprivate var _center                 : Int {return _panadapter!.center }
    fileprivate var _bandwidth              : Int { return _panadapter!.bandwidth }
    fileprivate var _start                  : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                    : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit              : CGFloat { return CGFloat(_end - _start) / view.frame.width }
    
    fileprivate var _newCursor              : NSCursor!
    fileprivate var _startPercent           : CGFloat = 0.0
    fileprivate var _startFreq              : CGFloat = 0.0
    fileprivate var _previousPosition       = NSPoint(x: 0.0, y: 0.0)
    fileprivate var _originalPosition       = NSPoint(x: 0.0, y: 0.0)
    fileprivate var _originalType           : UpdateType!
    fileprivate var _dbmTop                 = false
    fileprivate var _dragSlice              : xLib6000.Slice?
    fileprivate var _dragTnf                : Tnf?

    fileprivate var _spacings               = Defaults[.dbLegendSpacings]
    fileprivate var _multiplier             : CGFloat = 0.0

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

    enum UpdateType {
        case bandwidth
        case center
        case dbm
        case slice
        case tnf
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _panadapterView.delegate = self

        _multiplier = CGFloat(_bandwidth) * 0.001
        
//        // create Spectrum, frequency Legend, dbLegend, Tnf & Slice layers
//        createLayers()
        
//        // get the default Metal device
//        _spectrumLayer.device = MTLCreateSystemDefaultDevice()
//        guard _spectrumLayer.device != nil else {
//            fatalError("Metal is not supported on this device")
//        }
        
        // setup Spectrum Layer
        setupSpectrumLayer()
        
        passParams()
        
        // direct spectrum data to the spectrum layer
        _panadapter?.delegate = _panadapterView.spectrumLayer

        // begin observations (defaults, panadapter, radio, tnf & slice)
        setupObservations()
        
        // draw each layer once
        _panadapterView.frequencyLegendLayer.redraw()
        _panadapterView.dbLegendLayer.redraw()
        _panadapterView.tnfLayer.redraw()
        _panadapterView.sliceLayer.redraw()
    }
    /// View did layout
    ///
    override func viewDidLayout() {
        
        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: view.frame.width, height: view.frame.height)
        
        // update the spectrum layer
        _panadapterView.spectrumLayer.populateUniforms(size: view.frame.size)
        _panadapterView.spectrumLayer.updateUniformsBuffer()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    public func redrawFrequencyLegend() {
        _panadapterView.frequencyLegendLayer.redraw()
    }
    public func redrawDbLegend() {
        _panadapterView.dbLegendLayer.redraw()
    }
    public func redrawTnfs() {
        _panadapterView.tnfLayer.redraw()
    }
    public func redrawSlices() {
        _panadapterView.sliceLayer.redraw()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods

    func passParams() {
        
        _panadapterView.frequencyLegendLayer.params = _params
        _panadapterView.dbLegendLayer.params = _params
        _panadapterView.sliceLayer.params = _params
        _panadapterView.tnfLayer.params = _params
    }
    
    /// Setup Spectrum layer buffers & parameters
    ///
    func setupSpectrumLayer() {
        
        // TODO: Make this a preference value
        _panadapterView.spectrumLayer.spectrumStyle = .line
        
        // setup buffers
        _panadapterView.spectrumLayer.setupBuffers()
        
        // setup the spectrum background color
        _panadapterView.spectrumLayer.setClearColor(Defaults[.spectrumBackground])
        
        // setup Uniforms
        _panadapterView.spectrumLayer.populateUniforms(size: view.frame.size)
        _panadapterView.spectrumLayer.updateUniformsBuffer()
    }
    /// Setup Tnf's & Slices present at viewDidLoad time, start observations & Notification
    ///
    func setupObservations() {
        
        // capture tnfs present at viewDidLoad time
        for (_, tnf) in _radio.tnfs {
            // add observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths)
        }
        // capture slices present at viewDidLoad time
        for (_, slice) in _radio.slices {
            // add observations of this Slice
            observations(slice, paths: _sliceKeyPaths)
        }
        // begin observations (defaults, panadapter & radio)
        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
        observations(_panadapter!, paths: _panadapterKeyPaths)
        observations(_radio, paths: _radioKeyPaths)

        // add notification subscriptions
        addNotifications()
    }
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc func panLeft(_ gr: NSPanGestureRecognizer) {
        
        // get the current position
        let currentPosition = gr.location(in: view)

        // ----------------------------------------------------------------------------
        // Start of Nested methods & enums
        
        // function to monitor dragging
        func drag(type: UpdateType, cursor: NSCursor, object: Any?) {
            // **** LEFT button drag RIGHT/LEFT in FREQ LEGEND ****
            switch gr.state {
                
            case .began:
                // set the cursor
                cursor.push()

                // save the starting coordinate
                _previousPosition = currentPosition
                
            case .changed:
                // update the panadapter view
                update(type, _previousPosition, currentPosition, object)
                
                // use the current (intermediate) location as the start
                _previousPosition = currentPosition

            case .ended:
                // update the panadapter view
                update(type, _previousPosition, currentPosition, object)
                
                // restore the previous cursor
                NSCursor.pop()

            default:
                // ignore other states
                break
            }
        }
        // function to update panadapter view(s)
        func update(_ type: UpdateType, _ previous: NSPoint, _ current: NSPoint, _ object: Any?) {
            
            switch type {
            case .bandwidth:
                // is there a panadapter object?
                if let pan = object as? Panadapter {
                    
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
                    pan.center = Int(newCenter)
                    pan.bandwidth = Int(newBandwidth)
                    
                    // redraw the frequency legend
                    _panadapterView.frequencyLegendLayer.redraw()
                }

            case .center:
                // is there a panadapter object?
                if let pan = object as? Panadapter {
                    
                    // adjust the center
                    pan.center = pan.center - Int( (current.x - previous.x) * _hzPerUnit)
                    
                    // redraw the frequency legend
                    _panadapterView.frequencyLegendLayer.redraw()
                }
                
            case .dbm:
                // is there a panadapter object?
                if let pan = object as? Panadapter {
                    
                    // YES, Upper half of the db legend?
                    if _originalPosition.y > view.frame.height/2 {
                        // YES, update the max value
                        pan.maxDbm += (previous.y - current.y)
                    } else {
                        // NO, update the min value
                        pan.minDbm += (previous.y - current.y)
                    }
                    // redraw the db legend
                    _panadapterView.dbLegendLayer.redraw()
                }

            case .slice:
                // calculate offsets in x & y
                let deltaX = current.x - previous.x
                let deltaY = current.y - previous.y
                
                // is there a slice object?
                if let slice = object as? xLib6000.Slice {
                    
                    // YES, drag or resize?
                    if abs(deltaX) > abs(deltaY) {
                        // drag
                        slice.frequency += Int(deltaX * _hzPerUnit)
                    } else {
                        // resize
                        slice.filterLow -= Int(deltaY * _multiplier)
                        slice.filterHigh += Int(deltaY * _multiplier)
                    }
                }
                // redraw the slices
                _panadapterView.sliceLayer.redraw()

            case .tnf:
                // calculate offsets in x & y
                let deltaX = current.x - previous.x
                let deltaY = current.y - previous.y
                
                // is there a tnf object?
                if let tnf = object as? Tnf {

                    // YES, drag or resize?
                    if abs(deltaX) > abs(deltaY) {
                        // drag
                        Swift.print("tnf drag")
                        tnf.frequency = Int(current.x * _hzPerUnit) + _start
                    } else {
                        // resize
                        tnf.width = tnf.width + Int(deltaY * _multiplier)
                    }
                }
                // redraw the tnfs
                _panadapterView.tnfLayer.redraw()
            }
        }

        // ----------------------------------------------------------------------------
        // End of Nested methods & enums
        
        // save the starting position
        if gr.state == .began {
            _originalPosition = currentPosition
            
            // calculate start's percent of width & it's frequency (only used by freq legend)
            _startPercent = currentPosition.x / view.frame.width
            _startFreq = (_startPercent * CGFloat(_bandwidth)) + CGFloat(_start)

            // what type of drag?
            if _originalPosition.y < _panadapterView.frequencyLegendLayer.height {
                
                // in frequency legend, bandwidth drag
                _originalType = .bandwidth
            
            } else if _originalPosition.x < view.frame.width - _panadapterView.dbLegendLayer.width {
               
                // in spectrum
                _dragSlice = sliceHitTest(frequency: _startFreq)
                _dragTnf = tnfHitTest(frequency: _startFreq)
                if let _ =  _dragSlice{
                    // Slice drag / resize
                    _originalType = .slice
                
                } else if let _ = _dragTnf {
                    // Tnf drag / resize
                    _originalType = .tnf
                
                } else {
                    // spectrum drag
                    _originalType = .center
                }
            } else {
                // in db legend, db legend drag
                _originalType = .dbm
            }
        }
        
        // decide what type of drag this is
        switch _originalType {
        case .bandwidth:
            drag(type: .bandwidth, cursor: NSCursor.resizeLeftRight(), object: _panadapter as Any)
            
        case .slice:
            drag(type: .slice, cursor: NSCursor.resizeLeftRight(), object: _dragSlice as Any)
            
        case .tnf:
            drag(type: .tnf, cursor: NSCursor.resizeLeftRight(), object: _dragTnf as Any)
            
        case .dbm:
            drag(type: .dbm, cursor: NSCursor.resizeUpDown(), object: _panadapter as Any)
            
        case .center:
            drag(type: .center, cursor: NSCursor.resizeLeftRight(), object: _panadapter as Any)
        
        default:    // should never happen
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
        if gr.action == #selector(PanadapterViewController.clickRight(_:)) {
            // YES, if not over the legend, push it up the responder chain
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
    @objc func clickRight(_ gr: NSClickGestureRecognizer) {
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
        _panadapterView.dbLegendLayer.redraw()
        
    }
    /// FInd the Slice at a frequency (if any)
    ///
    /// - Parameter freq:       the target frequency
    /// - Returns:              a slice or nil
    ///
    func sliceHitTest(frequency freq: CGFloat) -> xLib6000.Slice? {
        var slice: xLib6000.Slice?
        
        for (_, s) in _radio.slices {
            if s.frequency + s.filterLow <= Int(freq) && s.frequency + s.filterHigh >= Int(freq) {
                slice = s
                break
            }
        }
        return slice
    }
    /// FInd the Tnf at or near a frequency (if any)
    ///
    /// - Parameter freq:       the target frequency
    /// - Returns:              a tnf or nil
    ///
    func tnfHitTest(frequency freq: CGFloat) -> Tnf? {
        var tnf: Tnf?
        
        // calculate a minimum width for hit testing
        let effectiveWidth = Int( CGFloat(_bandwidth) * 0.01)
        
        for (_, t) in _radio.tnfs {
            
            let halfWidth = max(effectiveWidth, t.width/2)
            if t.frequency - halfWidth <= Int(freq) && t.frequency + halfWidth >= Int(freq) {
                tnf = t
                break
            }
        }
        return tnf
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _defaultsKeyPaths = [               // Defaults keypaths to observe
        "frequencyLegend",
        "dbLegend",
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
            
        case "frequencyLegend":
            _panadapterView.frequencyLegendLayer.redraw()
            
        case "dbLegend":
            _panadapterView.dbLegendLayer.redraw()
            
        case "gridLines":
            _panadapterView.frequencyLegendLayer.redraw()
            _panadapterView.dbLegendLayer.redraw()
            
        case "spectrum", "tnfInactive":
            _panadapterView.spectrumLayer.populateUniforms(size: view.frame.size)
            _panadapterView.spectrumLayer.updateUniformsBuffer()
            
        case "spectrumBackground":
            _panadapterView.spectrumLayer.setClearColor(Defaults[.spectrumBackground])
            
        case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
            _multiplier = CGFloat(_bandwidth) * 0.001
            _panadapterView.sliceLayer.redraw()
            _panadapterView.frequencyLegendLayer.redraw()
            fallthrough
            
        case #keyPath(Radio.tnfEnabled):
            fallthrough
        case "tnfInactive", "tnfNormal", "tnfDeep", "tnfVeryDeep":
            fallthrough
        case #keyPath(Tnf.frequency), #keyPath(Tnf.depth), #keyPath(Tnf.width):
            _panadapterView.tnfLayer.redraw()
            
        case "sliceInactive", "sliceActive", "sliceFilter":
           fallthrough            
        case #keyPath(xLib6000.Slice.frequency), #keyPath(xLib6000.Slice.filterLow), #keyPath(xLib6000.Slice.filterHigh):
            _panadapterView.sliceLayer.redraw()
        
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
            _panadapterView.sliceLayer.redraw()
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
            _panadapterView.sliceLayer.redraw()
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
            _panadapterView.tnfLayer.redraw()
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
            _panadapterView.tnfLayer.redraw()
        }
    }
}
