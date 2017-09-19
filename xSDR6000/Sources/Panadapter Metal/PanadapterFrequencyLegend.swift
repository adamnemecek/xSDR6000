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

    var params: Params!                                             // Radio & Panadapter references
    
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
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {

        // setup the Frequency Legend font & size
        _attributes[NSForegroundColorAttributeName] = Defaults[.frequencyLegend]
        _attributes[NSFontAttributeName] = _font

        // calculate a typical font height
        _fontHeight = "123.456".size(withAttributes: _attributes).height
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
}
