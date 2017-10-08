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
    
    fileprivate var _waterfallView      : WaterfallView!
    fileprivate var _params             : Params { return representedObject as! Params }
    fileprivate var _panadapter         : Panadapter? { return _params.panadapter }
    fileprivate var _waterfall          : Waterfall? { return _params.radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _center             : Int { return _panadapter!.center }
    fileprivate var _bandwidth          : Int { return _panadapter!.bandwidth }
    fileprivate var _start              : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit          : CGFloat { return CGFloat(_end - _start) / _panadapter!.panDimensions.width }
    
    fileprivate var _waterfallLayer     : WaterfallLayer { return _waterfallView.waterfallLayer }
    fileprivate var _timeLegendLayer    : TimeLegendLayer { return _waterfallView.timeLegendLayer }

    // constants
    fileprivate let _log                = (NSApp.delegate as! AppDelegate)
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make the view controller the delegate for the view
        _waterfallView = self.view as! WaterfallView
        _waterfallView.delegate = self
   }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    
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

    
    /// Prevent the Right Click recognizer from responding when the mouse is not over the Legend
    ///
    /// - Parameters:
    ///   - gr: the Gesture Recognizer
    ///   - event: the Event
    /// - Returns: True = allow, false = ignore
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
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc func clickRight(_ gr: NSClickGestureRecognizer) {
        
        // update the time Legend
        _timeLegendLayer.updateLegendSpacing(gestureRecognizer: gr, in: view)
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

