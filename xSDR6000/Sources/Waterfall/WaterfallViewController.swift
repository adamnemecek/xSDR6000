//
//  WaterfallViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/13/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Waterfall View Controller class implementation
// --------------------------------------------------------------------------------

final class WaterfallViewController : NSViewController, NSGestureRecognizerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet fileprivate var _waterfallView: WaterfallView!
    
    fileprivate var _params: Params { return representedObject as! Params }

    // gesture recognizer related
    fileprivate var _rightClick: NSClickGestureRecognizer!
    fileprivate var _panLeftButton: NSPanGestureRecognizer!
    fileprivate var _panRightButton: NSPanGestureRecognizer!
    fileprivate var _panStart: NSPoint?
    fileprivate var _panSlice: xLib6000.Slice?
    fileprivate var _panTnf: xLib6000.Tnf?
    fileprivate var _dbmTop = false
    fileprivate var _newCursor: NSCursor?
    fileprivate var _timeLegendSpacings = [String]()        // Time legend spacing choices

    //constants
    fileprivate let kModule = "WaterfallViewController"     // Module Name reported in log messages
    fileprivate let _timeLegendWidth: CGFloat = 40          // width of Time Legend layer
    fileprivate let kLeftButton = 0x01                      // button masks
    fileprivate let kRightButton = 0x02
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // give the WaterfallView a reference to the Params
        _waterfallView.params = _params

        // get the list of possible spacings
        _timeLegendSpacings = Defaults[.timeLegendSpacings]
        
        // setup gestures, Right Click
        _rightClick = NSClickGestureRecognizer(target: self, action: #selector(rightClick(_:)))
        _rightClick.buttonMask = kRightButton
        _rightClick.delegate = self
        _waterfallView.addGestureRecognizer(_rightClick)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    // ----------------------------------------------------------------------------
    // MARK: - NSGestureRecognizer Delegate methods

    /// Prevent the Right Click recognizer from responding when the mouse is not over the Legend
    ///
    /// - Parameters:
    ///   - gr: the Gesture Recognizer
    ///   - event: the Event
    /// - Returns: True = allow, false = ignore
    ///
    func gestureRecognizer(_ gr: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        
        return _waterfallView.convert(event.locationInWindow, from: nil).x >= _waterfallView.frame.width - _timeLegendWidth
    }
    /// respond to Right Click gesture when over the DbLegend
    ///
    /// - Parameter gr: the Click Gesture Recognizer
    ///
    @objc fileprivate func rightClick(_ gr: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        
        // get the "click" coordinates and convert to this View
        let location = gr.location(in: _waterfallView)
        
        // create the popup menu
        let menu = NSMenu(title: "TimeLegendSpacings")
        
        // populate the popup menu of Spacings
        for i in 0..<_timeLegendSpacings.count {
            item = menu.insertItem(withTitle: "\(_timeLegendSpacings[i]) sec", action: #selector(timeLegendSpacing(_:)), keyEquivalent: "", at: i)
            item.tag = Int(_timeLegendSpacings[i]) ?? 0
            item.target = self
        }
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: location, in: _waterfallView)
    }
    /// respond to the Context Menu selection
    ///
    /// - Parameter sender: the Context Menu
    ///
    @objc fileprivate func timeLegendSpacing(_ sender: NSMenuItem) {
        
        // set the Db Legend spacing
        Defaults[.timeLegendSpacing] = String(sender.tag)
        
        // force a redraw
//        _waterfallView.redrawLegend()
    }

}
