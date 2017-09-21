//
//  PanadapterFrequencyLegend.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Panadapter Frequency Legend View class implementation
// --------------------------------------------------------------------------------

final class PanadapterFrequencyLegend: NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params: Params!                                             // Radio & Panadapter references
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio: Radio { return params.radio }           // values derived from Params
    fileprivate var _panadapter: Panadapter? { return params.panadapter }
    
    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _bandwidthParam: BandwidthParamTuple {         // given Bandwidth, return a Spacing & a Format
        get { return PanadapterViewController.kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? PanadapterViewController.kBandwidthParams[0] } }
    
    fileprivate var _path = NSBezierPath()
    fileprivate var _font = NSFont(name: "Monaco", size: 12.0)
    fileprivate var _attributes = [String:AnyObject]()              // Font & Size for the Frequency Legend
    fileprivate var _fontHeight: CGFloat = 0

    fileprivate var _panLeft: NSPanGestureRecognizer!
    fileprivate var _xStart: CGFloat = 0
    fileprivate var _newCursor: NSCursor?
    fileprivate let kLeftButton = 0x01                              // button masks

    fileprivate var _initialClickPoint: CGFloat = 0.0
    fileprivate var _markPercent: CGFloat = 0.0
    fileprivate var _markFreq: CGFloat = 0.0
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {

        // setup the Frequency Legend font & size
        _attributes[NSForegroundColorAttributeName] = Defaults[.frequencyLegend]
        _attributes[NSFontAttributeName] = _font

        // calculate a typical font height
        _fontHeight = "123.456".size(withAttributes: _attributes).height

        // Pan (Left Button)
        _panLeft = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
        _panLeft.buttonMask = kLeftButton
        addGestureRecognizer(_panLeft)
    }
    /// Draw the Frequency Legend
    ///
    ///
    override func draw(_ dirtyRect: NSRect) {
        
        // set the background color
        layer?.backgroundColor = Defaults[.frequencyLegendBackground].cgColor

        // set Line Width, Color & Dash
        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
        Defaults[.gridLines].set()
        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )
        
        // calculate the spacings
        let freqRange = _end - _start
        let xIncrement = CGFloat(_bandwidthParam.spacing) / _hzPerUnit
        
        // calculate the number & position of the legend marks
        let numberOfLabels = freqRange / _bandwidthParam.spacing
        let firstFrequency = _start + _bandwidthParam.spacing - (_start - ( (_start / _bandwidthParam.spacing) * _bandwidthParam.spacing))
        let xOffset = CGFloat(firstFrequency - _start) / _hzPerUnit
        
        var previousPosition: CGFloat = 0

        // draw the Frequency labels
        for i in 0...numberOfLabels {
            
            // calculate the label x coordinate
            let xPosition = xOffset + (CGFloat(i) * xIncrement)
            
            // calculate the label value & width
            let label = String(format: _bandwidthParam.format, ( CGFloat(firstFrequency) + CGFloat( i * _bandwidthParam.spacing)) / 1_000_000.0)
            let width = label.size(withAttributes: _attributes).width
            
            // skip the legend if it would overlap the start or end or if it would be too close to the previous legend
            if xPosition > 0 && xPosition + width < frame.width && xPosition - previousPosition > 1.2 * width {
                // draw the label
                label.draw(at: NSMakePoint( xPosition - (width/2), 1), withAttributes: _attributes)
                
                // save the position for comparison when drawing the next label
                previousPosition = xPosition
            }
            
            // draw a vertical line at the label center
            if xPosition < frame.width {
                _path.vLine(at: xPosition, fromY: frame.height, toY: _fontHeight)

                if xPosition + (xIncrement/2) < frame.width {
                    // draw a vertical line between labels
                    _path.vLine(at: xPosition + (xIncrement/2), fromY: frame.height, toY: _fontHeight)
                }
            }
        }
        _path.strokeRemove()
        
//        // draw band markers (if enabled)
//        if Defaults[.showMarkers] {
//            drawBandMarkers() }
        
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
    
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeft(_ gr: NSPanGestureRecognizer) {

        // update panadapter bandwidth & center
        func update(_ xStart: CGFloat, _ xCurrent: CGFloat) {
            
            Swift.print("xStart = \(xStart), xCurrent = \(xCurrent)")
            
            let end = CGFloat(_end)                     // end frequency (Hz)
            let start = CGFloat(_start)                 // start frequency (Hz)
            let bandwidth = CGFloat(_bandwidth)         // bandwidth (hz)
            
            // calculate the % change, + = greater bw, - = lesser bw
            let deltaPercent = ((xStart - xCurrent) / frame.width)

            // calculate the new bandwidth (Hz)
            let newBandwidth = (1 + deltaPercent) * bandwidth
            
            Swift.print("newBandwidth = \(newBandwidth)")
            
            // calculate adjustments to start * end
            let bandwidthDifference = newBandwidth - bandwidth
            let endAdjust = bandwidthDifference / 2.0
            let startAdjust = -endAdjust
            let newStart = start + startAdjust
            let newEnd = end + endAdjust
            
            let newMarkPercent = (_markFreq - newStart) / newBandwidth
            let markError = newMarkPercent - _markPercent
            let freqError = markError * newBandwidth
            
            Swift.print("freqError = \(freqError)")
            
            let finalStart = newStart + freqError
            let finalEnd = newEnd + freqError
            let newCenter = finalStart + (finalEnd - finalStart) / 2.0
            
            Swift.print("newCenter = \(newCenter)")
            
            // adjust the bandwidth & center values (Hz)
            _panadapter!.center = Int(newCenter)
            _panadapter!.bandwidth = Int(newBandwidth)
            
            // redraw the legend
            redraw()
        }
        
        let xCurrent = gr.location(in: self).x
        
        switch gr.state {
        case .began:
            // save the start location
            _xStart = xCurrent
            // calculate original mark params
            _markPercent = xCurrent / frame.width
            _markFreq = (_markPercent * CGFloat(_bandwidth)) + CGFloat(_start)

            Swift.print("width = \(frame.width), markPercent = \(_markPercent), markFreq = \(_markFreq)")
            
            // set the cursor
            _newCursor = NSCursor.resizeLeftRight()
            _newCursor!.push()
            
        case .changed:
            // update the panadapter params
            update(_xStart, xCurrent)
            
            // use the current (intermediate) location as the start
            _xStart = xCurrent
            
        case .ended:
            // update the panadapter params
            update(_xStart, xCurrent)
            
            // restore the cursor
            _newCursor!.pop()
            
        default:
            break
        }
    }
}
