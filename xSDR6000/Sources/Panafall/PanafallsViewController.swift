//
//  PanafallsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 4/30/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

typealias Params = (radio: Radio, panadapter: Panadapter?, waterfall: Waterfall?)     // Radio & Panadapter references

class PanafallsViewController: NSSplitViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _notifications = [NSObjectProtocol]()                   // Notification observers
    fileprivate var _radioViewController: RadioViewController! { return representedObject as! RadioViewController }
        
    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)

    fileprivate let kPanafallStoryboard = "Panafall"                        // Storyboard names
    
    fileprivate let kPanafallButtonIdentifier = "Button"                    // Storyboard identifiers
    fileprivate let kPanadapterIdentifier = "Panadapter"
    fileprivate let kWaterfallIdentifier = "Waterfall"
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add notification subscriptions
        addNotifications()
    }
        
    // ----------------------------------------------------------------------------
    // MARK: - Public methods

    /// Redraw the FrequencyLegends on all Panadapters
    ///
    func redrawAllFrequencyLegends() {
        
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawFrequencyLegend() }
    }
    /// Redraw the DbLegend on all Panadapters
    ///
    func redrawAllDbLegends() {
        
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawDbLegend() }
    }
    /// Redraw the Slices on all Panadapters
    ///
    /// Redraw all Panadapters (all components)
    ///
    open func redrawAll() {
        
        // force a redraw of each Panafall
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawAll() }
    }    
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods

    fileprivate let _panadapterKeyPaths =                   // Panadapter keypaths to observe
        [
            #keyPath(Panadapter.center),
            #keyPath(Panadapter.bandwidth),
            #keyPath(Panadapter.minDbm),
            #keyPath(Panadapter.maxDbm)
    ]
//    fileprivate let _waterfallKeyPaths =                    // Waterfall keypaths to observe
//        [
//            #keyPath(Waterfall.autoBlackEnabled),
//            #keyPath(Waterfall.blackLevel),
//            #keyPath(Waterfall.colorGain),
//            #keyPath(Waterfall.gradientIndex)
//    ]
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
        
        // what is the object?
        switch object {
        
        case is Panadapter:
            
            // get the Panadapter
            let pan = object as! Panadapter
            
            // find the viewController
            var panafallButtonVc: PanafallButtonViewController?
            for vc in childViewControllers {
                if ((vc as! PanafallButtonViewController).representedObject as! Params).panadapter == pan {
                    panafallButtonVc = vc as? PanafallButtonViewController
                    break
                }
            }
            
            switch keyPath! {
            case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
                panafallButtonVc?.redrawFrequencyLegend()
                panafallButtonVc?.redrawSlices()
                
            case #keyPath(Panadapter.minDbm), #keyPath(Panadapter.maxDbm):
                panafallButtonVc?.redrawDbLegend()
                
            default:
                _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
            }
            
//        case is Waterfall:
//            
//            let waterfall = object as! Waterfall
//            
//            switch keyPath! {
//                
//            case #keyPath(Waterfall.gradientIndex):
//                // load the new Gradient & recalc the levels
//                _waterfallGradient.loadGradient(waterfall)
//                fallthrough
//                
//            case #keyPath(Waterfall.autoBlackEnabled), #keyPath(Waterfall.blackLevel), #keyPath(Waterfall.colorGain):
//                // recalc the levels
//                _waterfallGradient.calcLevels(waterfall)
//                
//            default:
//                _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
//            }
            
        default:
            break
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    fileprivate func addNotifications() {
        
        // Panadapter initialized
        NC.makeObserver(self, with: #selector(panadapterHasBeenAdded(_:)), of: .panadapterHasBeenAdded, object: nil)

        // Panadapter will be removed
        NC.makeObserver(self, with: #selector(panadapterWillBeRemoved(_:)), of: .panadapterWillBeRemoved, object: nil)

        // Waterfall initialized
        NC.makeObserver(self, with: #selector(waterfallHasBeenAdded(_:)), of: .waterfallHasBeenAdded, object: nil)

        // Waterfall will be removed
        NC.makeObserver(self, with: #selector(waterfallWillBeRemoved(_:)), of: .waterfallWillBeRemoved, object: nil)
    }
    //
    //  Panafall creation:
    //
    //      Step 1 .panadapterInitialized
    //      Step 2 .waterfallInitialized
    //
    /// Process .panadapterHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterHasBeenAdded(_ note: Notification) {
        // a Panadapter model has been added to the Panadapters collection and Initialized
        
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            
            // YES, log the event
            _log.msg("ID = \(panadapter.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // observe changes to Panadapter properties
            observations(panadapter, paths: _panadapterKeyPaths)
            
            // interact with the UI
            DispatchQueue.main.async { [unowned self] in
                
                // get the Storyboard containing a Panafall Button View Controller
                let sb = NSStoryboard(name: self.kPanafallStoryboard, bundle: nil)
                
                // create a Panafall Button View Controller
                let panafallButtonVc = sb.instantiateController(withIdentifier: self.kPanafallButtonIdentifier) as! PanafallButtonViewController
                
                // setup the Params tuple
                panafallButtonVc.representedObject = Params(radio: self._radioViewController.radio!, panadapter: panadapter, waterfall: nil)
                
                // add PanafallButtonViewController to the PanafallsViewController
                self.addChildViewController(panafallButtonVc)
                
                // tell the SplitView to adjust
                self.splitView.adjustSubviews()
            }
        }
    }
    /// Process .waterfallHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallHasBeenAdded(_ note: Notification) {
        // a Waterfall model has been added to the Waterfalls collection and Initialized
        
        // does the Notification contain a Panadapter?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _log.msg("ID = \(waterfall.id)", level: .debug, function: #function, file: #file, line: #line)

//            // observe changes to Waterfall properties
//            observations(waterfall, paths: _waterfallKeyPaths)

//            // find the Panafall Button View Controller for the Panafall containing the Waterfall
//            for vc in self.childViewControllers where (((vc as! PanafallButtonViewController).representedObject) as! Params).panadapter!.id == waterfall.panadapterId {
//                
//                // add the waterfall to the params
//                var params = ((vc as! PanafallButtonViewController).representedObject as! Params)
//                params.waterfall = waterfall
//                (vc as! PanafallButtonViewController).representedObject = params                
//            }
        }
    }
    //
    //  Panafall removal:
    //
    //      Step 1 .panadapterWillBeRemoved
    //      Step 2 .waterfallWIllBeRemoved
    //
    /// Process .panadapterWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterWillBeRemoved(_ note: Notification) {
        // a Panadapter model has been marked for removal and will be removed from the Panadapters collection
        
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            
            // YES, log the event
            _log.msg("ID = \(panadapter.id)", level: .debug, function: #function, file: #file, line: #line)

            // remove Panadapter property observers
            observations(panadapter, paths: _panadapterKeyPaths, remove: true)

            panadapter.delegate = nil
        }
    }
    /// Process .waterfallWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallWillBeRemoved(_ note: Notification) {
        // a Waterfall model has been marked for removal and will be removed from the Waterfalls collection
        
        // does the Notification contain a Waterfall?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _log.msg("ID = \(waterfall.id)", level: .debug, function: #function, file: #file, line: #line)
            
//            // remove Waterfall property observers
//            observations(waterfall, paths: _waterfallKeyPaths, remove: true)
            
            waterfall.delegate = nil

            // interact with the UI
            DispatchQueue.main.async { [unowned self] in
                
                // get the Panadapter Id for this Waterfall
                let panadapterId = waterfall.panadapterId
                
                // find the Panafall Button View Controller for the Panafall containing the Waterfall
                for vc in self.childViewControllers where (((vc as! PanafallButtonViewController).representedObject) as! Params).panadapter!.id == panadapterId {
                    
                    let panafallButtonVc = vc as! PanafallButtonViewController
                    
                    // remove the entire PanafallButtonViewController
                    panafallButtonVc.removeFromParentViewController()
                    panafallButtonVc.dismiss(self)
                }
            }
        }
    }
}
