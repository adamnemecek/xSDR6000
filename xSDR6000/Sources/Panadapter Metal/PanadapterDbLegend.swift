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
    
    fileprivate var _spacings = [String]()                      // legend spacing choices

    fileprivate var _panLeft: NSPanGestureRecognizer!
    fileprivate var _clickRight: NSClickGestureRecognizer!
    fileprivate var _panStart: NSPoint?
    fileprivate var _dbmTop = false
    fileprivate var _newCursor: NSCursor?

    fileprivate let kFormat = " %4.0f"
    fileprivate let kXPosition: CGFloat = 0.0
    fileprivate let kRightButton = 0x02
    fileprivate let kLeftButton = 0x01                          // button masks

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // setup the Legend font & size
        _attributes[NSFontAttributeName] = _font
        
        // calculate a typical font height
        _fontHeight = "-000".size(withAttributes: _attributes).height
        
        // the view background will be transparent

        // get the list of possible spacings
        _spacings = Defaults[.dbLegendSpacings]
        
        // Pan (Left Button)
        _panLeft = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
        _panLeft.buttonMask = kLeftButton
        addGestureRecognizer(_panLeft)

        // Click (Right Button)
        _clickRight = NSClickGestureRecognizer(target: self, action: #selector(clickRight(_:)))
        _clickRight.buttonMask = kRightButton
        addGestureRecognizer(_clickRight)
    }
    /// Draw the Db Legend
    ///
    /// - Parameter dirtyRect:      the rect to draw
    ///
    override func draw(_ dirtyRect: NSRect) {
        
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
            lineLabel.draw(at: NSMakePoint(kXPosition, yPosition ) , withAttributes: _attributes)
        }
        _path.strokeRemove()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Force the view to redraw
    ///
    func redraw() {
        
        DispatchQueue.main.async {
            self.needsDisplay = true
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// respond to Right Click gesture
    ///
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc fileprivate func clickRight(_ gr: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        
        // get the "click" coordinates and convert to this View
        let location = gr.location(in: self)
        
        // create the popup menu
        let menu = NSMenu(title: "Spacings")
        
        // populate the popup menu of Spacings
        for i in 0..<_spacings.count {
            item = menu.insertItem(withTitle: "\(_spacings[i]) dbm", action: #selector(legendSpacing(_:)), keyEquivalent: "", at: i)
            item.tag = Int(_spacings[i]) ?? 0
            item.target = self
        }
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: location, in: self)
    }
    /// respond to the Context Menu selection
    ///
    /// - Parameter sender:     the Context Menu
    ///
    @objc fileprivate func legendSpacing(_ sender: NSMenuItem) {
        
        // set the Db Legend spacing
        Defaults[.dbLegendSpacing] = String(sender.tag, radix: 10)
        
        // force a redraw
        redraw()
        
    }
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeft(_ gr: NSPanGestureRecognizer) {
        
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
}
