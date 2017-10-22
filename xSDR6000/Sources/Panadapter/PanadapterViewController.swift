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
    
    enum DragType {
        case dbm                            // +/- Panadapter dbm upper/lower level
        case frequency                      // +/- Panadapter bandwidth
        case slice                          // +/- Slice frequency/width
        case spectrum                       // +/- Panadapter center frequency
        case tnf                            // +/- Tnf frequency/width
    }

    struct Dragable {
        var type                            = DragType.spectrum
        var original                        = NSPoint(x: 0.0, y: 0.0)
        var previous                        = NSPoint(x: 0.0, y: 0.0)
        var current                         = NSPoint(x: 0.0, y: 0.0)
        var percent                         : CGFloat = 0.0
        var frequency                       : CGFloat = 0.0
        var cursor                          : NSCursor!
        var object                          : Any?
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panadapterView         : PanadapterView!
    fileprivate var _params                 : Params { return representedObject as! Params }
    fileprivate var _radio                  : Radio { return _params.radio }
    fileprivate var _panadapter             : Panadapter? { return _params.panadapter }
    
    fileprivate var _center                 : Int {return _panadapter!.center }
    fileprivate var _bandwidth              : Int { return _panadapter!.bandwidth }
    fileprivate var _start                  : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                    : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit              : CGFloat { return CGFloat(_end - _start) / view.frame.width }
    
    fileprivate var _panadapterLayer        : PanadapterLayer { return _panadapterView.panadapterLayer }
    fileprivate var _dbLayer                : DbLayer { return _panadapterView.dbLayer }
    fileprivate var _frequencyLayer         : FrequencyLayer { return _panadapterView.frequencyLayer }
    fileprivate var _tnfLayer               : TnfLayer { return _panadapterView.tnfLayer }
    fileprivate var _sliceLayer             : SliceLayer { return _panadapterView.sliceLayer }
    
    fileprivate var _dr                     = Dragable()

    // constants
    fileprivate let _log                    = (NSApp.delegate as! AppDelegate)
    
    fileprivate let kLeftButton             = 0x01                  // button masks
    fileprivate let kRightButton            = 0x02
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add notification subscriptions
        addNotifications()

        // make the view controller the delegate for the view
        _panadapterView = self.view as! PanadapterView
        _panadapterView.delegate = self

        // give each layer access to the Params struct
        passParams()
        
        // setup Panadapter Layer
        setupPanadapterLayer()
        
        // direct stream data to the panadapter layer
        _panadapter?.delegate = _panadapterLayer

        // begin observations (defaults, panadapter & radio)
        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
        observations(_panadapter!, paths: _panadapterKeyPaths)
        observations(_radio, paths: _radioKeyPaths)

        // draw each layer once
        _frequencyLayer.redraw()
        _dbLayer.redraw()
        _tnfLayer.redraw()
        _sliceLayer.redraw()
    }
    /// View did layout
    ///
    override func viewDidLayout() {
        
        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: view.frame.width, height: view.frame.height)
        
        // update the spectrum layer
        _panadapterLayer.populateUniforms(size: view.frame.size)
        _panadapterLayer.updateUniformsBuffer()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    // force a redraw of a layer
    
    public func redrawFrequencyLegend() {
        _frequencyLayer.redraw()
    }
    public func redrawDbLegend() {
        _dbLayer.redraw()
    }
    public func redrawTnfs() {
        _tnfLayer.redraw()
    }
    public func redrawSlices() {
        _sliceLayer.redraw()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc func panLeft(_ gr: NSPanGestureRecognizer) {

        // ----------------------------------------------------------------------------
        // nested function to update layers
        func update(_ dr: Dragable) {
            
            // call the appropriate function on the appropriate layer
            switch dr.type {
            case .dbm:
                _dbLayer.updateDbmLevel(dragable: dr)
                
            case .frequency:
                _frequencyLayer.updateBandwidth(dragable: dr)
                
            case .slice:
                _sliceLayer.updateSlice(dragable:dr)
                
            case .spectrum:
                _frequencyLayer.updateCenter(dragable: dr)
                
            case .tnf:
                _tnfLayer.updateTnf(dragable: dr)
            }
        }
        // ----------------------------------------------------------------------------

        // get the current position
        _dr.current = gr.location(in: view)
        
        // save the starting position
        if gr.state == .began {
            _dr.original = _dr.current
            
            // calculate start's percent of width & it's frequency
            _dr.percent = _dr.current.x / view.frame.width
            _dr.frequency = (_dr.percent * CGFloat(_bandwidth)) + CGFloat(_start)
            
            _dr.object = nil

            // what type of drag?
            if _dr.original.y < _frequencyLayer.height {
                
                // in frequency legend, bandwidth drag
                _dr.type = .frequency
                _dr.cursor = NSCursor.resizeLeftRight()

            } else if _dr.original.x < view.frame.width - _dbLayer.width {
                
                // in spectrum, check for presence of Slice or Tnf
                let dragSlice = hitTestSlice(at: _dr.frequency)
                let dragTnf = hitTestTnf(at: _dr.frequency)
                if let _ =  dragSlice{
                    // in Slice drag / resize
                    _dr.type = .slice
                    _dr.object = dragSlice
                    _dr.cursor = NSCursor.crosshair()

                } else if let _ = dragTnf {
                    // in Tnf drag / resize
                    _dr.type = .tnf
                    _dr.object = dragTnf
                    _dr.cursor = NSCursor.crosshair()

                } else {
                    // spectrum drag
                    _dr.type = .spectrum
                    _dr.cursor = NSCursor.resizeLeftRight()
                }
            } else {
                // in db legend, db legend drag
                _dr.type = .dbm
                _dr.cursor = NSCursor.resizeUpDown()
            }
        }
        // what portion of the drag are we in?
        switch gr.state {
            
        case .began:
            // set the cursor
            _dr.cursor.push()
            
            // save the starting coordinate
            _dr.previous = _dr.current
            
        case .changed:
            // update the appropriate layer
            update(_dr)
            
            // save the current (intermediate) location as the previous
            _dr.previous = _dr.current
            
        case .ended:
            // update the appropriate layer
            update(_dr)
            
            // restore the previous cursor
            NSCursor.pop()
            
        default:
            // ignore other states
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
            return view.convert(event.locationInWindow, from: nil).x >= view.frame.width - _dbLayer.width
        } else {
            // not right click, process it
            return true
        }
    }
    /// Respond to Click-Left gesture
    ///
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc func clickLeft(_ gr: NSClickGestureRecognizer) {
        
        // get the coordinates and convert to this View
        let mouseLocation = gr.location(in: view)
        
        // calculate the frequency
        let clickFrequency = (mouseLocation.x * _hzPerUnit) + CGFloat(_start)
        
        // Is there an inactive Slice at the clickFrequency
        if activateSlice(at: clickFrequency) {
            
            // YES, it is now the active Slice
            redrawSlices()
        }
    }
    /// Respond to Click-Right gesture
    ///     NOTE: will only receive events in db legend, see previous method
    ///
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc func clickRight(_ gr: NSClickGestureRecognizer) {
        
        // update the Db Legend spacings
        _dbLayer.updateLegendSpacing(gestureRecognizer: gr, in: view)
    }
    /// Redraw after a resize
    ///
    func didResize() {
        
        // after a resize, redraw display components
        redrawDbLegend()
        redrawFrequencyLegend()
        redrawSlices()
    }
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Pass the Params struct to each layer
    ///
    private func passParams() {
        
        _frequencyLayer.params = _params
        _dbLayer.params = _params
        _sliceLayer.params = _params
        _tnfLayer.params = _params
    }
    /// Setup Panadapter layer buffers & parameters
    ///
    private func setupPanadapterLayer() {
        
        // TODO: Make this a preference value
        _panadapterLayer.spectrumStyle = .line
        
        // setup buffers
        _panadapterLayer.setupBuffers()
        
        // setup the spectrum background color
        _panadapterLayer.setClearColor(Defaults[.spectrumBackground])
        
        
        // setup Uniforms
        _panadapterLayer.populateUniforms(size: view.frame.size)
        _panadapterLayer.updateUniformsBuffer()
    }
    /// Find the Slice at a frequency (if any)
    ///
    /// - Parameter freq:       the target frequency
    /// - Returns:              a slice or nil
    ///
    private func hitTestSlice(at freq: CGFloat) -> xLib6000.Slice? {
        var slice: xLib6000.Slice?
        
        for (_, s) in _radio.slices where s.panadapterId == _panadapter!.id{
            if s.frequency + s.filterLow <= Int(freq) && s.frequency + s.filterHigh >= Int(freq) {
                slice = s
                break
            }
        }
        return slice
    }
    /// Make a Slice active
    ///
    /// - Parameter freq:       the target frequency
    ///
    private func activateSlice(at freq: CGFloat) -> Bool {
        var slice: xLib6000.Slice?
        
        for (_, s) in _radio.slices where s.panadapterId == _panadapter!.id && s.frequency + s.filterLow <= Int(freq) && s.frequency + s.filterHigh >= Int(freq) {
            
            // if it isn't already active, save the Slice
            if !s.active { slice = s }
            break
        }
        // was there an inactive Slice at the frequency?
        if let slice = slice {
            
            // YES, make it active and all others inactive
            for (_, s) in _radio.slices where s.panadapterId == _panadapter!.id {
                
                s.active = ( slice == s)
            }
        }
        // indicate whether the active slice has been changed
        return slice != nil
    }
    /// Find the Tnf at or near a frequency (if any)
    ///
    /// - Parameter freq:       the target frequency
    /// - Returns:              a tnf or nil
    ///
    private func hitTestTnf(at freq: CGFloat) -> Tnf? {
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
            _frequencyLayer.redraw()
            
        case "dbLegend":
            _dbLayer.redraw()
            
        case "gridLines":
            _frequencyLayer.redraw()
            _dbLayer.redraw()
            
        case "spectrum", "tnfInactive":
            _panadapterLayer.populateUniforms(size: view.frame.size)
            _panadapterLayer.updateUniformsBuffer()
            
        case "spectrumBackground":
            _panadapterLayer.setClearColor(Defaults[.spectrumBackground])
            
        case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
            _sliceLayer.redraw()
            _frequencyLayer.redraw()
            fallthrough
            
        case #keyPath(Radio.tnfEnabled):
            fallthrough
        case "tnfInactive", "tnfNormal", "tnfDeep", "tnfVeryDeep":
            fallthrough
        case #keyPath(Tnf.frequency), #keyPath(Tnf.depth), #keyPath(Tnf.width):
            _tnfLayer.redraw()
            
        case "sliceInactive", "sliceActive", "sliceFilter":
           fallthrough            
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
            
            // YES, on this panadapter?
            if slice.panadapterId == _panadapter!.id {
                
                // YES, log the event
                _log.msg("ID = \(slice.id) on pan = \(_panadapter!.id.hex)", level: .debug, function: #function, file: #file, line: #line)
                
                // YES, add observations of this Slice
                observations(slice, paths: _sliceKeyPaths)
                
                // force a redraw
                _sliceLayer.redraw()
            }
        }
    }
    /// Process .sliceWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func sliceWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Slice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, on this panadapter?
            if slice.panadapterId == _panadapter!.id {
                
                // YES, log the event
                _log.msg("ID = \(slice.id) on pan = \(_panadapter!.id.hex)", level: .debug, function: #function, file: #file, line: #line)
                
                // YES, remove observations of this Slice
                observations(slice, paths: _sliceKeyPaths, remove: true)
                
                // force a redraw
                _sliceLayer.redraw()
            }
        }
    }
    /// Process .tnfHasBeenAdded Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc fileprivate func tnfHasBeenAdded(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? Tnf {
            
            // YES, log the event
            _log.msg("ID = \(tnf.id)", level: .debug, function: #function, file: #file, line: #line)

            // add observations of this Tnf
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
            
            // YES, log the event
            _log.msg("ID = \(tnf.id)", level: .debug, function: #function, file: #file, line: #line)

            // remove observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths, remove: true)
            
            // force a redraw
            _tnfLayer.redraw()
        }
    }
}
