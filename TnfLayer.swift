//
//  TnfLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/1/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

public final class TnfLayer: CALayer, CALayerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var lineColor                       = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.2)

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _params             : Params!           // Radio & Panadapter references
    fileprivate var _radio              : Radio { return _params.radio }
    fileprivate var _panadapter         : Panadapter? { return _params.panadapter }
    
    fileprivate var _center             : Int {return _panadapter!.center }
    fileprivate var _bandwidth          : Int { return _panadapter!.bandwidth }
    fileprivate var _start              : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit          : CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _path               = NSBezierPath()
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init( params: Params) {
        super.init()
        
        // save a reference to the Params
        _params = params
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - CALayerDelegate methods
    
    /// Draw Layers
    ///
    /// - Parameters:
    ///   - layer:      a CALayer
    ///   - ctx:        context
    ///
    public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        // for each Tnf
        for (_, tnf) in _radio.tnfs {
            
            // is it on this panadapter?
            if tnf.frequency >= _start && tnf.frequency <= _end {
                
                // YES, calculate the position & width
                let tnfPosition = CGFloat(tnf.frequency - tnf.width/2 - _start) / _hzPerUnit
                let tnfWidth = CGFloat(tnf.width) / _hzPerUnit
                
                // get the color
                let color = _radio.tnfEnabled ? Defaults[.tnfActive] : Defaults[.tnfInactive]
                
                // draw the rectangle
                let rect = NSRect(x: tnfPosition, y: 0, width: tnfWidth, height: frame.height)
                _path.fillRect( rect, withColor: color, andAlpha: Defaults[.sliceFilterOpacity])
                
                // crosshatch it based on depth
                _path.crosshatch(rect, color: lineColor, depth: tnf.depth, twoWay: tnf.permanent)
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
