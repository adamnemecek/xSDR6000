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
    
    fileprivate var _params: Params { return representedObject as! Params }
    
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _view: MTKView!
    private var _renderer: PanadapterRenderer!
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _view = self.view as! MTKView
        _view.device = MTLCreateSystemDefaultDevice()
        
        guard _view.device != nil else {
            fatalError("Metal is not supported on this device")
        }
        
        _renderer = PanadapterRenderer(mtkView: _view)
        
        guard _renderer != nil else {
            fatalError("Renderer failed initialization")
        }
        
        _view.delegate = _renderer
//        _view.preferredFramesPerSecond = 60

        _panadapter?.delegate = _renderer
    }

    /// View did layout
    ///
    override func viewDidLayout() {
        
        // tell the Panadapter to tell the Radio the current dimensions
        _panadapter?.panDimensions = CGSize(width: _view.frame.width, height: _view.frame.height)
        
        Swift.print("\(_view.frame.width), \(_view.frame.height)")
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
}

