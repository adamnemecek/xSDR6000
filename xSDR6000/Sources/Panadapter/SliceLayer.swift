//
//  SLiceLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/1/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

public final class SliceLayer: CALayer {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params                          : Params!           // Radio & Panadapter references
    var triangleSize                    : CGFloat = 15.0
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio              : Radio { return params.radio }
    fileprivate var _panadapter         : Panadapter? { return params.panadapter }
    
    fileprivate var _center             : Int {return _panadapter!.center }
    fileprivate var _bandwidth          : Int { return _panadapter!.bandwidth }
    fileprivate var _start              : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit          : CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _path               = NSBezierPath()
    fileprivate var _sliceFlags         : [SliceId: FlagViewController] = [:]

    fileprivate let kMultiplier         : CGFloat = 0.001

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Draw Layer
    ///
    /// - Parameter ctx:        a CG context
    ///
    public func drawLayer(in ctx: CGContext) {
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        drawFilterOutlines()
        
        drawActiveSlice()
        
        drawInactiveSlices()
        
        drawFlags()
        
        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
    /// Process a drag
    ///
    /// - Parameter dr:         the draggable
    ///
    func updateSlice(dragable dr: PanadapterViewController.Dragable) {

        // calculate offsets in x & y
        let deltaX = dr.current.x - dr.previous.x
        let deltaY = dr.current.y - dr.previous.y
        
        // is there a slice object?
        if let slice = dr.object as? xLib6000.Slice {
            
            // YES, drag or resize?
            if abs(deltaX) > abs(deltaY) {
                
                // drag
                slice.frequency += Int(deltaX * _hzPerUnit)
            
            } else {
                
                // resize
                slice.filterLow -= Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
                slice.filterHigh += Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
            }
        }
        // redraw the slices
        redraw()
    }
    /// Force the layer to be redrawn
    ///
    func redraw() {
        // interact with the UI
        DispatchQueue.main.async {
            // force a redraw
            self.setNeedsDisplay()
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Draw the outline of a SLice filter
    ///
    fileprivate func drawFilterOutlines() {
        
        // draw the filter outline(s)
        for (_, slice) in _radio.slices where slice.panadapterId == _panadapter!.id {
            
            // is it inside the bandwidth?
            if slice.frequency >= _start && slice.frequency <= _end {
                
                // YES, calculate the position & width
                let slicePosition = CGFloat(slice.frequency + slice.filterLow - _start) / _hzPerUnit
                let sliceWidth = CGFloat( -slice.filterLow + slice.filterHigh ) / _hzPerUnit
                
                // calculate the rectangle
                let rect = NSRect(x: slicePosition, y: 0, width: sliceWidth, height: frame.height)
                
                // draw the rectangle
                _path.fillRect( rect, withColor: Defaults[.sliceFilter])
            }
        }
        _path.strokeRemove()
    }
    /// Draw the frequency line of the active Slice
    ///
    fileprivate func drawActiveSlice() {
        // set the active slice color
        Defaults[.sliceActive].set()
        
        // draw the active frequency line
        for (_, slice) in _radio.slices where slice.panadapterId == _panadapter!.id && slice.active {
            
            // is it on this panadapter?
            if slice.frequency >= _start && slice.frequency <= _end {
                
                // YES, calculate the line position
                let sliceFrequencyPosition = CGFloat(slice.frequency - _start) / _hzPerUnit
                
                // draw the line
                _path.vLine(at: sliceFrequencyPosition, fromY: 0, toY: frame.height)
                
                // draw the triangle at the top
                _path.drawTriangle(at: sliceFrequencyPosition, topWidth: triangleSize, triangleHeight: triangleSize, topPosition: frame.height)
            }
        }
        _path.strokeRemove()
    }
    /// Draw the frequency line(s) of the inactive Slice(s)
    ///
    fileprivate func drawInactiveSlices() {
        // set the inactive slice color
        Defaults[.sliceInactive].set()
        
        // draw the inactive frequency line(s)
        for (_, slice) in _radio.slices where slice.panadapterId == _panadapter!.id && !slice.active {
            
            // is it on this panadapter?
            if slice.frequency >= _start && slice.frequency <= _end{
                
                // YES, calculate the line position
                let sliceFrequencyPosition = CGFloat(slice.frequency - _start) / _hzPerUnit
                
                // draw the line
                _path.vLine(at: sliceFrequencyPosition, fromY: 0, toY: frame.height)
            }
        }
        _path.strokeRemove()
    }
    /// Create or redraw Slice flags
    ///
    fileprivate func drawFlags() {
        
        for (_, slice) in _radio.slices {
            
            // is there a Flag for this Slice?
            if _sliceFlags[slice.id] == nil {
                
                // NO, create one
                _sliceFlags[slice.id] = (delegate as! PanadapterView).createFlagView()
                _sliceFlags[slice.id]!.slice = slice
                
                (delegate as! PanadapterView).addSubview(_sliceFlags[slice.id]!.view)
            }
            let flagVc = _sliceFlags[slice.id]!
            
            // calculate the Flag position
            let flagWidth = flagVc.view.frame.width
            let flagHeight = flagVc.view.frame.height - (delegate as! PanadapterView).frequencyLegendHeight
            let flagPositionX = (CGFloat(slice.frequency - _start) / _hzPerUnit) - flagWidth
            let flagPositionY = frame.height - flagHeight
            flagVc.flagPosition = NSPoint(x: flagPositionX, y: flagPositionY)
            
            // YES, reposition it
            flagVc.reposition()
        }
    }
}


