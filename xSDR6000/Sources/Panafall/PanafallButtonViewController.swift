//
//  PanafallButtonViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Panafall Button View Controller class implementation
// --------------------------------------------------------------------------------

final class PanafallButtonViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    @IBOutlet weak var buttonView: PanafallButtonView!
    
    // used by bindings in Popovers
    //Panafall
    var antList: [Radio.AntennaPort] { return _radio.antennaList }
    var average: Int {
        get { return _panadapter!.average }
        set { _panadapter!.average = newValue } }

    var daxIqChannel: Int {
        get { return _panadapter!.daxIqChannel }
        set { _panadapter!.daxIqChannel = newValue } }

    var fps: Int {
        get { return _panadapter!.fps }
        set { _panadapter!.fps = newValue } }

    var loopA: Bool {
        get { return _panadapter!.loopAEnabled }
        set { _panadapter!.loopAEnabled = newValue } }

    var rfGain: Int {
        get { return _panadapter!.rfGain }
        set { _panadapter!.rfGain = newValue } }

    var rxAnt: String {
        get { return _panadapter!.rxAnt }
        set { _panadapter!.rxAnt = newValue } }

    var weightedAverage: Bool {
        get { return _panadapter!.weightedAverageEnabled }
        set { _panadapter!.weightedAverageEnabled = newValue } }

    // Waterfall
    var autoBlackEnabled: Bool {
        get { return _waterfall!.autoBlackEnabled }
        set { _waterfall!.autoBlackEnabled = newValue } }

    var blackLevel: Int {
        get { return _waterfall!.blackLevel }
        set { _waterfall!.blackLevel = newValue } }

    var colorGain: Int {
        get { return _waterfall!.colorGain }
        set { _waterfall!.colorGain = newValue } }

    var gradientIndex: Int {
        get { return _waterfall!.gradientIndex }
        set { _waterfall!.gradientIndex = newValue } }

    var gradientName: String { return gradientNames[_waterfall!.gradientIndex] }

    var gradientNames: [String] { return Gradient.gradientNames() }

    var lineDuration: Int {
        get { return _waterfall!.lineDuration }
        set { _waterfall!.lineDuration = newValue } }
    
    let daxChoices = ["None", "1", "2", "3", "4"]

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panafallViewController: PanafallViewController!
    
    fileprivate var _params: Params { return representedObject as! Params }
    
    fileprivate var _radio: Radio { return _params.radio }
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
    fileprivate var _waterfall: Waterfall? { return _radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _minDbm: CGFloat { return _panadapter!.minDbm }
    fileprivate var _maxDbm: CGFloat { return _panadapter!.maxDbm }

    // constants
    fileprivate let kPanafallEmbed = "PanafallEmbed"        // Segue names
    fileprivate let kBandPopover = "BandPopover"
    fileprivate let kAntennaPopover = "AntennaPopover"
    fileprivate let kDisplayPopover = "DisplayPopover"
    fileprivate let kDaxPopover = "DaxPopover"

    fileprivate let kPanadapterSplitViewItem = 0
    fileprivate let kWaterfallSplitViewItem = 1
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
        
    /// Prepare to execute a Segue
    ///
    /// - Parameters:
    ///   - segue: a Segue instance
    ///   - sender: the sender
    ///
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {

        switch segue.identifier! {
        
        case kPanafallEmbed:                            // this will always occur first
            
            // pass a copy of the Params
            (segue.destinationController as! NSViewController).representedObject = representedObject
            
            // save a reference to the Panafall view controller
            _panafallViewController = segue.destinationController as! PanafallViewController
            _panafallViewController!.representedObject = representedObject as! Params
            
            // give the PanadapterViewController & waterfallViewControllers a copy of the Params
            _panafallViewController!.splitViewItems[kPanadapterSplitViewItem].viewController.representedObject = representedObject as! Params
            _panafallViewController!.splitViewItems[kWaterfallSplitViewItem].viewController.representedObject = representedObject as! Params

        case kAntennaPopover, kDisplayPopover, kDaxPopover:
            
            // pass the Popovers a reference to this controller
            (segue.destinationController as! NSViewController).representedObject = self
            
        case kBandPopover:
            
            // pass the Band Popover a copy of the Params
            (segue.destinationController as! NSViewController).representedObject = representedObject
            
        default:
            break
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
        
    /// Redraw the FrequencyLegends on all Panadapters
    ///
    func redrawFrequencyLegend() {
        
        _panafallViewController?.redrawFrequencyLegend()
    }
    /// Redraw the DbLegends on all Panadapters
    ///
    func redrawDbLegend() {
        
        _panafallViewController?.redrawDbLegend()
    }
    /// Redraw the Slices on all Panadapters
    ///
    func redrawSlices() {
        
        _panafallViewController?.redrawSlices()
    }
    /// Redraw this Panafall
    ///
    public func redrawAll() {
        _panafallViewController.redrawAll()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Zoom + (decrease bandwidth)
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func zoomPlus(_ sender: NSButton) {
        
        // are we near the minimum?
        if _bandwidth / 2 > _panadapter!.minBw {
            
            // NO, make the bandwidth half of its current value
            _panadapter!.bandwidth = _bandwidth / 2
            
        } else {
            
            // YES, make the bandwidth the minimum value
            _panadapter!.bandwidth = _panadapter!.minBw
        }
    }
    /// Zoom - (increase the bandwidth)
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func zoomMinus(_ sender: NSButton) {
        // are we near the maximum?
        if _bandwidth * 2 > _panadapter!.maxBw {
            
            // YES, make the bandwidth maximum value
            _panadapter!.bandwidth = _panadapter!.maxBw
            
        } else {
            
            // NO, make the bandwidth twice its current value
            _panadapter!.bandwidth = _bandwidth * 2
        }
    }
    /// Close this Panafall
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func close(_ sender: NSButton) {
        
        buttonView.removeTrackingArea()
        
        // tell the Radio to remove this Panafall
        _radio.panafallRemove(_panadapter!.id)
    }
    /// Create a new Slice (if possible)
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func rx(_ sender: NSButton) {
        
        // tell the Radio (hardware) to add a Slice on this Panadapter
        _radio.sliceCreate(panadapter: _panadapter!)
    }
    /// Create a new Tnf
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func tnf(_ sender: NSButton) {
        
        // tell the Radio (hardware) to add a Tnf on this Panadapter
        _radio.tnfCreate(frequency: 0, panadapter: _panadapter!)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Delegate methods
    
}
