//
//  EqViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/1/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Radio View Controller class implementation
// --------------------------------------------------------------------------------

final class EqViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet fileprivate weak var onButton: NSButton!              // buttons
    @IBOutlet fileprivate weak var rxButton: NSButton!
    @IBOutlet fileprivate weak var txButton: NSButton!
    @IBOutlet fileprivate weak var slider0: NSSlider!               // sliders
    @IBOutlet fileprivate weak var slider1: NSSlider!
    @IBOutlet fileprivate weak var slider2: NSSlider!
    @IBOutlet fileprivate weak var slider3: NSSlider!
    @IBOutlet fileprivate weak var slider4: NSSlider!
    @IBOutlet fileprivate weak var slider5: NSSlider!
    @IBOutlet fileprivate weak var slider6: NSSlider!
    @IBOutlet fileprivate weak var slider7: NSSlider!

    fileprivate var _radio: Radio!                                  // radio class
    fileprivate var _equalizerRx: Equalizer!                        // Rx Equalizer
    fileprivate var _equalizerTx: Equalizer!                        // Tx Equalizer

    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get references to the Radio & the Equalizers
        _radio = representedObject as! Radio
        
        _equalizerRx = _radio.equalizers[.rxsc]
        _equalizerTx = _radio.equalizers[.txsc]

        // enable the appropriate Equalizer
        rxButton.state = Defaults[.rxEqSelected] ? NSOnState : NSOffState
        txButton.state = Defaults[.rxEqSelected] ? NSOffState : NSOnState
        
        // set the state of thesliders & ON Button
        populateEqualizer()
     }
    
    override func viewWillAppear() {
    
        view.layer?.backgroundColor = NSColor.gray.cgColor
    
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    //
    // respond to the ON button
    //
    @IBAction func on(_ sender: NSButton) {

        // get a reference to the selected Equalizer
        let eq = (txButton.state == NSOnState ? _equalizerTx : _equalizerRx)

        // set its state
        eq!.eqEnabled = (onButton.state == NSOnState)
    }
    //
    // respond to the RX button
    //
    @IBAction func rx(_ sender: NSButton) {
        
        // force the other equalizer off
        txButton.state = (sender.state == NSOnState ? NSOffState : NSOnState)
        
        // save the state
        Defaults[.rxEqSelected] = (sender.state == NSOnState ? true : false)
        
        // populate the slider values and the ON button state
        populateEqualizer()
    }
    //
    // respond to the TX button
    //
    @IBAction func tx(_ sender: NSButton) {
        
        // force the other equalizer off
        rxButton.state = (sender.state == NSOnState ? NSOffState : NSOnState)
        
        // save the state
        Defaults[.rxEqSelected] = (sender.state == NSOnState ? false : true)

        // populate the slider values and the ON button state
        populateEqualizer()
    }
    //
    // respond to changes in a slider
    //
    @IBAction func slider(_ sender: NSSlider) {
        
        // get a reference to the selected Equalizer
        let eq = (txButton.state == NSOnState ? _equalizerTx : _equalizerRx)!
        
        // set the slider value
        switch sender.tag {
        case 0:
            eq.level63Hz = sender.integerValue
        case 1:
            eq.level125Hz = sender.integerValue
        case 2:
            eq.level250Hz = sender.integerValue
        case 3:
            eq.level500Hz = sender.integerValue
        case 4:
            eq.level1000Hz = sender.integerValue
        case 5:
            eq.level2000Hz = sender.integerValue
        case 6:
            eq.level4000Hz = sender.integerValue
        case 7:
            eq.level8000Hz = sender.integerValue
        default:
            break
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    fileprivate func populateEqualizer() {
        
        // get a reference to the selected Equalizer
        let eq = (txButton.state == NSOnState ? _equalizerTx : _equalizerRx)!
        
        // set the slider values
        slider0.integerValue = eq.level63Hz
        slider1.integerValue = eq.level125Hz
        slider2.integerValue = eq.level250Hz
        slider3.integerValue = eq.level500Hz
        slider4.integerValue = eq.level1000Hz
        slider5.integerValue = eq.level2000Hz
        slider6.integerValue = eq.level4000Hz
        slider7.integerValue = eq.level8000Hz
        
        // set the ON button state
        onButton.state = (eq.eqEnabled ? NSOnState : NSOffState)
    }

}
