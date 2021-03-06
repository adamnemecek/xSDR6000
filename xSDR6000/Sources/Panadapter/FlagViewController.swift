//
//  FlagViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/22/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

class FlagViewController: NSViewController {

    var flagPosition                        = NSPoint(x: 0.0, y: 0.0)
    @objc var slice                         : xLib6000.Slice?
    
    fileprivate var _params                 : Params { return representedObject as! Params }
    fileprivate var _radio                  : Radio { return _params.radio }
    fileprivate var _panadapter             : Panadapter? { return _params.panadapter }
    
    fileprivate var _center                 : Int {return _panadapter!.center }
    fileprivate var _bandwidth              : Int { return _panadapter!.bandwidth }
    fileprivate var _start                  : Int { return _center - (_bandwidth/2) }
    fileprivate var _end                    : Int  { return _center + (_bandwidth/2) }

    fileprivate var _flagPosition           = NSPoint(x: 0.0, y: 0.0)
    fileprivate var _parentView             : NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer?.backgroundColor = NSColor.lightGray.cgColor
    }
    
    func reposition() {
        
        view.setFrameOrigin(flagPosition)
    }
}
