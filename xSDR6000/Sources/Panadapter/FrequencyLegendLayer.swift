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
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var height                          : CGFloat = 20          // layer height
    var font                            = NSFont(name: "Monaco", size: 12.0)

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _params             : Params!               // Radio & Panadapter references
    fileprivate var _radio              : Radio { return _params.radio }
    fileprivate var _panadapter         : Panadapter? { return _params.panadapter }
    
    fileprivate var _center             : Int {return _panadapter!.center }
    fileprivate var _bandwidth          : Int { return _panadapter!.bandwidth }
    fileprivate var _start              : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                : Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit          : CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _bandwidthParam     : BandwidthParamTuple {  // given Bandwidth, return a Spacing & a Format
        get { return PanadapterViewController.kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? PanadapterViewController.kBandwidthParams[0] } }
    
    fileprivate var _attributes         = [String:AnyObject]()   // Font & Size for the Frequency Legend
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
        let xIncrPerLegend = CGFloat(_bandwidthParam.spacing) / _hzPerUnit
        
        // calculate the number & position of the legend marks
        let numberOfMarks = freqRange / _bandwidthParam.spacing
        let firstFreqValue = _start + _bandwidthParam.spacing - (_start - ( (_start / _bandwidthParam.spacing) * _bandwidthParam.spacing))
        let firstFreqPosition = CGFloat(firstFreqValue - _start) / _hzPerUnit
       
        // horizontal line above legend
        Defaults[.frequencyLegend].set()
        _path.hLine(at: height, fromX: 0, toX: frame.width)

        // draw legends
        for i in 0...numberOfMarks {
            let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            
            // calculate the Frequency legend value & width
            let legendLabel = String(format: _bandwidthParam.format, ( CGFloat(firstFreqValue) + CGFloat( i * _bandwidthParam.spacing)) / 1_000_000.0)
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
