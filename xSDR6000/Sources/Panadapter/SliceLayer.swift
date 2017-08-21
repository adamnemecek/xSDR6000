//
//  SliceLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Slice Layer class implementation
// --------------------------------------------------------------------------------

class SliceLayer: CALayer, CALayerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var slice: xLib6000.Slice!
    var params: Params!                                             // Radio & Panadapter references
    var frequencyLineWidth: CGFloat = 3.0
    var markerHeight: CGFloat = 0.6                                 // height % for band markers
    
    var legendFont = NSFont(name: "Monaco", size: 12.0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panadapter: Panadapter? { return params.panadapter }
    
    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / bounds.width }

    fileprivate var _path = NSBezierPath()

    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw Layers
    ///
    /// - Parameters:
    ///   - layer: a CALayer
    ///   - ctx: context
    ///
    func draw(_ layer: CALayer, in ctx: CGContext) {
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        drawFilterOutlines(slice)
        
        drawFrequencyLines(slice)
        
        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
    /// Begin observing Slice properties
    ///
    public func beginObservations() {
        observations(slice, paths: _sliceKeyPaths)
    }
    /// Stop observing Slice properties
    ///
    public func stopObservations() {
        observations(slice, paths: _sliceKeyPaths, remove: true)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Draw the Filter Outline
    ///
    /// - Parameter slice:  this Slice
    ///
    fileprivate func drawFilterOutlines(_ slice: xLib6000.Slice) {
        
        // calculate the Filter position & width
        let _filterPosition = CGFloat(slice.filterLow + slice.frequency - _start) / _hzPerUnit
        let _filterWidth = CGFloat(slice.filterHigh - slice.filterLow) / _hzPerUnit
        
        // draw the Filter
        let _rect = NSRect(x: _filterPosition, y: 0, width: _filterWidth, height: frame.height)
        _path.fillRect( _rect, withColor: Defaults[.sliceFilter], andAlpha: Defaults[.sliceFilterOpacity])
        
        _path.strokeRemove()
    }
    /// Draw the Frequency line
    ///
    /// - Parameter slice:  this Slice
    ///
    fileprivate func drawFrequencyLines(_ slice: xLib6000.Slice) {
        
        // set the width & color
        _path.lineWidth = frequencyLineWidth
        if slice.active { Defaults[.sliceActive].set() } else { Defaults[.sliceInactive].set() }
        
        // calculate the position
        let _freqPosition = ( CGFloat(slice.frequency - _start) / _hzPerUnit)
        
        // create the Frequency line
        _path.move(to: NSPoint(x: _freqPosition, y: frame.height))
        _path.line(to: NSPoint(x: _freqPosition, y: 0))
        
        // add the triangle cap (if active)
        if slice.active { _path.drawTriangle(at: _freqPosition, topWidth: 15, triangleHeight: 15, topPosition: frame.height) }
        
        _path.strokeRemove()
    }
    
    /// Fore a redraw
    ///
    fileprivate func redraw() {
        
        // interact with the UI
        DispatchQueue.main.async { [unowned self] in
            // force a redraw
            self.setNeedsDisplay()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _sliceKeyPaths =
        [
            #keyPath(xLib6000.Slice.active),
            #keyPath(xLib6000.Slice.frequency),
            #keyPath(xLib6000.Slice.filterHigh),
            #keyPath(xLib6000.Slice.filterLow)
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
            else { object.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil) }
        }
    }
    /// Observe properties
    ///
    /// - Parameters:
    ///   - keyPath: the registered KeyPath
    ///   - object: object containing the KeyPath
    ///   - change: dictionary of values
    ///   - context: context (if any)
    ///
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case #keyPath(xLib6000.Slice.active):
            redraw()
            
        case #keyPath(xLib6000.Slice.frequency):
            redraw()
            
        case #keyPath(xLib6000.Slice.filterHigh):
            redraw()
            
        case #keyPath(xLib6000.Slice.filterLow):
            redraw()
            
        default:
            _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
        }
    }
}
