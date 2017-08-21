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

    @IBOutlet fileprivate var panadapterView: PanadapterView!
    
    fileprivate var _params: Params { return representedObject as! Params }

    fileprivate var _panadapter: Panadapter? { return _params.panadapter }

    fileprivate var _start: Int { return _panadapter!.center - (_panadapter!.bandwidth/2) }
    fileprivate var _end: Int  { return _panadapter!.center + (_panadapter!.bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / view.frame.width }

    // gesture recognizer related
    fileprivate var _rightClick: NSClickGestureRecognizer!
    fileprivate var _panLeftButton: NSPanGestureRecognizer!
    fileprivate var _panRightButton: NSPanGestureRecognizer!
    fileprivate var _panStart: NSPoint?
    fileprivate var _panSlice: xLib6000.Slice?
    fileprivate var _panTnf: xLib6000.Tnf?
    fileprivate var _dbmTop = false
    fileprivate var _newCursor: NSCursor?
    fileprivate var _dbLegendSpacings = [String]()          // Db spacing choices

    // constants
    fileprivate let _dbLegendWidth: CGFloat = 40            // width of Db Legend layer
    fileprivate let _log = (NSApp.delegate as! AppDelegate)

    fileprivate let kLeftButton = 0x01                      // button masks
    fileprivate let kRightButton = 0x02
    fileprivate let kEdgeTolerance = 10                     // percent of bandwidth

    fileprivate let kPanafallStoryboard = "Panafall"        // Storyboard names
    fileprivate let kFlagIdentifier = "Flag"                // Storyboard identifiers

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
 
        // give the PanadapterView a reference to the Params
        panadapterView.params = _params
        
        // get the list of possible spacings
        _dbLegendSpacings = Defaults[.dbLegendSpacings]
        
        // setup gestures, Right Click
        _rightClick = NSClickGestureRecognizer(target: self, action: #selector(rightClick(_:)))
        _rightClick.buttonMask = kRightButton
        _rightClick.delegate = self
        panadapterView.addGestureRecognizer(_rightClick)
        
        // Pan (Left Button)
        _panLeftButton = NSPanGestureRecognizer(target: self, action: #selector(panLeftButton(_:)))
        _panLeftButton.buttonMask = kLeftButton
        panadapterView.addGestureRecognizer(_panLeftButton)
        
//        // Pan (Right Button)
//        _panRightButton = NSPanGestureRecognizer(target: self, action: #selector(panRightButton(_:)))
//        _panRightButton.buttonMask = kRightButton
//        panadapterView.addGestureRecognizer(_panRightButton)
        
//        // get the Storyboard containing a Flag View Controller
//        let sb = NSStoryboard(name: kPanafallStoryboard, bundle: nil)
        
//        // create a Flag View Controller
//        let flagVc = sb.instantiateController(withIdentifier: self.kFlagIdentifier) as! NSViewController
        
//        // add the Flag to the view
//        addChildViewController(flagVc)
        
//        panadapterView.addSubview(flagVc.view)
//        
//        flagVc.view.centerXAnchor.constraint(equalTo: panadapterView.centerXAnchor).isActive = true
//        flagVc.view.centerYAnchor.constraint(equalTo: panadapterView.centerYAnchor).isActive = true
        
//        print("flag \(flagVc.view) @ \(flagVc.view.frame)")
//        print("subviews = \(panadapterView.subviews)")
        
        
    }
    /// View did layout
    ///
    override func viewDidLayout() {
        
        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: view.frame.width, height: view.frame.height - panadapterView.frequencyLegendHeight)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Redraw the FrequencyLegend
    ///
    public func redrawFrequencyLegend() {
        
        // force a redraw of theFrequencyLegend layer
        panadapterView?.redrawFrequencyLegendLayer()
    }
    /// Redraw the DbLegend
    ///
    public func redrawDbLegend() {
        
        // force a redraw of DbLegend layer
        panadapterView?.redrawDbLegendLayer()
    }
    /// Redraw a Slice
    ///
    public func redrawSlice(_ slice: xLib6000.Slice) {
        
        // force a redraw of a Slice layer
        panadapterView?.redrawSliceLayer(slice)
    }
    /// Redraw the Slice(s)
    ///
    public func redrawSlices() {
        
        // force a redraw of all the Slice layers
        panadapterView?.redrawSliceLayers()
    }
    /// Redraw all of the components
    ///
    public func redrawAll() {
        
        // force a redraw of all layers
        panadapterView?.redrawAllLayers()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// respond to the Context Menu selection
    ///
    /// - Parameter sender: the Context Menu
    ///
    @objc fileprivate func dbLegendSpacing(_ sender: NSMenuItem) {
        
        // set the Db Legend spacing
        Defaults[.dbLegendSpacing] = String(sender.tag, radix: 10)
        
        // force a redraw
//        panadapterView.redrawDbLegendLayer()
    }
    /// Incr/decr the Slice frequency (scroll Panafall at edges)
    ///
    /// - Parameters:
    ///   - slice: the Slice
    ///   - incr: frequency step
    ///
//    fileprivate func adjustSliceFrequency(_ slice: xLib6000.Slice, incr: Int) {
//        
//        // moving Up in frequency?
//        let isUp = (incr > 0)
//        
//        // calculate the edge and the delta to it
//        let edge = (isUp ? _panadapter.center + _panadapter.bandwidth/2 : _panadapter.center - _panadapter.bandwidth/2)
//        let delta = (isUp ? edge - slice.frequency : slice.frequency - edge)
//        
//        // is the delta too close to the edge?
//        if delta <= _panadapter.bandwidth / kEdgeTolerance {
//            
//            // YES, adjust the Panadapter center frequency (scroll the Panafall)
//            _panadapter.center += incr
//
//        } else {
//            
//            // NO, adjust the slice frequency (move the Slice)
//            slice.frequency += incr
//            
//            redrawSlice(slice)
//        }
//    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
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
        
        return panadapterView.convert(event.locationInWindow, from: nil).x >= panadapterView.frame.width - _dbLegendWidth
    }    
    /// respond to Right Click gesture when over the DbLegend
    ///
    /// - Parameter gr: the Click Gesture Recognizer
    ///
    @objc fileprivate func rightClick(_ gr: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        
        // get the "click" coordinates and convert to this View
        let location = gr.location(in: panadapterView)
        
        // create the popup menu
        let menu = NSMenu(title: "DbLegendSpacings")
        
        // populate the popup menu of Spacings
        for i in 0..<_dbLegendSpacings.count {
            item = menu.insertItem(withTitle: "\(_dbLegendSpacings[i]) dbm", action: #selector(dbLegendSpacing(_:)), keyEquivalent: "", at: i)
            item.tag = Int(_dbLegendSpacings[i]) ?? 0
            item.target = self
        }
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: location, in: panadapterView)
    }
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr: the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeftButton(_ gr: NSPanGestureRecognizer) {
        
        let location = gr.location(in: panadapterView)
        
        switch gr.state {
            
        case .began:
            
            // save the start location
            _panStart = location
            
            if location.x > panadapterView.frame.width - _dbLegendWidth {
                
                _newCursor = NSCursor.resizeUpDown()
                
                // top or bottom?
                _dbmTop = (location.y > panadapterView.frame.height/2)
                
            } else {
                
                _newCursor = NSCursor.resizeLeftRight()
            }
            _newCursor!.push()
            
        case .changed:
            
            // Up/Down   or   Left/Right ?
            if NSCursor.current() == NSCursor.resizeUpDown() {
                
                // Up/Down, update the dbM Legend
                if _dbmTop {
                    
                    _panadapter!.maxDbm += (_panStart!.y - location.y)
                    
                } else {
                    
                    _panadapter!.minDbm += (_panStart!.y - location.y)
                }
                // only rn|0| is returned for dbm changes so must refresh
                // redraw the changed components
                redrawDbLegend()

            } else {
                
                // Left/Right, update the panafall center
                _panadapter!.center += Int( (_panStart!.x - location.x) * _hzPerUnit )
                redrawFrequencyLegend()
            }

            // use the current (intermediate) location as the start
            _panStart = location
            
            
        case .ended:
            
            if NSCursor.current() == NSCursor.resizeUpDown() {
                
                // Up/Down, update the dbM Legend
                if _dbmTop {
                    
                    _panadapter!.maxDbm += (_panStart!.y - location.y)
                    
                } else {
                    
                    _panadapter!.minDbm += (_panStart!.y - location.y)
                }
                // redraw the changed components
                redrawDbLegend()
                
            } else {
                
                // Left/Right, update the panafall center
                _panadapter!.center += Int( (_panStart!.x - location.x) * _hzPerUnit )
                redrawFrequencyLegend()
            }
            _newCursor!.pop()
            
        default:
            break
        }
    }
    /// Respond to Pan gesture (right mouse down)
    ///     TNF:
    ///         Up / Down movement:     increase / decrease the Tnf width
    ///         Right / Left movement:  lower / raise the Tnf frequency
    ///
    ///     SLICE:
    ///         Right / Left movement:  lower / raise the Slice frequency
    ///
    /// - Parameter gr: the Pan Gesture Recognizer
    ///
//    @objc fileprivate func panRightButton(_ gr: NSPanGestureRecognizer) {
//        
//        // common routine for position update
//        func updatePosition(_ location: NSPoint) {
//            
//            // calculate the offset
//            let xOffset = Int( floor((location.x - _panStart!.x) * _hzPerUnit) )
//            let yOffset = Int( floor((location.y - _panStart!.y) * _hzPerUnit) )
//            
//            // what are we panning?
//            if let tnf = _panTnf {
//                
//                // TNF, frequency or width?
//                if yOffset != 0 {
//                    
//                    // width (widen the Thf)
//                    tnf.width += yOffset
//                    
//                } else {
//                    
//                    // frequency (move the Tnf)
//                    tnf.frequency += xOffset
//                }
//                
//            } else {
//                
//                // Slice, adjust the Slice frequency
//                if let slice = _panSlice { adjustSliceFrequency(slice, incr: xOffset) }
//                
//                
//            }
//        }
//        
//        // get the mouse location
//        let location = gr.location(in: panadapterView)
//        
//        // identify the state
//        switch gr.state {
//            
//        case .began:
//            
//            // save the start location
//            _panStart = location                    // save the start location
//            
//            // calculate the frequency
//            let frequency = Int(location.x * _hzPerUnit) + _start
//            
//            // where is the click?
//            if let tnf = _radio.findTnfBy(frequency: frequency, panafallBandwidth: _panadapter.bandwidth) {
//                
//                // in a Tnf
//                _panTnf = tnf
//                
//                _newCursor = NSCursor.crosshair()
//                
//            } else if let slice = _radio.findSliceOn(_panadapter.id, byFrequency: frequency, panafallBandwidth: _panadapter.bandwidth) {
//                
//                // in a Slice
//                _panSlice = slice
//                
//                _newCursor = NSCursor.resizeLeftRight()
//                
//            } else {
//                
//                // in an open part of the Panadapter (use the Active Slice)
//                _panSlice = _radio.findActiveSliceOn(_panadapterId)
//                
//                _newCursor = NSCursor.closedHand()
//            }
//            _newCursor!.push()
//            
//        case .changed:
//            
//            updatePosition(location)
//            
//            // use the current (intermediate) location as the start
//            _panStart = location
//            
//        case .ended:
//            
//            updatePosition(location)
//            
//            _newCursor!.pop()
//            _panStart = nil
//            _panTnf = nil
//            _panSlice = nil
//            
//        default:
//            break
//        }
//    }

}
