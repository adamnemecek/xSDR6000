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

class PanadapterViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet weak var _spectrumView: MTKView!
    @IBOutlet weak var _frequencyLegendView: NSView!
    @IBOutlet weak var _dbLegendView: NSView!
    
    fileprivate var _params: Params { return representedObject as! Params }
    
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
    
    // constants
    fileprivate let _log                    = (NSApp.delegate as! AppDelegate)
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _renderer: PanadapterRenderer!
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
    }

    /// View did layout
    ///
    override func viewDidLayout() {
        
        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: _spectrumView.frame.width, height: _spectrumView.frame.height)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    fileprivate let _defaultsKeyPaths = [             // Defaults keypaths to observe
        "gridLines",
        "spectrum",
        "spectrumBackground",
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
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case "gridLines", "spectrum":
            _renderer.updateUniforms()
            
        case "spectrumBackground":
            _renderer.setClearColor()
            
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
            }
        }
    }
}

