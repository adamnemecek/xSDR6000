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

public final class DbLayer: CALayer {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params                          : Params!                        // Radio & Panadapter references
    var width: CGFloat                  = 40
    var font                            = NSFont(name: "Monaco", size: 12.0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio              : Radio { return params.radio }
    fileprivate var _panadapter         : Panadapter? { return params.panadapter }
    fileprivate var _minDbm             : CGFloat {return _panadapter!.minDbm }
    fileprivate var _maxDbm             : CGFloat {return _panadapter!.maxDbm }

    fileprivate var _spacings           = Defaults[.dbLegendSpacings]

    fileprivate var _path               = NSBezierPath()

    fileprivate var _attributes         = [String:AnyObject]()          // Font & Size for the db Legend
    fileprivate var _fontHeight         : CGFloat = 0                   // height of typical label

    fileprivate let kFormat             = " %4.0f"

    func updateDbmLevel(dragable dr: PanadapterViewController.Dragable) {

        // Upper half of the legend?
        if dr.original.y > frame.height/2 {
            
            // YES, update the max value
            _panadapter!.maxDbm += (dr.previous.y - dr.current.y)
        
        } else {
            
            // NO, update the min value
            _panadapter!.minDbm += (dr.previous.y - dr.current.y)
        }
        // redraw the db legend
        redraw()
    }
    
    func updateLegendSpacing(gestureRecognizer gr: NSClickGestureRecognizer, in view: NSView) {
        var item: NSMenuItem!

        // get the "click" coordinates and convert to the View
        let position = gr.location(in: view)
        
        // create the Spacings popup menu
        let menu = NSMenu(title: "Spacings")
        
        // populate the popup menu of Spacings
        for i in 0..<_spacings.count {
            item = menu.insertItem(withTitle: "\(_spacings[i]) dbm", action: #selector(legendSpacing(_:)), keyEquivalent: "", at: i)
            item.tag = Int(_spacings[i]) ?? 0
            item.target = self
        }
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: position, in: view)
    }
    /// respond to the Context Menu selection
    ///
    /// - Parameter sender:     the Context Menu
    ///
    @objc fileprivate func legendSpacing(_ sender: NSMenuItem) {
        
        // set the Db Legend spacing
        Defaults[.dbLegendSpacing] = String(sender.tag, radix: 10)
        
        // redraw the db legend
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
        let dbRange = _maxDbm - _minDbm
        let numberOfLegends = Int( dbRange / dbSpacing)
        let yIncrPerDb = frame.height / dbRange
        
        // calculate the value of the first legend & its y coordinate
        let minDbmValue = _minDbm - _minDbm.truncatingRemainder(dividingBy:  dbSpacing)
        let yOffset = -_minDbm.truncatingRemainder(dividingBy: dbSpacing) * yIncrPerDb
        
        
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
