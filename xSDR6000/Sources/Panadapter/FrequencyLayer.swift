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

public final class FrequencyLayer: CALayer {

    typealias BandwidthParamTuple = (high: Int, low: Int, spacing: Int, format: String)
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params                          : Params!               // Radio & Panadapter references
    var legendHeight                    : CGFloat = 20          // height of legend area
    var font                            = NSFont(name: "Monaco", size: 12.0)
    var markerHeight                    : CGFloat = 0.6         // height % for band markers
    

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

    // band & markers
    fileprivate lazy var _segments = Band.sharedInstance.segments
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Draw Layer
    ///
    /// - Parameter ctx:        a CG context
    ///
    func drawLayer(in ctx: CGContext) {
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        drawLegend()
        
        if Defaults[.showMarkers] { drawBandMarkers() }
        
        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
    /// Process a drag
    ///
    /// - Parameter dr:         the draggable
    ///
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
    /// Force the layer to be redrawn
    ///
    func redraw() {
        // interact with the UI
        DispatchQueue.main.async {
            // force a redraw
            self.setNeedsDisplay()
        }
    }
    fileprivate func drawLegend() {
        
        // set the background color
        backgroundColor = Defaults[.frequencyLegendBackground].cgColor
        
        // setup the Frequency Legend font & size
        _attributes[NSForegroundColorAttributeName] = Defaults[.frequencyLegend]
        _attributes[NSFontAttributeName] = font
        
        let bandwidthParams = kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? kBandwidthParams[0]
        let xIncrPerLegend = CGFloat(bandwidthParams.spacing) / _hzPerUnit
        
        // calculate the number & position of the legend marks
        let numberOfMarks = (_end - _start) / bandwidthParams.spacing
        let firstFreqValue = _start + bandwidthParams.spacing - (_start - ( (_start / bandwidthParams.spacing) * bandwidthParams.spacing))
        let firstFreqPosition = CGFloat(firstFreqValue - _start) / _hzPerUnit

        // remember the position of the previous legend (left to right)
        var previousLegendPosition: CGFloat = 0.0
        
        // horizontal line above legend
        Defaults[.frequencyLegend].set()
        _path.hLine(at: legendHeight, fromX: 0, toX: frame.width)
        
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
        
//        let legendHeight = "123.456".size(withAttributes: _attributes).height

        // set Line Width, Color & Dash
        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )
        Defaults[.gridLines].set()
        
        // draw vertical grid lines
        for i in 0...numberOfMarks {
            let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            
            // draw a vertical line at the frequency legend
            if xPosition < bounds.width {
                _path.vLine(at: xPosition, fromY: bounds.height, toY: legendHeight)
            }
            // draw an "in-between" vertical line
            _path.vLine(at: xPosition + (xIncrPerLegend/2), fromY: bounds.height, toY: legendHeight)
        }
        _path.strokeRemove()
    }
    
    /// Draw the Band Markers
    ///
    fileprivate func drawBandMarkers() {
        // use solid lines
        _path.setLineDash( [2.0, 0.0], count: 2, phase: 0 )
        
        // filter for segments that overlap the panadapter frequency range
        let overlappingSegments = _segments.filter {
            (($0.start >= _start || $0.end <= _end) ||    // start or end in panadapter
                $0.start < _start && $0.end > _end) &&    // start -> end spans panadapter
                $0.enabled && $0.useMarkers}                                    // segment is enabled & uses Markers
        
        // ***** Band edges *****
        Defaults[.bandEdge].set()  // set the color
        _path.lineWidth = 1         // set the width
        
        // filter for segments that contain a band edge
        let edgeSegments = overlappingSegments.filter {$0.startIsEdge || $0.endIsEdge}
        for s in edgeSegments {
            
            // is the start of the segment a band edge?
            if s.startIsEdge {
                
                // YES, draw a vertical line for the starting band edge
                _path.vLine(at: CGFloat(s.start - _start) / _hzPerUnit, fromY: frame.height * markerHeight, toY: 0)
                _path.drawX(at: NSPoint(x: CGFloat(s.start - _start) / _hzPerUnit, y: frame.height * markerHeight), halfWidth: 6)
            }
            
            // is the end of the segment a band edge?
            if s.endIsEdge {
                
                // YES, draw a vertical line for the ending band edge
                _path.vLine(at: CGFloat(s.end - _start) / _hzPerUnit, fromY: frame.height * markerHeight, toY: 0)
                _path.drawX(at: NSPoint(x: CGFloat(s.end - _start) / _hzPerUnit, y: frame.height * markerHeight), halfWidth: 6)
            }
        }
        _path.strokeRemove()
        
        // ***** Inside segments *****
        Defaults[.segmentEdge].set()        // set the color
        _path.lineWidth = 1         // set the width
        var previousEnd = 0
        
        // filter for segments that contain an inside segment
        let insideSegments = overlappingSegments.filter {!$0.startIsEdge && !$0.endIsEdge}
        for s in insideSegments {
            
            // does this segment overlap the previous segment?
            if s.start != previousEnd {
                
                // NO, draw a vertical line for the inside segment start
                _path.vLine(at: CGFloat(s.start - _start) / _hzPerUnit, fromY: frame.height * markerHeight - 6/2 - 1, toY: 0)
                _path.drawCircle(at: NSPoint(x: CGFloat(s.start - _start) / _hzPerUnit, y: frame.height * markerHeight), radius: 6)
            }
            
            // draw a vertical line for the inside segment end
            _path.vLine(at: CGFloat(s.end - _start) / _hzPerUnit, fromY: frame.height * markerHeight - 6/2 - 1, toY: 0)
            _path.drawCircle(at: NSPoint(x: CGFloat(s.end - _start) / _hzPerUnit, y: frame.height * markerHeight), radius: 6)
            previousEnd = s.end
        }
        _path.strokeRemove()
        
        // ***** Band Shading *****
        Defaults[.bandMarker].withAlphaComponent(Defaults[.bandMarkerOpacity]).set()
        for s in overlappingSegments {
            
            // calculate start & end of shading
            let start = (s.start >= _start) ? s.start : _start
            let end = (_end >= s.end) ? s.end : _end
            
            // draw a shaded rectangle for the Segment
            let rect = NSRect(x: CGFloat(start - _start) / _hzPerUnit, y: 0, width: CGFloat(end - start) / _hzPerUnit, height: 20)
            NSBezierPath.fill(rect)
        }
        _path.strokeRemove()
    }
}
