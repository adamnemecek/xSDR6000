//
//  BandButtonViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/8/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

class BandButtonViewController : NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet fileprivate weak var bandButtons: NSMatrix!

    fileprivate var _params: Params { return representedObject as! Params }
    
//    fileprivate var _radio: Radio { return _params.radio }
    fileprivate var _panadapter: Panadapter? { return _params.panadapter }
//    fileprivate var _waterfall: Waterfall? { return _params.waterfall }

    fileprivate var _b = Band.sharedInstance
    
    fileprivate let kNumberOfColumns = 3
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // there is 1 row of kNumberOfColumns buttons by default
        let buttonsToAdd: Int = _b.sortedBands.count - kNumberOfColumns
        var rowsToAdd: Int = buttonsToAdd / kNumberOfColumns
        let cellsToAdd: Int = buttonsToAdd % kNumberOfColumns
        rowsToAdd = (rowsToAdd + (cellsToAdd > 0 ? 1 : 0))
        
        // add needed rows
        for _ in 1...rowsToAdd {
            
            bandButtons.addRow()
        }
        // resize the NSMatrix (constraints will resize the View)
        bandButtons.sizeToCells()

        for row in 0..<bandButtons.numberOfRows {
            
            for col in 0..<bandButtons.numberOfColumns {
                
                let cell = bandButtons.cell(atRow: row, column: col)
                let index = (row * kNumberOfColumns + col)
                if index < _b.sortedBands.count {
                    
                    // populate the button's Title
                    cell!.title = _b.sortedBands[index]
                
                } else {
                    
                    // disable unused buttons (in the last row)
                    cell!.isEnabled = false
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func buttonPush(_ sender: NSMatrix) {
        var band = sender.selectedCell()!.title

        // handle the special cases
        switch  band {
        
        case "WWV":
            band = "33"
        
        case "GEN":
            band = "34"
        
        default:
            break
        }
        // tell the Panadapter
        _panadapter!.band = band
    }

}
