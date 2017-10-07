//
//  FrequencyLegendLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/30/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

public final class FrequencyLegendLayer: CALayer, CALayerDelegate {

    typealias BandwidthParamTuple = (high: Int, low: Int, spacing: Int, format: String)
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params                          : Params!               // Radio & Panadapter references
    var height                          : CGFloat = 20          // layer height
    var font                            = NSFont(name: "Monaco", size: 12.0)

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio              : Radio { return params.radio }
    fileprivate var _panadapter         : Panadapter? { return params.panadapter }
    
    fileprivate var _center             : Int {return _panadapter!.center }
    fileprivate var _bandwidth          : Int { return _panadapter!.bandwidth }
    fileprivate var _start              : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit          : CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _bandwidthParam     : BandwidthParamTuple {  // given Bandwidth, return a Spacing & a Format
        get { return kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? kBandwidthParams[0] } }
    
    fileprivate var _attributes         = [String:AnyObject]()   // Font & Size for the Frequency Legend
    fileprivate var _path               = NSBezierPath()

    fileprivate let kBandwidthParams: [BandwidthParamTuple] =    // spacing & format vs Bandwidth
        [   //      Bandwidth               Legend
            //  high         low      spacing   format
            (15_000_000, 10_000_000, 1_000_000, "%0.0f"),           // 15.00 -> 10.00 Mhz
            (10_000_000,  5_000_000,   400_000, "%0.1f"),           // 10.00 ->  5.00 Mhz
            ( 5_000_000,   2_000_000,  200_000, "%0.1f"),           //  5.00 ->  2.00 Mhz
            ( 2_000_000,   1_000_000,  100_000, "%0.1f"),           //  2.00 ->  1.00 Mhz
            ( 1_000_000,     500_000,   50_000, "%0.2f"),           //  1.00 ->  0.50 Mhz
            (   500_000,     400_000,   40_000, "%0.2f"),           //  0.50 ->  0.40 Mhz
            (   400_000,     200_000,   20_000, "%0.2f"),           //  0.40 ->  0.20 Mhz
            (   200_000,     100_000,   10_000, "%0.2f"),           //  0.20 ->  0.10 Mhz
            (   100_000,      40_000,    4_000, "%0.3f"),           //  0.10 ->  0.04 Mhz
            (    40_000,      20_000,    2_000, "%0.3f"),           //  0.04 ->  0.02 Mhz
            (    20_000,      10_000,    1_000, "%0.3f"),           //  0.02 ->  0.01 Mhz
            (    10_000,       5_000,      500, "%0.4f"),           //  0.01 ->  0.005 Mhz
            (    5_000,            0,      400, "%0.4f")            //  0.005 -> 0 Mhz
    ]

    func updateBandwidth(dragable dr: PanadapterViewController.Dragable) {
        
        // CGFloat versions of params
        let end = CGFloat(_end)                     // end frequency (Hz)
        let start = CGFloat(_start)                 // start frequency (Hz)
        let bandwidth = CGFloat(_bandwidth)         // bandwidth (hz)
        
        // calculate the % change, + = greater bw, - = lesser bw
        let delta = ((dr.previous.x - dr.current.x) / frame.width)
        
        // calculate the new bandwidth (Hz)
        let newBandwidth = (1 + delta) * bandwidth
        
        // calculate adjustments to start & end
        let adjust = (newBandwidth - bandwidth) / 2.0
        let newStart = start - adjust
        let newEnd = end + adjust
        
        // calculate adjustment to the center
        let newStartPercent = (dr.frequency - newStart) / newBandwidth
        let freqError = (newStartPercent - dr.percent) * newBandwidth
        let newCenter = (newStart + freqError) + (newEnd - newStart) / 2.0
        
        // adjust the center & bandwidth values (Hz)
        _panadapter!.center = Int(newCenter)
        _panadapter!.bandwidth = Int(newBandwidth)
        
        // redraw the frequency legend
        redraw()
    }
    
    func updateCenter(dragable dr: PanadapterViewController.Dragable) {
        
        // adjust the center
        _panadapter!.center = _panadapter!.center - Int( (dr.current.x - dr.previous.x) * _hzPerUnit)
        
        // redraw the frequency legend
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
    public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        // set the background color
        layer.backgroundColor = Defaults[.frequencyLegendBackground].cgColor
        
        // setup the Frequency Legend font & size
        _attributes[NSForegroundColorAttributeName] = Defaults[.frequencyLegend]
        _attributes[NSFontAttributeName] = font
        
        let legendHeight = "123.456".size(withAttributes: _attributes).height
        
        // remember the position of the previous legend (left to right)
        var previousLegendPosition: CGFloat = 0.0
        
        // calculate the spacings
        let freqRange = _end - _start
        let bandwidthParams = kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? kBandwidthParams[0]
        let xIncrPerLegend = CGFloat(bandwidthParams.spacing) / _hzPerUnit
        
        // calculate the number & position of the legend marks
        let numberOfMarks = freqRange / bandwidthParams.spacing
        let firstFreqValue = _start + bandwidthParams.spacing - (_start - ( (_start / bandwidthParams.spacing) * bandwidthParams.spacing))
        let firstFreqPosition = CGFloat(firstFreqValue - _start) / _hzPerUnit
       
        // horizontal line above legend
        Defaults[.frequencyLegend].set()
        _path.hLine(at: height, fromX: 0, toX: frame.width)

        // draw legends
        for i in 0...numberOfMarks {
            let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            
            // calculate the Frequency legend value & width
            let legendLabel = String(format: bandwidthParams.format, ( CGFloat(firstFreqValue) + CGFloat( i * bandwidthParams.spacing)) / 1_000_000.0)
            let legendWidth = legendLabel.size(withAttributes: _attributes).width
            
            // skip the legend if it would overlap the start or end or if it would be too close to the previous legend
            if xPosition > 0 && xPosition + legendWidth < frame.width && xPosition - previousLegendPosition > 1.2 * legendWidth {
                // draw the legend
                legendLabel.draw(at: NSMakePoint( xPosition - (legendWidth/2), 1), withAttributes: _attributes)
                // save the position for comparison when drawing the next legend
                previousLegendPosition = xPosition
            }
        }
        _path.strokeRemove()

        // set Line Width, Color & Dash
        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )
        Defaults[.gridLines].set()
        
        // draw lines
        for i in 0...numberOfMarks {
            let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            
            // draw a vertical line at the frequency legend
            if xPosition < layer.bounds.width {
                _path.vLine(at: xPosition, fromY: layer.bounds.height, toY: legendHeight)
            }
            // draw an "in-between" vertical line
            _path.vLine(at: xPosition + (xIncrPerLegend/2), fromY: layer.bounds.height, toY: legendHeight)
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
