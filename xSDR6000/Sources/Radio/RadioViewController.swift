//
//  RadioViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/14/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults
import XCGLogger

// --------------------------------------------------------------------------------
// MARK: - Radio View Controller class implementation
// --------------------------------------------------------------------------------

final class RadioViewController : NSSplitViewController, RadioPickerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    private(set) var activeRadio: RadioParameters? {                // Radio currently in use (if any)
        didSet {
            let title = (activeRadio == nil ? "" : " - Connected to \(activeRadio!.nickname ?? "") @ \(activeRadio!.ipAddress)")
            DispatchQueue.main.async {
                self.view.window?.title = "xSDR6000\(title)"
            }
        }
    }

    
    internal var radio: Radio?                                      // Radio class in use

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _selectedRadio: RadioParameters?                // Radio to start
//    fileprivate var _toolbar: NSToolbar?
    fileprivate var _sideViewController: NSSplitViewController?
    fileprivate var _panafallsViewController: PanafallsViewController?
    fileprivate var _mainWindowController: MainWindowController?
    fileprivate var _notifications = [NSObjectProtocol]()           // Notification observers
    fileprivate var _radioPickerViewController: RadioPickerViewController?  // RadioPicker sheet controller
    fileprivate var _voltageTempMonitor: ParameterMonitor?          // the Voltage/Temp ParameterMonitor

    fileprivate let _opusManager = OpusManager()
    fileprivate let _log = (NSApp.delegate as! AppDelegate)
    fileprivate let kGuiFirmwareSupport = "2.0.17.x"                // Radio firmware supported by this App
    fileprivate let kxLib6000Identifier = "net.k3tzr.xLib6000"      // Bundle identifier for xLib6000
    fileprivate let kVoltageMeter = "+13.8b"                        // Short name of voltage meter
    fileprivate let kPaTempMeter = "patemp"                         // Short name of temperature meter
    fileprivate let kVoltageTemperature = "VoltageTemp"             // Identifier of toolbar VoltageTemperature toolbarItem
    fileprivate let kSideStoryboard = "Side"                        // Storyboard names
    fileprivate let kRadioPickerIdentifier = "RadioPicker"          // Storyboard identifiers
    fileprivate let kPcwIdentifier = "PCW"
    fileprivate let kPhoneIdentifier = "Phone"
    fileprivate let kRxIdentifier = "Rx"
    fileprivate let kEqualizerIdentifier = "Equalizer"
    fileprivate let kConnectFailed = "Initial Connection failed"    // Error messages
    fileprivate let kUdpBindFailed = "Initial UDP bind failed"
    fileprivate let kVersionKey = "CFBundleShortVersionString"      // CF constants
    fileprivate let kBuildKey = "CFBundleVersion"
    
    fileprivate enum ToolbarButton: String {                        // toolbar item identifiers
        case Pan, Tnf, Markers, Remote, Speaker, Headset, VoltTemp, Side
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // give the Log object (in the API) access to our logger
        Log.sharedInstance.delegate = (NSApp.delegate as! LogHandler)
        
        // register the User defaults
        setupDefaults()
        
        // add notification subscriptions
        addNotifications()
        
        _panafallsViewController = (childViewControllers[0] as! PanafallsViewController)
        _panafallsViewController!.representedObject = self
        
        _sideViewController = childViewControllers[1] as? NSSplitViewController
        
        // show/hide the Side view
        splitViewItems[1].isCollapsed = !Defaults[.sideOpen]
        splitView.needsLayout = true
        
        // open the Radio Picker
        openRadioPicker( self)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Toolbar Action methods
    
    /// Respond to the Headphone Gain slider
    ///
    /// - Parameter sender: the Slider
    ///
    @IBAction func headphoneGain(_ sender: NSSlider) {
        
        radio?.headphoneGain = sender.integerValue
    }
    /// Respond to the Lineout Gain slider
    ///
    /// - Parameter sender: the Slider
    ///
    @IBAction func lineoutGain(_ sender: NSSlider) {
        
        radio?.lineoutGain = sender.integerValue
    }
    /// Respond to the Headphone Mute button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func muteHeadphone(_ sender: NSButton) {
        
        radio?.headphoneMute = ( sender.state == NSOnState ? true : false )
    }
    /// Respond to the Lineout Mute button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func muteLineout(_ sender: NSButton) {
        
        radio?.lineoutMute = ( sender.state == NSOnState ? true : false )
    }
    /// Respond to the Pan button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func panButton(_ sender: AnyObject) {
        
        // dimensions are dummy values; when created, will be resized to fit its view
        radio?.panafallCreate(CGSize(width: 50, height: 50))
    }
    /// Respond to the Remote Rx button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func remoteRxButton(_ sender: NSButton) {
        
        // ask the Radio (hardware) to start/stop Rx Opus
        radio?.remoteRxAudioRequest(sender.state == NSOnState)
    }
    /// Respond to the Remote Tx button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func remoteTxButton(_ sender: NSButton) {
        
        // ask the Radio (hardware) to start/stop Tx Opus
        radio?.transmit.micSelection = (sender.state == NSOnState ? "PC" : "MIC")
        
        // FIXME: This is just for testing
    }
    /// Respond to the Side button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func sideButton(_ sender: NSButton) {
        
        // open / collapse the Side view
        splitViewItems[1].isCollapsed = (sender.state != NSOnState)
    }
    /// Respond to the Tnf button
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func tnfButton(_ sender: NSButton) {
        
        // enable / disable Tnf's
        radio?.tnfEnabled = (sender.state == NSOnState)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Menu Action methods
    
    /// Respond to the Radio Selection menu, show the RadioPicker as a sheet
    ///
    /// - Parameter sender: the MenuItem
    ///
    @IBAction func openRadioPicker(_ sender: AnyObject) {
        
        // get an instance of the RadioPicker
        _radioPickerViewController = storyboard!.instantiateController(withIdentifier: kRadioPickerIdentifier) as? RadioPickerViewController
        
        // make this View Controller the delegate of the RadioPicker
        _radioPickerViewController!.representedObject = self

        DispatchQueue.main.async {
        
            // show the RadioPicker sheet
            self.presentViewControllerAsSheet(self._radioPickerViewController!)
        }
    }
    /// Respond to the xSDR6000 Quit menu
    ///
    /// - Parameter sender: the Menu item
    ///
    @IBAction func quitXFlex(_ sender: AnyObject) {
        
        NSApp.terminate(self)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Side Button Action methods
    
    /// Respond to the Eq button (Side view)
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func tabEq(_ sender: NSButton) {
        
        if sender.state == NSOnState {
            
            // create a new Equalizer UI
            let sb = NSStoryboard(name: kSideStoryboard, bundle: nil)
            
            // create an Equalizer view controller
            let vc = sb.instantiateController(withIdentifier: kEqualizerIdentifier) as! EqViewController
            
            // give it a reference to its Radio object
            vc.representedObject = radio
            
            // add it to the Side View
            _sideViewController!.insertChildViewController(vc, at: 1)
            
            // tell the SplitView to adjust
            _sideViewController!.splitView.adjustSubviews()
            
        } else {
            
            // remove it from the Side View
            for (i, vc) in _sideViewController!.childViewControllers.enumerated() where vc is EqViewController {
                _sideViewController!.removeChildViewController(at: i)
            }
        }
    }
    /// Respond to the Pcw button (Side view)
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func tabPcw(_ sender: NSButton) {
        
        if sender.state == NSOnState {
            
            // create a new Equalizer UI
            let sb = NSStoryboard(name: kSideStoryboard, bundle: nil)
            
            // create an Pcw view controller
            let vc = sb.instantiateController(withIdentifier: kPcwIdentifier) as! PCWViewController
            
            // give it a reference to its Radio object
            vc.representedObject = radio
            
            // add it to the Side View
            _sideViewController!.insertChildViewController(vc, at: 1)
            
            // tell the SplitView to adjust
            _sideViewController!.splitView.adjustSubviews()
            
        } else {
            
            // remove it from the Side View
            for (i, vc) in _sideViewController!.childViewControllers.enumerated() where vc is PCWViewController {
                _sideViewController!.removeChildViewController(at: i)
            }
        }
    }
    /// Respond to the Phne button (Side view)
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func tabPhne(_ sender: NSButton) {
        
        if sender.state == NSOnState {
            
            // create a new Equalizer UI
            let sb = NSStoryboard(name: kSideStoryboard, bundle: nil)
            
            // create an Phone view controller
            let vc = sb.instantiateController(withIdentifier: kPhoneIdentifier) as! PhoneViewController
            
            // give it a reference to its Radio object
            vc.representedObject = radio
            
            // add it to the Side View
            _sideViewController!.insertChildViewController(vc, at: 1)
            
            // tell the SplitView to adjust
            _sideViewController!.splitView.adjustSubviews()
            
        } else {
            
            // remove it from the Side View
            for (i, vc) in _sideViewController!.childViewControllers.enumerated() where vc is PhoneViewController {
                _sideViewController!.removeChildViewController(at: i)
            }
        }
    }
    /// Respond to the Rx button (Side view)
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func tabRx(_ sender: NSButton) {
        
        if sender.state == NSOnState {
            
            // create a new Equalizer UI
            let sb = NSStoryboard(name: kSideStoryboard, bundle: nil)
            
            // create an Rx view controller
            let vc = sb.instantiateController(withIdentifier: kRxIdentifier) as! NSViewController
            
            // give it a reference to its Radio object
            vc.representedObject = radio
            
            // add it to the Side View
            _sideViewController!.insertChildViewController(vc, at: 1)
            
            // tell the SplitView to adjust
            _sideViewController!.splitView.adjustSubviews()
            
        } else {
            
            // remove it from the Side View
            for (i, vc) in _sideViewController!.childViewControllers.enumerated() where vc is RxViewController {
                _sideViewController!.removeChildViewController(at: i)
            }
        }
    }
    /// Respond to the Tx button (Side view)
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func tabTx(_ sender: NSButton) {
        
        if sender.state == NSOnState {
            
            // FIXME: Code needed
            
            // show the tab
            print("txTab - SHOW")
            
        } else {
            
            // FIXME: Code needed
            
            // hide the tab
            print("txTab - HIDE")
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Setup & Register User Defaults
    ///
    fileprivate func setupDefaults() {
        
        // get the URL of the defaults file
        let defaultsUrl = Bundle.main.url(forResource: "Defaults", withExtension: "plist")!
        
        // load the contents
        let myDefaults = NSDictionary(contentsOf: defaultsUrl)!
        
        // register the defaults
        Defaults.register(defaults: myDefaults as! Dictionary<String, Any>)
    }
    /// An observed Meter has been updated
    ///
    /// - Parameter meter: the Meter
    ///
    @objc fileprivate func meterUpdated(_ note: Notification) {
        
        // if the note contains a Meter
        if let meter = note.object as? Meter {
            
            // process the update
            processMeterUpdate(meter)
        }
    }
    /// The value of a meter needs to be processed
    ///
    /// - Parameter meter: a Meter instance
    ///
    fileprivate func processMeterUpdate(_ meter: Meter) {
        
        // interact with the UI
        DispatchQueue.main.async {
            
            // if no reference to the toolbar item
            if self._voltageTempMonitor == nil {
                
                // get the toolbar
                if let toolbar = NSApp.mainWindow?.toolbar {
                    
                    // find the VoltageTemperature toolbar item
                    let items = toolbar.items.filter( {$0.itemIdentifier == self.kVoltageTemperature} )
                    
                    // there should be only one
                    if items.count == 1 {
                        
                        // save a reference to it
                        self._voltageTempMonitor = items[0] as? ParameterMonitor
                    }
                }
            }
            // if found, get the units
            if self._voltageTempMonitor != nil {
                
                // make a short version of the Units
                var shortUnits = ""
                switch meter.units.lowercased() {
                    
                case "volts":
                    shortUnits = "v"
                    
                case "degc":
                    shortUnits = "c"
                    
                case "amps":
                    shortUnits = "a"
                    
                default:
                    break
                }
                // set the value & units
                if meter.name == self.kVoltageMeter {
                    
                    // Top (Voltage), set the high / low limits
                    self._voltageTempMonitor?.topLimits.high = meter.high
                    self._voltageTempMonitor?.topLimits.low = meter.low
                    // set the value & units
                    self._voltageTempMonitor?.topUnits = shortUnits
                    self._voltageTempMonitor?.topValue = meter.value
                    
                } else if meter.name == self.kPaTempMeter {
                    
                    // Bottom (Temperature), set the high / low limits
                    self._voltageTempMonitor?.bottomLimits.high = meter.high
                    self._voltageTempMonitor?.bottomLimits.low = meter.low
                    // set the value & units
                    self._voltageTempMonitor?.bottomUnits = shortUnits
                    self._voltageTempMonitor?.bottomValue = meter.value
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // KVO
    fileprivate let _radioKeyPaths =                                // Radio keypaths to observe
        [
            #keyPath(Radio.lineoutGain),
            #keyPath(Radio.lineoutMute),
            #keyPath(Radio.headphoneGain),
            #keyPath(Radio.headphoneMute),
            #keyPath(Radio.tnfEnabled),
            #keyPath(Radio.fullDuplexEnabled)
        ]
    private let _opusKeyPaths =
        [
            #keyPath(Opus.remoteRxOn),
            #keyPath(Opus.remoteTxOn),
            #keyPath(Opus.rxStreamStopped)
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
    /// Process changes to observed keyPaths (may arrive on any thread)
    ///
    /// - Parameters:
    ///   - keyPath: the KeyPath that changed
    ///   - object: the Object of the KeyPath
    ///   - change: a change dictionary
    ///   - context: a pointer to a context (if any)
    ///
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let kp = keyPath, let ch = change {
            
            if kp != "springLoaded" {
                
                // interact with the UI
                DispatchQueue.main.async { [unowned self] in
                    
                    switch kp {
                        
                    case #keyPath(Radio.lineoutGain):
                        self._mainWindowController?.lineoutGain.integerValue = ch[.newKey] as! Int
                        
                    case #keyPath(Radio.lineoutMute):
                        self._mainWindowController?.lineoutMute.state = (ch[.newKey] as! Bool) ? NSOnState : NSOffState
                        
                    case #keyPath(Radio.headphoneGain):
                        self._mainWindowController?.headphoneGain.integerValue = ch[.newKey] as! Int
                        
                    case #keyPath(Radio.headphoneMute):
                        self._mainWindowController?.headphoneMute.state = (ch[.newKey] as! Bool) ? NSOnState : NSOffState
                        
                    case #keyPath(Radio.tnfEnabled):
                        self._mainWindowController?.tnfEnabled.state = (ch[.newKey] as! Bool) ? NSOnState : NSOffState
                        
                    case #keyPath(Radio.fullDuplexEnabled):
                        self._mainWindowController?.fdxEnabled.state = (ch[.newKey] as! Bool) ? NSOnState : NSOffState
                        
                    case #keyPath(Opus.remoteRxOn):
                        
                        if let opus = object as? Opus, let start = ch[.newKey] as? Bool{
                            
                            if start == true && opus.delegate == nil {
                                
                                // Opus starting, supply a decoder
                                self._opusManager.rxAudio(true)
                                opus.delegate = self._opusManager

                            } else if start == false && opus.delegate != nil {
                                
                                // opus stopping, remove the decoder
                                self._opusManager.rxAudio(false)
                                opus.delegate = nil
                            }
                        }
                        
                    case #keyPath(Opus.remoteTxOn):
                        
                        if let opus = object as? Opus, let start = ch[.newKey] as? Bool{
                            
                            // Tx Opus starting / stopping
                            self._opusManager.txAudio( start, opus: opus )
                        }
                        
                    case #keyPath(Opus.rxStreamStopped):
                        
                        // FIXME: Implement this
                        break
                        
                    default:
                        // log and ignore any other keyPaths
                        self._log.msg("Unknown observation - \(String(describing: keyPath))", level: .error, function: #function, file: #file, line: #line)
                    }
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subscriptions to Notifications
    ///
    fileprivate func addNotifications() {
        
        NC.makeObserver(self, with: #selector(tcpDidConnect(_:)), of: .tcpDidConnect, object: nil)

//        NC.makeObserver(self, with: #selector(tcpDidDisconnect(_:)), of: .tcpDidDisconnect, object: nil)
//
        NC.makeObserver(self, with: #selector(meterHasBeenAdded(_:)), of: .meterHasBeenAdded, object: nil)

        NC.makeObserver(self, with: #selector(radioInitialized(_:)), of: .radioInitialized, object: nil)

        NC.makeObserver(self, with: #selector(opusHasBeenAdded(_:)), of: .opusHasBeenAdded, object: nil)

        NC.makeObserver(self, with: #selector(opusWillBeRemoved(_:)), of: .opusWillBeRemoved, object: nil)
    }
    /// Process .tcpDidConnect Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tcpDidConnect(_ note: Notification) {
        
        // a tcp connection has been established
        
        // remember the active Radio
        activeRadio = _selectedRadio
        
        // get Radio model & firmware version
        Defaults[.radioFirmwareVersion] = activeRadio!.firmwareVersion!
        Defaults[.radioModel] = activeRadio!.model
        
        // get the version info for the underlying xLib6000
        let frameworkBundle = Bundle(identifier: kxLib6000Identifier)
        let apiVersion = frameworkBundle?.object(forInfoDictionaryKey: kVersionKey) ?? "0"
        let apiBuild = frameworkBundle?.object(forInfoDictionaryKey: kBuildKey) ?? "0"

        Defaults[.apiVersion] = "v\(apiVersion) build \(apiBuild)"
        
        _log.msg("Using xLib6000 version " + Defaults[.apiVersion], level: .info, function: #function, file: #file, line: #line)
        
        Defaults[.apiFirmwareSupport] = radio!.kApiFirmwareSupport
        
        // get the version info for this app
        let appVersion = Bundle.main.object(forInfoDictionaryKey: kVersionKey) ?? "0"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: kBuildKey) ?? "0"

        Defaults[.guiVersion] = "v\(appVersion) build \(appBuild)"
        Defaults[.guiFirmwareSupport] = kGuiFirmwareSupport

        // observe changes to Radio properties
        observations(radio!, paths: _radioKeyPaths)
    }
    /// Process .tcpDidDisconnect Notification
    ///
    /// - Parameter note: a Notification instance
    ///
//    @objc fileprivate func tcpDidDisconnect(_ note: Notification) {
//        
//        // the TCP connection has disconnected
//        if (note.object as! Radio.DisconnectReason) != .closed {
//            
//            // not a normal disconnect
//            openRadioPicker(self)
//        }
//    }
    /// Process .meterHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func meterHasBeenAdded(_ note: Notification) {

        if let meter = note.object as? Meter {
            
            // is it one we need to watch?
            if meter.name == self.kVoltageMeter || meter.name == self.kPaTempMeter {
                
                // YES, process the initial meter reading
                processMeterUpdate(meter)
                
                // subscribe to its updates
                NC.makeObserver(self, with: #selector(meterUpdated(_:)), of: .meterUpdated, object: meter)
            }
        }
    }
    /// Process .radioInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func radioInitialized(_ note: Notification) {
        
        // the Radio class has been initialized
        if let radio = note.object as? Radio {
            
            DispatchQueue.main.async { [unowned self] in
                
                // Get a reference to the Window Controller containing the toolbar items
                self._mainWindowController = self.view.window?.windowController as? MainWindowController
                
                // Initialize the toolbar items
                self._mainWindowController?.lineoutGain.integerValue = radio.lineoutGain
                self._mainWindowController?.lineoutMute.state = radio.lineoutMute ? NSOnState : NSOffState
                self._mainWindowController?.headphoneGain.integerValue = radio.headphoneGain
                self._mainWindowController?.headphoneMute.state = radio.headphoneMute ? NSOnState : NSOffState
                self._mainWindowController?.window?.viewsNeedDisplay = true
            }
        }
    }
    /// Process .opusHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func opusHasBeenAdded(_ note: Notification) {
        
        // the Opus class has been initialized
        if let opus = note.object as? Opus {
            
            DispatchQueue.main.async { [unowned self] in
                
                // add Opus property observations
                self.observations(opus, paths: self._opusKeyPaths)
            }
        }
    }
    /// Process .opusWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func opusWillBeRemoved(_ note: Notification) {
        
        // an Opus class will be removed
        if let opus = note.object as? Opus {
            
            DispatchQueue.main.async { [unowned self] in
                
                // remove Opus property observations
                self.observations(opus, paths: self._opusKeyPaths, remove: true)
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - RadioPickerDelegate methods
    
    /// Stop the active Radio
    ///
    func closeRadio() {
        
        // remove observations of Radio properties
        observations(radio!, paths: _radioKeyPaths, remove: true)
        
        // perform an orderly close of the Radio resources
        radio?.disconnect()
        
        // remove the active Radio
        activeRadio = nil
    }
    /// Connect / Disconnect the selected Radio
    ///
    /// - Parameter selectedRadio: the RadioParameters
    ///
    func openRadio(_ selectedRadio: RadioParameters?) -> Bool {

        // close the Radio Picker (if open)
        closeRadioPicker()
        
        self._selectedRadio = selectedRadio
        
        if selectedRadio != nil && selectedRadio! == activeRadio {
            
            // Disconnect the active Radio
            closeRadio()
            
        } else if selectedRadio != nil {
            
            // Disconnect the active Radio & Connect a different Radio
            if activeRadio != nil {
                
                // Disconnect the active Radio
                closeRadio()
            }
            // Create a Radio class
            radio = Radio(radioParameters: selectedRadio!, clientName: kClientName, isGui: true)
            
            // start a connection to the Radio
            if !radio!.connect(selectedRadio: selectedRadio!) {
                
                // connect failed, log the error and return
                self._log.msg(kConnectFailed, level: .error, function: #function, file: #file, line: #line)
                
                return false        // Connect failed
            }
            return true             // Connect succeeded
        }
        return false                // no radio selected
    }
    /// Close the RadioPicker sheet
    ///
    func closeRadioPicker() {
        
        // close the RadioPicker
        if _radioPickerViewController != nil { dismissViewController(_radioPickerViewController!) ; _radioPickerViewController = nil }
    }

}
