//
//  WaterfallViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000
import MetalKit

class WaterfallViewController: NSViewController, NSGestureRecognizerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _waterfallView              : WaterfallView!
    fileprivate var _params                     : Params { return representedObject as! Params }
    fileprivate var _panadapter                 : Panadapter? { return _params.panadapter }
    fileprivate var _waterfall                  : Waterfall? { return _params.radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _center                     : Int { return _panadapter!.center }
    fileprivate var _bandwidth                  : Int { return _panadapter!.bandwidth }
    fileprivate var _start                      : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                        : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit                  : CGFloat { return CGFloat(_end - _start) / _panadapter!.panDimensions.width }
    
    fileprivate var _waterfallLayer             : WaterfallLayer { return _waterfallView.waterfallLayer }
    fileprivate var _timeLayer                  : TimeLayer { return _waterfallView.timeLegendLayer }

    // constants
    fileprivate let _log                        = (NSApp.delegate as! AppDelegate)
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make the view controller the delegate for the view
        _waterfallView = self.view as! WaterfallView
        _waterfallView.delegate = self

        // give each layer access to the Params struct
        passParams()
        
        // setup Waterfall Layer
        setupWaterfallLayer()
        
        // direct stream data to the waterfall layer
        _waterfall?.delegate = _waterfallLayer
        
        // begin observations (defaults & Waterfall)
        setupObservations()

        // draw each layer once
        _timeLayer.redraw()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // initialize the texture height percentage
        _waterfallLayer.heightPercent = Float(view.frame.height) / Float(WaterfallLayer.kTextureHeight)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Pass the Params struct to each layer
    ///
    private func passParams() {
        
        _waterfallLayer.params = _params
        _timeLayer.params = _params
    }
    /// Setup Waterfall layer buffers & parameters
    ///
    private func setupWaterfallLayer() {
        
        // setup state
        _waterfallLayer.setupState()
        
        // setup the spectrum background color
        _waterfallLayer.setClearColor(Defaults[.spectrumBackground])
        
        // initialize the texture height percentage
        _waterfallLayer.heightPercent = Float(view.frame.height) / Float(WaterfallLayer.kTextureHeight)

        // load the texture
        _waterfallLayer.loadTexture()
        
        // initialize the gradient levels
        _waterfallLayer.gradient.calcLevels(autoBlackEnabled: _waterfall!.autoBlackEnabled,
                                            autoBlackLevel: _waterfallLayer.autoBlackLevel,
                                            blackLevel: _waterfall!.blackLevel,
                                            colorGain: _waterfall!.colorGain)
    }
    /// start observations & Notification
    ///
    private func setupObservations() {
        
        // begin observations (defaults & waterfall)
        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
        observations(_waterfall!, paths: _waterfallKeyPaths)
        observations(_panadapter!, paths: _panadapterKeyPaths)

        // add notification subscriptions
        addNotifications()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    // force a redraw of a layer
    
    public func redrawTimeLegend() {
        _timeLayer.redraw()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Prevent the Right Click recognizer from responding when the mouse is not over the Legend
    ///
    /// - Parameters:
    ///   - gr:             the Gesture Recognizer
    ///   - event:          the Event
    /// - Returns:          True = allow, false = ignore
    ///
    func gestureRecognizer(_ gr: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        
        // is it a right click?
        if gr.action == #selector(WaterfallViewController.clickRight(_:)) {
            // YES, if not over the legend, push it up the responder chain
            return view.convert(event.locationInWindow, from: nil).x >= view.frame.width - _waterfallView.timeLegendWidth
        } else {
            // not right click, process it
            return true
        }
    }
    /// respond to Right Click gesture
    ///     NOTE: will only receive events in time legend, see previous method
    ///
    /// - Parameter gr:     the Click Gesture Recognizer
    ///
    @objc func clickRight(_ gr: NSClickGestureRecognizer) {
        
        // update the time Legend
        _timeLayer.updateLegendSpacing(gestureRecognizer: gr, in: view)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _defaultsKeyPaths = [       // Defaults keypaths to observe
        "spectrumBackground"
    ]

    fileprivate let _waterfallKeyPaths = [      // Waterfall keypaths to observe
        #keyPath(Waterfall.autoBlackEnabled),
        #keyPath(Waterfall.blackLevel),
        #keyPath(Waterfall.colorGain),
        #keyPath(Waterfall.gradientIndex),
    ]

    fileprivate let _panadapterKeyPaths = [      // Panadapter keypaths to observe
        #keyPath(Panadapter.center),
        #keyPath(Panadapter.bandwidth)
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
            
        case #keyPath(Waterfall.autoBlackEnabled), #keyPath(Waterfall.blackLevel), #keyPath(Waterfall.colorGain):
            // recalc the levels
            _waterfallLayer.gradient.calcLevels(autoBlackEnabled: _waterfall!.autoBlackEnabled, autoBlackLevel: _waterfallLayer.autoBlackLevel, blackLevel: _waterfall!.blackLevel, colorGain: _waterfall!.colorGain)
        
        case #keyPath(Waterfall.gradientIndex):
            // reload the Gradient
            _waterfallLayer.gradient.loadGradient(_waterfall!.gradientIndex)
            
        case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
            _waterfallLayer.updateNeeded = true
            
        case "spectrumBackground":
            break   // ???? what to do
            
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
        
        NC.makeObserver(self, with: #selector(waterfallWillBeRemoved(_:)), of: .waterfallWillBeRemoved, object: nil)
    }
    /// Process .waterfallWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Panadapter object?
        if let waterfall = note.object as? Waterfall {
            
            // YES, is it this panadapter's Waterfall?
            if waterfall == _waterfall! {
                
                // YES, remove Defaults property observers
                observations(Defaults, paths: _defaultsKeyPaths, remove: true)
                
                // remove Waterfall property observers
                observations(waterfall, paths: _waterfallKeyPaths, remove: true)
                
                // remove Panadapter property observers
                observations(_panadapter!, paths: _panadapterKeyPaths, remove: true)
            }
        }
    }
}

