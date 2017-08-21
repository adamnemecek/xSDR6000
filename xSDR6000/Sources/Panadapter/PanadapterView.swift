//
//  PanadapterView.swift
//  xSDR6000
//
//  Created by Douglas Adams on 12/10/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

typealias FrequencyParamTuple = (high: Int, low: Int, spacing: Int, format: String)

// --------------------------------------------------------------------------------
// MARK: - Panadapter View class implementation
// --------------------------------------------------------------------------------

final class PanadapterView : NSView, CALayerDelegate {
        
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params: Params!                                             // Radio & Panadapter references
    
    var frequencyLegendHeight: CGFloat = 20                         // height of the Frequency Legend layer
    var markerHeight: CGFloat = 0.6                                 // height % for band markers
    var dbLegendFont = NSFont(name: "Monaco", size: 12.0)
    var frequencyLegendFont = NSFont(name: "Monaco", size: 12.0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio: Radio { return params.radio }       // values derived from Params
    fileprivate var _panadapter: Panadapter? { return params.panadapter }

    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / self.frame.width }
    
    fileprivate var _rootLayer: CALayer!                                // layers
    fileprivate var _spectrumLayer: PanadapterLayer!
    fileprivate var _frequencyLegendLayer: CALayer!
    fileprivate var _sliceLayer: CALayer!
    fileprivate var _dbLegendLayer: CALayer!

    fileprivate var _minY: CAConstraint!
    fileprivate var _minX: CAConstraint!
    fileprivate var _maxY: CAConstraint!
    fileprivate var _maxX: CAConstraint!
    fileprivate var _aboveFrequencyLegendY: CAConstraint!
    fileprivate var _numberOfLegends: CGFloat!                          // number of legend values
    fileprivate var _dbLegendAttributes = [String:AnyObject]()          // Font & Size for the db Legend
    fileprivate var _frequencyLegendAttributes = [String:AnyObject]()   // Font & Size for the Frequency Legend
    fileprivate var _path = NSBezierPath()
    fileprivate var _dbLegendHeight: CGFloat = 0                        // height of dbLegend labels
    fileprivate var _dbLegendXPosition: CGFloat = 0
    fileprivate var _frequencyParams: FrequencyParamTuple {             // given Bandwidth, return a Spacing & a Format
        get { return kFrequencyParamTuples.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? kFrequencyParamTuples[0] } }
    
    // tracking areas
    fileprivate var _tnfTracking = [String : NSTrackingArea]()
    fileprivate let _trackingOptions = NSTrackingAreaOptions.mouseEnteredAndExited.union(.activeInActiveApp)
    fileprivate var _activeTrackingArea: NSTrackingArea?
    
    // band & markers
    fileprivate lazy var _segments = Band.sharedInstance.segments

    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)

    fileprivate let _dbLegendFormat = " %4.0f"
    fileprivate let _dbLegendWidth: CGFloat = 40                        // width of Db Legend layer
    fileprivate let _frequencyLineWidth: CGFloat = 3.0
    fileprivate let kRootLayer = "root"                                 // layer names
    fileprivate let kSpectrumLayer = "spectrum"
    fileprivate let kFrequencyLegendLayer = "frequency"
    fileprivate let kSliceLayer = "slice"
    fileprivate let kDbLegendLayer = "legend"
    
    fileprivate let kFrequencyParamTuples: [FrequencyParamTuple] =      // incr & format vs Bandwidth
        [   //      Bandwidth               Legend
            //  from         to        spacing   format
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

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// Awake from Nib
    ///
    override func awakeFromNib() {

        // create the Frequency Legend, Db Legend, Panadapter and Slice layers
        setupLayers()
        
        // begin observing Defaults
        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
        
        _panadapter!.delegate = _spectrumLayer
        
        redrawDbLegendLayer()
    }
    /// The view is about to begin resizing
    ///
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        
        // freeze the spectrum waveform
        _spectrumLayer.liveResize = true
    }
    /// The view's resizing has ended
    ///
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        
        // resume drawing the spectrum waveform
        _spectrumLayer.liveResize = false
        
        // tell the Panadapter to tell the Radio the new dimensions
        _panadapter!.panDimensions = CGSize(width: frame.width, height: frame.height - frequencyLegendHeight)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Redraw the FrequencyLegend Layer
    ///
    func redrawFrequencyLegendLayer() {
        
        redrawLayer(kFrequencyLegendLayer)
    }
    /// Redraw the DbLegend Layer
    ///
    func redrawDbLegendLayer() {
        
        redrawLayer(kDbLegendLayer)
    }
    /// Redraw all of the layers
    ///
    func redrawAllLayers() {
        
        redrawLayer(kFrequencyLegendLayer)
        redrawLayer(kDbLegendLayer)
        redrawSliceLayers()
    }
    /// Redraw a Slice Layer
    ///
    func redrawSliceLayer(_ slice: xLib6000.Slice) {
        var sliceLayer: CALayer? = nil
        
        // find the specified SliceLayer
        for layer in self._rootLayer.sublayers! where layer is SliceLayer {
            if (layer as! SliceLayer).slice == slice { sliceLayer = layer ; break }
        }
        // for the specified SliceLayer
        if let layer = sliceLayer as? SliceLayer {
            // interact with the UI
            DispatchQueue.main.async {
                // force a redraw
                layer.setNeedsDisplay()
            }
        }
    }
    /// Redraw all the Slice Layers
    ///
    func redrawSliceLayers() {
        
        // interact with the UI
        DispatchQueue.main.async {
            // for each SliceLayer
            for layer in self._rootLayer.sublayers! where layer is SliceLayer {
                // force a redraw
                layer.setNeedsDisplay()
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Establish the Layers and their relationships to each other
    ///
    fileprivate func setupLayers() {
        
        // create layer constraints
        _minY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY)
        _maxY = CAConstraint(attribute: .maxY, relativeTo: "superlayer", attribute: .maxY)
        _minX = CAConstraint(attribute: .minX, relativeTo: "superlayer", attribute: .minX)
        _maxX = CAConstraint(attribute: .maxX, relativeTo: "superlayer", attribute: .maxX)
        _aboveFrequencyLegendY = CAConstraint(attribute: .minY, relativeTo: "superlayer", attribute: .minY, offset: frequencyLegendHeight)
        
        // create layers
        _rootLayer = CALayer()                                      // ***** Root layer *****
        _rootLayer.name = kRootLayer
        _rootLayer.layoutManager = CAConstraintLayoutManager()
        _rootLayer.frame = frame
        layerUsesCoreImageFilters = true
        
        // make this a layer-hosting view
        layer = _rootLayer
        wantsLayer = true

        // select a compositing filter
        // possible choices - CIExclusionBlendMode, CIDifferenceBlendMode, CIMaximumCompositing
        guard let compositingFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            fatalError("Unable to create compositing filter")
        }

        _spectrumLayer = PanadapterLayer()                          // ***** Panadapter layer *****
        _spectrumLayer.name = kSpectrumLayer
        _spectrumLayer.frame = CGRect(x: 0, y: frequencyLegendHeight, width: _rootLayer.frame.width, height: _rootLayer.frame.height - frequencyLegendHeight)
        _spectrumLayer.addConstraint(_minX)                          // constraints
        _spectrumLayer.addConstraint(_maxX)
        _spectrumLayer.addConstraint(_aboveFrequencyLegendY)
        _spectrumLayer.addConstraint(_maxY)
        _spectrumLayer.delegate = _spectrumLayer                    // delegate
        
        _dbLegendLayer = CALayer()                                  // ***** Db Legend layer *****
        _dbLegendLayer.name = kDbLegendLayer
        _dbLegendLayer.addConstraint(_minX)                          // constraints
        _dbLegendLayer.addConstraint(_maxX)
        _dbLegendLayer.addConstraint(_aboveFrequencyLegendY)
        _dbLegendLayer.addConstraint(_maxY)
        _dbLegendLayer.delegate = self                              // delegate
        _dbLegendLayer.compositingFilter = compositingFilter
        
        _frequencyLegendLayer = CALayer()                           // ***** Frequency Legend layer *****
        _frequencyLegendLayer.name = kFrequencyLegendLayer
        _frequencyLegendLayer.addConstraint(_minX)                   // constraints
        _frequencyLegendLayer.addConstraint(_maxX)
        _frequencyLegendLayer.addConstraint(_minY)
        _frequencyLegendLayer.addConstraint(_maxY)
        _frequencyLegendLayer.delegate = self                       // delegate
        _frequencyLegendLayer.compositingFilter = compositingFilter
        
        // setup the layer hierarchy
        _rootLayer.addSublayer(_spectrumLayer)
        _rootLayer.addSublayer(_dbLegendLayer)
        _rootLayer.addSublayer(_frequencyLegendLayer)
        
        // add notification subscriptions
        addNotifications()
    }
    /// Create a new Slice layer
    ///
    /// - Parameter slice:      a Slice reference
    ///
    public func addSlice(_ slice: xLib6000.Slice) {
        
        DispatchQueue.main.async { [unowned self] in
            
            let sliceLayer = SliceLayer()
            
            sliceLayer.params = self.params
            // a reference to its Slice & name it
            sliceLayer.slice = slice
            sliceLayer.name = self.kSliceLayer + sliceLayer.slice.id

            // position it
            sliceLayer.frame = CGRect(x: 0, y: self.frequencyLegendHeight, width: self._rootLayer.frame.width, height: self._rootLayer.frame.height - self.frequencyLegendHeight)
            sliceLayer.addConstraint(self._minX)                          // constraints
            sliceLayer.addConstraint(self._maxX)
            sliceLayer.addConstraint(self._aboveFrequencyLegendY)
            sliceLayer.addConstraint(self._maxY)
            
            // set its delegate
            sliceLayer.delegate = sliceLayer
            
            // select the way it will be composited with the other layers
            sliceLayer.compositingFilter = self.compositingFilter
            
            // add it to the hierarchy
            self._rootLayer.addSublayer(sliceLayer)
            
            // cause the Layer to observe the Slice's properties
            sliceLayer.beginObservations()
            
            // cause it to be drawn
            sliceLayer.setNeedsDisplay()
        }
    }
    /// Remove an existing Slice layer
    ///
    /// - Parameter slice:      a Slice reference
    ///
    func removeSlice(_ slice: xLib6000.Slice) {
        
        DispatchQueue.main.async { [unowned self] in
            var sliceLayer: CALayer? = nil
            
            // find the specified SliceLayer
            for layer in self._rootLayer.sublayers! where layer is SliceLayer {
                if (layer as! SliceLayer).slice == slice { sliceLayer = layer ; break }
            }
            // if found
            if let layer = sliceLayer as? SliceLayer {
                
                // stop the Layer from observing the Slices's properties
                layer.stopObservations()
                
                /// remove the layer from the layer hierarchy
                layer.removeFromSuperlayer()
            }
        }
    }
    /// Draw the Db Legend Layer
    ///
    ///     layer includes the Db Legends and the horizontal Db lines
    ///
    fileprivate func drawDbLegendLayer(_ layer: CALayer) {
        
        // set the background color
        layer.backgroundColor = Defaults[.dbLegendBackground].cgColor
        
        // setup the db Legend font & size
        _dbLegendAttributes[NSForegroundColorAttributeName] = Defaults[.dbLegend]
        _dbLegendAttributes[NSFontAttributeName] = dbLegendFont
        _dbLegendHeight = "-000".size(withAttributes: _dbLegendAttributes).height
        _dbLegendXPosition = layer.bounds.width - 40

        // set Line Width, Color & Dash
        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
        Defaults[.gridLines].set()
        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )

        // calculate the spacings
        let dbRange = _panadapter!.maxDbm - _panadapter!.minDbm
        let yIncrPerDb = _dbLegendLayer.frame.height / dbRange
        let lineSpacing = CGFloat(Defaults[.dbLegendSpacing])
        let yIncrPerMark = yIncrPerDb * lineSpacing
        
        // calculate the number & position of the legend marks
        let numberOfLegends = Int( dbRange / lineSpacing)
        let firstMarkValue = _panadapter!.minDbm - _panadapter!.minDbm.truncatingRemainder(dividingBy:  lineSpacing)
        let firstMarkPosition = -_panadapter!.minDbm.truncatingRemainder(dividingBy:  lineSpacing) * yIncrPerDb
        
        // draw the legend
        for i in 0...numberOfLegends {

            // calculate the position of the legend
            let linePosition = firstMarkPosition + (CGFloat(i) * yIncrPerMark) - _dbLegendHeight/3
            
            // format & draw the legend
            let lineLabel = String(format: _dbLegendFormat, firstMarkValue + (CGFloat(i) * lineSpacing))
            lineLabel.draw(at: NSMakePoint(_dbLegendXPosition, linePosition ) , withAttributes: _dbLegendAttributes)
            // draw the line
            _path.hLine(at: linePosition + _dbLegendHeight/3, fromX: 0, toX: layer.bounds.width - 40 )
        }
        _path.strokeRemove()
    }
    /// Draw the Frequency Legend Layer
    ///
    ///     Layer includes the frequency legends and the vertical frequency lines
    ///
    fileprivate func drawFrequencyLegendLayer(_ layer: CALayer) {
        
        // set the background color
        layer.backgroundColor = Defaults[.frequencyLegendBackground].cgColor
        
        // setup the Frequency Legend font & size
        _frequencyLegendAttributes[NSForegroundColorAttributeName] = Defaults[.frequencyLegend]
        _frequencyLegendAttributes[NSFontAttributeName] = frequencyLegendFont

        let legendHeight = "123.456".size(withAttributes: _frequencyLegendAttributes).height
        
        // remember the position of the previous legend (left to right)
        var previousLegendPosition: CGFloat = 0.0
        
        // set Line Width, Color & Dash
        _path.lineWidth = CGFloat(Defaults[.gridLineWidth])
        Defaults[.gridLines].set()
        let dash: [CGFloat] = Defaults[.gridLinesDashed] ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )

        // calculate the spacings
        let freqRange = _end - _start
        let xIncrPerLegend = CGFloat(_frequencyParams.spacing) / _hzPerUnit
        
        // calculate the number & position of the legend marks
        let numberOfMarks = freqRange / _frequencyParams.spacing
        let firstFreqValue = _start + _frequencyParams.spacing - (_start - ( (_start / _frequencyParams.spacing) * _frequencyParams.spacing))
        let firstFreqPosition = CGFloat(firstFreqValue - _start) / _hzPerUnit
        
        for i in 0...numberOfMarks {
            let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            
            // calculate the Frequency legend value & width
            let legendLabel = String(format: _frequencyParams.format, ( CGFloat(firstFreqValue) + CGFloat( i * _frequencyParams.spacing)) / 1_000_000.0)
            let legendWidth = legendLabel.size(withAttributes: _frequencyLegendAttributes).width
            
            // skip the legend if it would overlap the start or end or if it would be too close to the previous legend
//            if xPosition > 0 && xPosition + legendWidth < _frequencyLayer.frame.width && xPosition - previousLegendPosition > 1.2 * legendWidth {
                // draw the legend
                legendLabel.draw(at: NSMakePoint( xPosition - (legendWidth/2), 1), withAttributes: _frequencyLegendAttributes)
                // save the position for comparison when drawing the next legend
                previousLegendPosition = xPosition
//            }
            // draw a vertical line at the frequency legend
            if xPosition < layer.bounds.width {
                _path.vLine(at: xPosition, fromY: layer.bounds.height, toY: legendHeight)
            }
            // draw an "in-between" vertical line
            _path.vLine(at: xPosition + (xIncrPerLegend/2), fromY: layer.bounds.height, toY: legendHeight)

        }
        _path.strokeRemove()
        
        // draw band markers (if enabled)
        if Defaults[.showMarkers] {
            drawBandMarkers() }

    }
    /// Draw the outline of the Tnf's
    ///
    fileprivate func drawTnfOutlines() {
        
        for (_, _tnf) in _radio.tnfs {
            
            if _tnf.frequency >= _start && _tnf.frequency <= _end {
                // calculate the Tnf position & width
                let _tnfPosition = CGFloat(_tnf.frequency - _tnf.width/2 - _start) / _hzPerUnit
                let _tnfWidth = CGFloat(_tnf.width) / _hzPerUnit
                
                let _color = _radio.tnfEnabled ? Defaults[.tnfActive] : Defaults[.tnfInactive]
                
                // draw the Tnf
                let _rect = NSRect(x: _tnfPosition, y: 0, width: _tnfWidth, height: frame.height)
                _path.fillRect( _rect, withColor: _color, andAlpha: Defaults[.sliceFilterOpacity])
                _path.crosshatch(_rect, color: NSColor.white, depth: _tnf.depth, twoWay: _tnf.permanent)
            }
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
    /// Add a Tnf Tracking area
    ///
    /// - Parameter tnf:    a Tnf reference
    ///
    fileprivate func addTnfTrackingArea(_ tnf: Tnf) {
        
        // make the tracking area wider if it would be too small to easily click on
        let tnfWidth = (tnf.width < 500 ? 500 : tnf.width)
        let trackingWidth  = CGFloat(tnfWidth) / _hzPerUnit
        
        // calculate the Tracking Area position
        let trackingPosition = CGFloat(tnf.frequency - tnfWidth/2 - _start) / _hzPerUnit
        
        // create the Tnf rectangle
        let rect = NSRect(x: trackingPosition, y: 0, width: trackingWidth, height: _sliceLayer.frame.height)
        
        // create & add the Tnf Tracking Area
        _tnfTracking[tnf.id] = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "tnf", "Object": tnf])
        addTrackingArea(_tnfTracking[tnf.id]!)
    }
    /// Remove a Tnf Tracking area
    ///
    /// - Parameter tnf:    a Tnf reference
    ///
    fileprivate func removeTnfTrackingArea(_ tnf: Tnf) {
        
        // remove the existing Tnf Tracking Area (if any)
        if _tnfTracking[tnf.id] != nil {
            
            removeTrackingArea(_tnfTracking[tnf.id]!)
            _tnfTracking[tnf.id] = nil
        }
    }
    /// Redraw a layer
    ///
    /// - Parameter layerName:  name of the layer
    ///
    fileprivate func redrawLayer(_ layerName: String) {
        var layer: CALayer?
        
        switch layerName {
            
        case kSpectrumLayer:
            layer = _spectrumLayer
            
        case kFrequencyLegendLayer:
            layer = _frequencyLegendLayer
            
        case kDbLegendLayer:
            layer = _dbLegendLayer
            
        default:
            assert(true, "PanadapterView, redraw - unknown layer name, \(layerName)")
            break
        }
        
        if let layer = layer {
            
            // interact with the UI
            DispatchQueue.main.async {
                // force a redraw
                layer.setNeedsDisplay()
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods

    fileprivate let _defaultsKeyPaths =               // Defaults keypaths to observe
        [
            "bandEdge",                               // Marker related
            "bandMarker",
            "bandMarkerOpacity",
            "segmentEdge",
            "showMarkers",
            
            "dbLegend",                               // DbLegend related
            "dbLegendBackground",
            "dbLegendSpacing",
            
            "frequencyLegend",                        // FrequencyLegend related
            "frequencyLegendBackground",
            
            "gridLines",                              // Grid related
            "gridLineWidth",
            "gridLinesDashed",
            
            "sliceActive",                            // Slice related
            "sliceFilter",
            "sliceFilterOpacity",
            "sliceInactive",
            
            "spectrumBackground",                     // Spectrum related
            
            "tnfActive",                              // Tnf related
            "tnfEnabled",
            "tnfInactive"
        ]
    fileprivate let _tnfKeyPaths =                    // Tnf keypaths to observe
        [
            #keyPath(Tnf.depth),
            #keyPath(Tnf.frequency),
            #keyPath(Tnf.permanent),
            #keyPath(Tnf.width)
    ]
    
    /// Add / Remove property observations
    ///
    /// - Parameters:
    ///   - object: the object of the observations
    ///   - paths: an array of KeyPaths
    ///   - add: add / remove (defaults to add)
    ///
    fileprivate func observations<T: NSObject>(_ object: T, paths: [String], remove: Bool = false) {
        
        // for each KeyPath Add / Remove observations
        for keyPath in paths {
            
            if remove { object.removeObserver(self, forKeyPath: keyPath, context: nil) }
            else { object.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil) }
        }
    }
    /// Observe properties
    ///
    /// - Parameters:
    ///   - keyPath: the registered KeyPath
    ///   - object: object containing the KeyPath
    ///   - change: dictionary of values
    ///   - context: context (if any)
    ///
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case "bandEdge", "bandMarker", "bandMarkerOpacity", "segmentEdge", "showMarkers":   // Marker related
            redrawLayer(kFrequencyLegendLayer)
            
        case "dbLegend", "dbLegendBackground", "dbLegendSpacing":                           // dbLegend related
            redrawLayer(kDbLegendLayer)
            
        case "frequencyLegend", "frequencyLegendBackground":                                // FrequencyLegend related
            redrawLayer(kFrequencyLegendLayer)
            
        case "gridLines", "gridLineWidth", "gridLinesDashed", "spectrumBackground":         // Grid related
            redrawLayer(kDbLegendLayer)
            redrawLayer(kFrequencyLegendLayer)
            
        case "sliceActive", "sliceFilter", "sliceFilterOpacity", "sliceInactive":           // Slice related
            redrawSliceLayers()
        
        case "tnfActive", "tnfEnabled", "tnfInactive":                                      // Tnf related
            redrawLayer(kFrequencyLegendLayer)
        
        default:
            _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    fileprivate func addNotifications() {
        
        NC.makeObserver(self, with: #selector(panadapterWillBeRemoved(_:)), of: .panadapterWillBeRemoved, object: nil)

        NC.makeObserver(self, with: #selector(sliceHasBeenAdded(_:)), of: .sliceHasBeenAdded, object: nil)
        
        NC.makeObserver(self, with: #selector(sliceWillBeRemoved(_:)), of: .sliceWillBeRemoved, object: nil)
        
        NC.makeObserver(self, with: #selector(tnfHasBeenAdded(_:)), of: .tnfHasBeenAdded, object: nil)
        
        NC.makeObserver(self, with: #selector(tnfWillBeRemoved(_:)), of: .tnfWillBeRemoved, object: nil)
    }
    /// Process .panadapterWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Panadapter object?
        if (note.object as? Panadapter) != nil {

            // remove Defaults property observers
            observations(Defaults, paths: _defaultsKeyPaths, remove: true)
        }
    }
    /// Process .sliceHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func sliceHasBeenAdded(_ note: Notification) {
        
        // does the Notification contain a Slice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, add a Slice Layer
            addSlice(slice)
            
            // log the event
            _log.msg("Slice initialized, ID = \(slice.id), pan = \(slice.panadapterId)", level: .debug, function: #function, file: #file, line: #line)

        }
    }
    /// Process .sliceShouldBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func sliceWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Slice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, log the event
            _log.msg("Slice will be removed, ID = \(slice.id), pan = \(slice.panadapterId)", level: .debug, function: #function, file: #file, line: #line)
            
            // remove the Slice Layer
            removeSlice(slice)
            
            // remove the Slice object
            _radio.slices[slice.id] = nil

        }
    }
    /// Process .tnfHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tnfHasBeenAdded(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? xLib6000.Tnf {
            
            // YES, log the event
            _log.msg("Tnf initialized, ID = \(tnf.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // observe changes to Tnf properties
            observations(tnf, paths: _tnfKeyPaths)
            
            // force a redraw of the Layer containing the Tnf's
            redrawLayer(kFrequencyLegendLayer)
        }
    }
    /// Process .tnfShouldBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tnfWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? xLib6000.Tnf {
            
            // YES, log the event
            _log.msg("Tnf will be removed, ID = \(tnf.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // remove Tnf property observers
            observations(tnf, paths: _tnfKeyPaths, remove: true)
            
            // remove the Tnf
            _radio.tnfs[tnf.id] = nil
            
            // force a redraw of the Layer containing the Tnf's
            redrawLayer(kFrequencyLegendLayer)
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - CALayerDelegate methods
    
    /// Draw Layers
    ///
    /// - Parameters:
    ///   - layer: a CALayer
    ///   - ctx: context
    ///
    func draw(_ layer: CALayer, in ctx: CGContext) {
        
        guard let layerName = layer.name else {
            return
        }
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        // draw a layer
        switch layerName {
            
        case kDbLegendLayer:
            drawDbLegendLayer(layer)
            
        case kFrequencyLegendLayer:
            drawFrequencyLegendLayer(layer)
            drawTnfOutlines()
            
        default:
            assert(true, "PanadapterView, draw - unknown layer name")
        }
        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
}
