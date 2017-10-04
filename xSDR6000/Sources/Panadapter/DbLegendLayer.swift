//
//  DbLegendLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/30/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

public final class DbLegendLayer: CALayer, CALayerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var width: CGFloat = 40
    var font = NSFont(name: "Monaco", size: 12.0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _params             : Params!                        // Radio & Panadapter references
    fileprivate var _radio              : Radio { return _params.radio }
    fileprivate var _panadapter         : Panadapter? { return _params.panadapter }
    
    fileprivate var _center             : Int {return _panadapter!.center }
    fileprivate var _bandwidth          : Int { return _panadapter!.bandwidth }
    fileprivate var _start              : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit          : CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _path               = NSBezierPath()

    fileprivate var _attributes         = [String:AnyObject]()          // Font & Size for the db Legend
    fileprivate var _fontHeight         : CGFloat = 0                   // height of typical label

    fileprivate let kFormat             = " %4.0f"
    
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

        // setup the Legend font & size
        _attributes[NSForegroundColorAttributeName] = Defaults[.dbLegend]
        _attributes[NSFontAttributeName] = font
        
        // calculate a typical font height
        _fontHeight = "-000".size(withAttributes: _attributes).height
                
        // setup the Legend color
        _attributes[NSForegroundColorAttributeName] = Defaults[.dbLegend]
        
        // get the spacing between legends
        let dbSpacing = CGFloat(Defaults[.dbLegendSpacing])
        
        // calculate the number of legends & the y pixels per db
        let dbRange = _panadapter!.maxDbm - _panadapter!.minDbm
        let numberOfLegends = Int( dbRange / dbSpacing)
        let yIncrPerDb = frame.height / dbRange
        
        // calculate the value of the first legend & its y coordinate
        let minDbmValue = _panadapter!.minDbm - _panadapter!.minDbm.truncatingRemainder(dividingBy:  dbSpacing)
        let yOffset = -_panadapter!.minDbm.truncatingRemainder(dividingBy: dbSpacing) * yIncrPerDb
        
        
        // draw the legends
        for i in 0...numberOfLegends {
            
            // calculate the y coordinate of the legend
            let yPosition = yOffset + (CGFloat(i) * yIncrPerDb * dbSpacing) - _fontHeight/3
            
            // format & draw the legend
            let lineLabel = String(format: kFormat, minDbmValue + (CGFloat(i) * dbSpacing))
            lineLabel.draw(at: NSMakePoint(frame.width - width, yPosition ) , withAttributes: _attributes)
        }
        _path.strokeRemove()
        
        // set Line Width, Color & Dash
        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )
        Defaults[.gridLines].set()

        // draw the lines
        for i in 0...numberOfLegends {
            
            // calculate the y coordinate of the legend
            let yPosition = yOffset + (CGFloat(i) * yIncrPerDb * dbSpacing) - _fontHeight/3
            
            // draw the line
            _path.hLine(at: yPosition + _fontHeight/3, fromX: 0, toX: frame.width - width )
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
