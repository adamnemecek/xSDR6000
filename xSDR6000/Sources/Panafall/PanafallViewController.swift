//
//  PanafallViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/14/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Panafall View Controller class implementation
// --------------------------------------------------------------------------------

final class PanafallViewController: NSSplitViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet weak var _panadapterSplitViewItem: NSSplitViewItem!    

    fileprivate var _params: Params { return representedObject as! Params }

    fileprivate var _radio: Radio { return _params.radio }
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
//    fileprivate var _waterfall: Waterfall? { return _params.waterfall }

    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / view.frame.width }
    
    fileprivate var _panadapterViewController: PanadapterViewController? { return _panadapterSplitViewItem.viewController as? PanadapterViewController }
//    fileprivate var _panadapterView: PanadapterView? { return (_panadapterViewController?.view as? PanadapterView) }
    
    // gesture recognizer related
    fileprivate var _doubleClick: NSClickGestureRecognizer!
    fileprivate var _rightClick: NSClickGestureRecognizer!
    fileprivate var _panLeftButton: NSPanGestureRecognizer!
    fileprivate var _panRightButton: NSPanGestureRecognizer!
    fileprivate var _panStart: NSPoint?
    fileprivate var _previousCursor: NSCursor?

    fileprivate var _notifications = [NSObjectProtocol]()
    fileprivate var _myContext = 0
    
    
    

    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)
    fileprivate let kButtonViewWidth: CGFloat = 75          // Width of ButtonView when open
    fileprivate let kEdgeTolerance = 10                     // percent of bandwidth
    fileprivate let kLeftButton = 0x01                      // masks for Gesture Recognizers
    fileprivate let kRightButton = 0x02
    
    fileprivate let kCreateSlice = "Create Slice"           // Menu titles
    fileprivate let kRemoveSlice = "Remove Slice"
    fileprivate let kCreateTnf = "Create Tnf"
    fileprivate let kRemoveTnf = "Remove Tnf"
    fileprivate let kPermanentTnf = "Permanent"
    fileprivate let kNormalTnf = "Normal"
    fileprivate let kDeepTnf = "Deep"
    fileprivate let kVeryDeepTnf = "Very Deep"
    

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
                
        splitView.delegate = self
        
        // setup Left Double Click recognizer
        _doubleClick = NSClickGestureRecognizer(target: self, action: #selector(leftDoubleClick(_:)))
        _doubleClick.buttonMask = kLeftButton
        _doubleClick.numberOfClicksRequired = 2
        splitView.addGestureRecognizer(_doubleClick)
        
        // setup Right Single Click recognizer
        _rightClick = NSClickGestureRecognizer(target: self, action: #selector(rightClick(_:)))
        _rightClick.buttonMask = kRightButton
        _rightClick.numberOfClicksRequired = 1
        splitView.addGestureRecognizer(_rightClick)
    }
    /// Process scroll wheel events to change the Active Slice frequency
    ///
    /// - Parameter theEvent: a Scroll Wheel event
    ///
    override func scrollWheel(with theEvent: NSEvent) {
        
        // ignore events not in the Y direction
        if theEvent.deltaY != 0 {
            
            // find the Active Slice
            if let slice = _panadapter!.radio!.findActiveSliceOn(_panadapter!.id) {
                
                // Increase or Decrease?
                let incr = theEvent.deltaY < 0 ? slice.step : -slice.step
                
                // update the frequency
                adjustSliceFrequency(slice, incr: incr)
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Redraw the FrequencyLegend
    ///
    func redrawFrequencyLegend() {
        
//        _panadapterViewController?.redrawFrequencyLegend()
    }
    /// Redraw the DbLegend
    ///
    func redrawDbLegend() {
        
//        _panadapterViewController?.redrawDbLegend()
    }
    /// Redraw the Slice
    ///
    func redrawSlices() {
        
//        _panadapterViewController?.redrawSlices()
    }
    /// Redraw all of the components
    ///
    public func redrawAll() {
        
        // redraw
//        _panadapterViewController?.redrawAll()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Respond to Left Double Click gesture
    ///
    /// - Parameter gr: the GestureRecognizer
    ///
    @objc fileprivate func leftDoubleClick(_ gr: NSClickGestureRecognizer) {
        
        // get the coordinates and convert to this View
        let mouseLocation = gr.location(in: splitView)
        
        // calculate the frequency
        let mouseFrequency = Int(mouseLocation.x * _hzPerUnit) + _start
        
        // is the click "in a Slice"?
        if let slice = _radio.findSliceOn(_panadapter!.id, byFrequency: mouseFrequency, panafallBandwidth: _bandwidth) {
            
            // YES, make the Slice active
            slice.active = true
//            _panadapterView?.redrawSliceLayer(slice)
            
        } else if let slice = _radio.findActiveSliceOn(_panadapter!.id) {
            
            // move the Slice
            slice.frequency = mouseFrequency
//            _panadapterView?.redrawSliceLayer(slice)
        }
    }
    /// Respond to a Right Click gesture
    ///
    /// - Parameter gr: the GestureRecognizer
    ///
    @objc fileprivate func rightClick(_ gr: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        
        // get the "click" coordinates and convert to this View
        let mouseLocation = gr.location(in: splitView)
        
        // create the popup menu
        let menu = NSMenu(title: "Panadapter")
        
        // calculate the frequency
        let mouseFrequency = Int(mouseLocation.x * _hzPerUnit) + _start
        
        // is the Frequency inside a Slice?
        let slice = _radio.findSliceOn(_panadapter!.id, byFrequency: mouseFrequency, panafallBandwidth: _bandwidth)
        if let slice = slice {
            
            // YES, mouse is in a Slice
            item = menu.insertItem(withTitle: kRemoveSlice, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 0)
            item.representedObject = slice
            item.target = self
            
        } else {
            
            // NO, mouse is not in a Slice
            item = menu.insertItem(withTitle: kCreateSlice, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 0)
            item.representedObject = NSNumber(value: mouseFrequency)
            item.target = self
        }
        
        // is the Frequency inside a Tnf?
        let tnf = _radio.findTnfBy(frequency: mouseFrequency, panafallBandwidth: _bandwidth)
        if let tnf = tnf {
            
            // YES, mouse is in a TNF
            item = menu.insertItem(withTitle: kRemoveTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 1)
            item.representedObject = tnf
            item.target = self
            
            menu.insertItem(NSMenuItem.separator(), at: 2)
            item = menu.insertItem(withTitle: kPermanentTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 3)
            item.state = tnf.permanent ? NSOnState : NSOffState
            item.representedObject = tnf
            item.target = self
            
            item = menu.insertItem(withTitle: kNormalTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 4)
            item.state = (tnf.depth == Tnf.Depth.normal.rawValue) ? NSOnState : NSOffState
            item.representedObject = tnf
            item.target = self
            
            item = menu.insertItem(withTitle: kDeepTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 5)
            item.state = (tnf.depth == Tnf.Depth.deep.rawValue) ? NSOnState : NSOffState
            item.representedObject = tnf
            item.target = self
            
            item = menu.insertItem(withTitle: kVeryDeepTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 6)
            item.state = (tnf.depth == Tnf.Depth.veryDeep.rawValue) ? NSOnState : NSOffState
            item.representedObject = tnf
            item.target = self
            
        } else {
            
            // NO, mouse is not in a TNF
            item = menu.insertItem(withTitle: kCreateTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: 1)
            item.representedObject = NSNumber(value: Float(mouseFrequency))
            item.target = self
        }
        
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: mouseLocation, in: splitView)
        
    }
    /// Perform the appropriate action
    ///
    /// - Parameter sender: a MenuItem
    ///
    @objc fileprivate func contextMenu(_ sender: NSMenuItem) {
        
        switch sender.title {
            
        case kCreateSlice:        // tell the Radio to create a new Slice
            let freq = (sender.representedObject! as! NSNumber).intValue
            _radio.sliceCreate(panadapter: _panadapter!, frequency: freq)
            
        case kRemoveSlice:        // tell the Radio to remove the Slice
            _radio.sliceRemove((sender.representedObject as! xLib6000.Slice).id)
            
        case kCreateTnf:          // tell the Radio to create a new Tnf
            let freq = (sender.representedObject! as! NSNumber).intValue
            _radio.tnfCreate(frequency: freq, panadapter: _panadapter!)
            
        case kRemoveTnf:          // tell the Radio to remove the Tnf
            _radio.tnfRemove(tnf: sender.representedObject as! Tnf)
            
        case kPermanentTnf:           // update the Tnf
            (sender.representedObject as! Tnf).permanent = !(sender.representedObject as! Tnf).permanent
            
        case kNormalTnf:              // update the Tnf
            (sender.representedObject as! Tnf).depth = Tnf.Depth.normal.rawValue
            
        case kDeepTnf:                // update the Tnf
            (sender.representedObject as! Tnf).depth = Tnf.Depth.deep.rawValue
            
        case kVeryDeepTnf:           // update the Tnf
            (sender.representedObject as! Tnf).depth = Tnf.Depth.veryDeep.rawValue
            
        default:
            break
        }
    }
    /// Incr/decr the Slice frequency (scroll panafall at edges)
    ///
    /// - Parameters:
    ///   - slice: the Slice
    ///   - incr: frequency step
    ///
    fileprivate func adjustSliceFrequency(_ slice: xLib6000.Slice, incr: Int) {
        
        // moving Up in frequency?
        let isUp = (incr > 0)
        
        // calculate the edge and the delta to it
        let edge = (isUp ? _center + _bandwidth/2 : _center - _bandwidth/2)
        let delta = (isUp ? edge - slice.frequency : slice.frequency - edge)
        
        // is the delta too close to the edge?
        if delta <= _bandwidth / kEdgeTolerance {
            
            Swift.print("BEFORE slice = \(slice.frequency), center = \(_panadapter!.center), incr = \(incr)")

            // YES, adjust the panafall center frequency (scroll the Panafall)
            _panadapter!.center += incr

//            _panadapterView?.redrawFrequencyLegendLayer()
            
            // adjust the slice frequency (move the Slice)
            slice.frequency = slice.frequency + incr
            
            Swift.print("AFTER  slice = \(slice.frequency), center = \(_panadapter!.center), incr = \(incr)\n")

            // redraw all the slices
//            _panadapterView?.redrawSliceLayers()
            
        } else {
            
            // NO, adjust the slice frequency (move the Slice)
            slice.frequency = slice.frequency + incr
            
            // redraw the slice
//            _panadapterView?.redrawSliceLayer(slice)
        }
        
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    // ----------------------------------------------------------------------------
    // MARK: - NSSplitViewDelegate methods
    
    /// Process NSSplitViewDidResizeSubviews Notifications
    ///
    /// - Parameter notification: a Notification instance
    ///
    override func splitViewDidResizeSubviews(_ notification: Notification) {

        // force a redraw
//        _panadapterView?.redrawAllLayers()
    }
}
