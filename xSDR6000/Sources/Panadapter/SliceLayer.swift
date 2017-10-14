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
    var lineColor                       = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.2)
    
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

    fileprivate let kMultiplier         : CGFloat = 0.001

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
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

    // ----------------------------------------------------------------------------
    // MARK: - CALayerDelegate methods
    
    /// Draw Layers
    ///
    /// - Parameters:
    ///   - layer:      a CALayer
    ///   - ctx:        context
    ///
    public func drawLayer(in ctx: CGContext) {

        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        // for each Slice
        for (_, slice) in _radio.slices {
            
            // is it on this panadapter?
            if slice.frequency >= _start && slice.frequency <= _end {
                
                // YES, calculate the position & width
                let slicePosition = CGFloat(slice.frequency + slice.filterLow - _start) / _hzPerUnit
                let sliceWidth = CGFloat( -slice.filterLow + slice.filterHigh ) / _hzPerUnit
                
                // get the color
                let color = Defaults[.sliceFilter]
                
                // calculate the rectangle
                let rect = NSRect(x: slicePosition, y: 0, width: sliceWidth, height: frame.height)
                
                // draw the rectangle
                _path.fillRect( rect, withColor: color, andAlpha: Defaults[.sliceFilterOpacity])
            }
        }
        _path.strokeRemove()
        
        // set the active slice color
        Defaults[.sliceActive].set()
        
        // for each active Slice
        for (_, slice) in _radio.slices where slice.active {
            
            // is it on this panadapter?
            if slice.frequency >= _start && slice.frequency <= _end {

                // YES, calculate the line position
                let sliceFrequencyPosition = CGFloat(slice.frequency - _start) / _hzPerUnit

                // draw the line
                _path.vLine(at: sliceFrequencyPosition, fromY: 0, toY: frame.height)
            }
        }
        _path.strokeRemove()

        // set the inactive slice color
        Defaults[.sliceInactive].set()
        
        // for each inactive Slice
        for (_, slice) in _radio.slices where !slice.active {
            
            // is it on this panadapter?
            if slice.frequency >= _start && slice.frequency <= _end{
                
                // YES, calculate the line position
                let sliceFrequencyPosition = CGFloat(slice.frequency - _start) / _hzPerUnit
                
                // draw the line
                _path.vLine(at: sliceFrequencyPosition, fromY: 0, toY: frame.height)
            }
        }
        _path.strokeRemove()

        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
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
}


