//
//  ViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000
import MetalKit

typealias BandwidthParamTuple = (high: Int, low: Int, spacing: Int, format: String)

class PanadapterViewController: NSViewController {
    
    static let kBandwidthParams: [BandwidthParamTuple] =    // spacing & format vs Bandwidth
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

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet weak var _spectrumView: MTKView!
    @IBOutlet weak var _frequencyLegendView: PanadapterFrequencyLegend!
    @IBOutlet weak var _dbLegendView: PanadapterDbLegend!
    
    fileprivate var _params: Params { return representedObject as! Params }

    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / _panadapter!.panDimensions.width }

    fileprivate var _panadapter: Panadapter? { return _params.panadapter }

    fileprivate var _bandwidthParam: BandwidthParamTuple {         // given Bandwidth, return a Spacing & a Format
        get { return PanadapterViewController.kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? PanadapterViewController.kBandwidthParams[0] } }
    
    fileprivate var _renderer: PanadapterRenderer!

    fileprivate var _panLeft: NSPanGestureRecognizer!
    fileprivate var _xStart: CGFloat = 0
    fileprivate var _newCursor: NSCursor?
    fileprivate let kLeftButton = 0x01                              // button masks

    // constants
    fileprivate let _log                    = (NSApp.delegate as! AppDelegate)
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // give the Frequency Legend access to the params
        _frequencyLegendView.params = _params

        _dbLegendView.params = _params
        
        _spectrumView.device = MTLCreateSystemDefaultDevice()
        
        guard _spectrumView.device != nil else {
            fatalError("Metal is not supported on this device")
        }
        
        _renderer = PanadapterRenderer(mtkView: _spectrumView)
        
        guard _renderer != nil else {
            fatalError("Renderer failed initialization")
        }
        
        _spectrumView.delegate = _renderer

        _panadapter?.delegate = _renderer
        
        // begin observing Defaults
        observations(UserDefaults.standard, paths: _defaultsKeyPaths)
        
        // add notification subscriptions
        addNotifications()

        // Pan (Left Button)
        _panLeft = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
        _panLeft.buttonMask = kLeftButton
        view.addGestureRecognizer(_panLeft)
    }
    /// View did layout
    ///
    override func viewDidLayout() {

        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: _spectrumView.frame.width, height: _spectrumView.frame.height)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc fileprivate func panLeft(_ gr: NSPanGestureRecognizer) {
        
        // update panadapter center
        func update(_ xStart: CGFloat, _ xCurrent: CGFloat) {
            let xDelta = xCurrent - xStart
            
            // adjust the center
            _panadapter!.center = _panadapter!.center - Int(xDelta * _hzPerUnit)
            
            // redraw the frequency legend
            _frequencyLegendView.redraw()
        }
        
        let xCurrent = gr.location(in: view).x
        
        switch gr.state {
        case .began:
            // save the start location
            _xStart = xCurrent
            
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
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Populate vertices for Tnf draw calls
    ///
    /// - Returns:      vertices for Tnf's
    ///
    func prepareTnfVertices() -> [PanadapterRenderer.TnfVertex] {
        var vertices: [PanadapterRenderer.TnfVertex] = []
        
        for (_, _tnf) in _panadapter!.radio!.tnfs {
            
            if _tnf.frequency >= _start && _tnf.frequency <= _end {
                
                // calculate the Tnf position & width
                let _tnfPosition = Float(_tnf.frequency - _tnf.width/2 - _start) / Float(_hzPerUnit)
                let _tnfWidth = Float(_tnf.width) / Float(_hzPerUnit)
                
                // color it based on depth & active / inactive
                var color: NSColor
                
                switch _tnf.depth {
                case Tnf.Depth.normal.rawValue:
                    color = Defaults[.tnfColorNormal]
                case Tnf.Depth.deep.rawValue:
                    color = Defaults[.tnfColorDeep]
                case Tnf.Depth.veryDeep.rawValue:
                    color = Defaults[.tnfColorVeryDeep]
                default:
                    color = Defaults[.tnfColorNormal]
                }
                // convert NSColor to float4
                let tnfColor = float4(Float(color.redComponent),
                                  Float(color.greenComponent),
                                  Float(color.blueComponent),
                                  Float(color.alphaComponent))

                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: _tnfPosition,  y: -1.0), color: tnfColor))
                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: _tnfPosition,  y:  1.0), color: tnfColor))
                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: _tnfPosition + _tnfWidth, y: -1.0), color: tnfColor))
                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: _tnfPosition + _tnfWidth, y:  1.0), color: tnfColor))
//                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: -0.5,  y: -1.0), color: tnfColor))
//                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: -0.5,  y:  1.0), color: tnfColor))
//                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: -0.5 + 0.1, y: -1.0), color: tnfColor))
//                vertices.append(PanadapterRenderer.TnfVertex(coord: float2(x: -0.5 + 0.1, y:  1.0), color: tnfColor))
            }
        }
        return vertices
    }
    /// Force a redraw
    ///
    func redraw() {
        DispatchQueue.main.async {
            
            // force a redraw
            self.view.needsDisplay = true            
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _defaultsKeyPaths = [               // Defaults keypaths to observe
        "gridLines",
        "spectrum",
        "spectrumBackground",
    ]

    fileprivate let _tnfKeyPaths = [                    // Tnf keypaths to observe
        #keyPath(Tnf.frequency),
        #keyPath(Tnf.depth),
        #keyPath(Tnf.width),
    ]
    
    fileprivate let _panadapterKeyPaths = [           // Panadapter keypaths to observe
        #keyPath(Panadapter.bandwidth),
        #keyPath(Panadapter.center)
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
            else { object.addObserver(self, forKeyPath: keyPath, options: [.initial, .new], context: nil) }
        }
    }
    /// Observe properties
    ///
    /// - Parameters:
    ///   - keyPath:        the registered KeyPath
    ///   - object:         object containing the KeyPath
    ///   - change:         dictionary of values
    ///   - context:        context (if any)
    ///
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case "gridLines", "spectrum":
            _renderer.populateUniforms()
            _renderer.updateUniformsBuffer()
            
        case "spectrumBackground":
            _renderer.setClearColor()
            
//        case #keyPath(Panadapter.bandwidth), #keyPath(Panadapter.center):
//            if let newValue = change?[.newKey] as? Int {
//                _renderer.uniforms.start = Int32(_center - newValue/2)
//                _renderer.uniforms.end = Int32(_center + newValue/2)
//                _renderer.updateUniformsBuffer()
//            }
            
        case #keyPath(Tnf.frequency), #keyPath(Tnf.depth), #keyPath(Tnf.width):
            _renderer.tnfVertices = prepareTnfVertices()
            _renderer.updateTnfs()
            
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
        
        NC.makeObserver(self, with: #selector(tnfHasBeenAdded(_:)), of: .tnfHasBeenAdded, object: nil)
        
        NC.makeObserver(self, with: #selector(tnfWillBeRemoved(_:)), of: .tnfWillBeRemoved, object: nil)

        NC.makeObserver(self, with: #selector(panadapterWillBeRemoved(_:)), of: .panadapterWillBeRemoved, object: nil)
    }
    /// Process .panadapterWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Panadapter object?
        if let panadapter = note.object as? Panadapter {
            
            // YES, is it this panadapter
            if panadapter == _panadapter! {
                
                // YES, remove Defaults property observers
                observations(Defaults, paths: _defaultsKeyPaths, remove: true)

//                // YES, remove Panadapter property observers
//                observations(panadapter, paths: _panadapterKeyPaths, remove: true)
            }
        }
    }
    /// Process .tnfHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tnfHasBeenAdded(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? Tnf {
            
            // YES, add observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths)
        }
    }
    /// Process .tnfWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tnfWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? Tnf {

            // YES, remove observations of this Tnf
            observations(tnf, paths: _tnfKeyPaths, remove: true)

        }
    }
}

