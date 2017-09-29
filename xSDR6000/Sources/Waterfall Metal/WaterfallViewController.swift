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

class WaterfallViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet weak var _waterfallView: MTKView!
    @IBOutlet weak var _timeLegendView: PanadapterDbLegend!
    
    fileprivate var _params: Params { return representedObject as! Params }
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
    fileprivate var _waterfall: Waterfall? { return _params.radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _center: Int { return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / _panadapter!.panDimensions.width }
    
//    fileprivate var _renderer: WaterfallRenderer!

    fileprivate var _panLeft: NSPanGestureRecognizer!
    fileprivate var _xStart: CGFloat = 0
    fileprivate var _newCursor: NSCursor?
    fileprivate let kLeftButton = 0x01                              // button masks

    // constants
    fileprivate let _log                    = (NSApp.delegate as! AppDelegate)
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        _waterfallView.device = MTLCreateSystemDefaultDevice()
//
//        guard _waterfallView.device != nil else {
//            fatalError("Metal is not supported on this device")
//        }
//
//        _renderer = WaterfallRenderer(mtkView: _waterfallView)
//
//        guard _renderer != nil else {
//            fatalError("Renderer failed initialization")
//        }
//
//        _waterfallView.delegate = _renderer
//
//        _waterfall?.delegate = _renderer
//
//        // begin observing Defaults
//        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
//
//        // add notification subscriptions
//        addNotifications()
//
//        // Pan (Left Button)
//        _panLeft = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
//        _panLeft.buttonMask = kLeftButton
//        view.addGestureRecognizer(_panLeft)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeft(_ gr: NSPanGestureRecognizer) {
        
        // update panadapter center
        func update(_ xStart: CGFloat, _ xCurrent: CGFloat) {
            let xDelta = xCurrent - xStart
            
            // adjust the center
            _panadapter!.center = _panadapter!.center - Int(xDelta * _hzPerUnit)
            
//            // redraw the frequency legend
//            _frequencyLegendView.redraw()
        }
        
        let xCurrent = gr.location(in: view).x
        
        switch gr.state {
        case .began:
            // save the start location
            _xStart = xCurrent
            
            // set the cursor
            _newCursor = NSCursor.resizeLeftRight()
            _newCursor!.push()
            
        case .changed:
            // update the panadapter params
            update(_xStart, xCurrent)
            
            // use the current (intermediate) location as the start
            _xStart = xCurrent
            
        case .ended:
            // update the panadapter params
            update(_xStart, xCurrent)
            
            // restore the cursor
            _newCursor!.pop()
            
        default:
            break
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Force a redraw
    ///
    func redraw() {
        DispatchQueue.main.async {
            
            // force a redraw
            self.view.needsDisplay = true            
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _defaultsKeyPaths = [               // Defaults keypaths to observe
        "gridLines",
        "spectrum",
        "spectrumBackground",
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
    ///   - keyPath:        the registered KeyPath
    ///   - object:         object containing the KeyPath
    ///   - change:         dictionary of values
    ///   - context:        context (if any)
    ///
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
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
            
            // YES, is it this panadapter
            if waterfall == _waterfall! {
                
                // YES, remove Defaults property observers
                observations(Defaults, paths: _defaultsKeyPaths, remove: true)
            }
        }
    }
}

