//
//  PanadapterDbLegend.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//


import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Panadapter Db Legend View class implementation
// --------------------------------------------------------------------------------

final class PanadapterDbLegend: NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params: Params!                                             // Radio & Panadapter references
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio: Radio { return params.radio }           // values derived from Params
    fileprivate var _panadapter: Panadapter? { return params.panadapter }
    
    fileprivate var _path = NSBezierPath()
    fileprivate let _font = NSFont(name: "Monaco", size: 12.0)
    fileprivate var _attributes = [String:AnyObject]()          // Font & Size for the db Legend
    fileprivate var _fontHeight: CGFloat = 0                    // height of typical label
    
    fileprivate var _panLeftButton: NSPanGestureRecognizer!
    fileprivate var _panStart: NSPoint?
    fileprivate var _dbmTop = false
    fileprivate var _newCursor: NSCursor?

    fileprivate let kFormat = " %4.0f"
    fileprivate let kXPosition: CGFloat = 0.0
    fileprivate let kLeftButton = 0x01                          // button masks

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // setup the Legend font & size
        _attributes[NSFontAttributeName] = _font
        
        // calculate a typical font height
        _fontHeight = "-000".size(withAttributes: _attributes).height
        
        // the view background will be transparent

        // Pan (Left Button)
        _panLeftButton = NSPanGestureRecognizer(target: self, action: #selector(panLeftButton(_:)))
        _panLeftButton.buttonMask = kLeftButton
        addGestureRecognizer(_panLeftButton)
}
    /// Draw the Db Legend
    ///
    ///
    override func draw(_ dirtyRect: NSRect) {
        
        // setup the Legend color
        _attributes[NSForegroundColorAttributeName] = Defaults[.frequencyLegend]

//        // set Line Width, Color & Dash
//        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
//        Defaults[.gridLines].set()
//        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
//        _path.setLineDash( dash, count: 2, phase: 0 )
        
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
            lineLabel.draw(at: NSMakePoint(kXPosition, yPosition ) , withAttributes: _attributes)
        }
        _path.strokeRemove()
    }
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr: the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeftButton(_ gr: NSPanGestureRecognizer) {
        
        let location = gr.location(in: self)
        
        switch gr.state {
            
        case .began:
            
            // save the start location
            _panStart = location
            
            // set the cursor
            _newCursor = NSCursor.resizeUpDown()
            
            // top or bottom?
            _dbmTop = (location.y > frame.height/2)
            
            _newCursor!.push()
            
        case .changed:
            
            // update the dbM Legend
            if _dbmTop {
                
                _panadapter!.maxDbm += (_panStart!.y - location.y)
                
            } else {
                
                _panadapter!.minDbm += (_panStart!.y - location.y)
            }
            // redraw the legend
            redraw()
            
            // use the current (intermediate) location as the start
            _panStart = location
            
            
        case .ended:
            
                // update the dbM Legend
            if _dbmTop {
                
                _panadapter!.maxDbm += (_panStart!.y - location.y)
                
            } else {
                
                _panadapter!.minDbm += (_panStart!.y - location.y)
            }
            // redraw the legend
            redraw()
            
            _newCursor!.pop()
            
        default:
            break
        }
    }
    
    func redraw() {
        
        DispatchQueue.main.async {
            
            self.needsDisplay = true
        }
    }
}
