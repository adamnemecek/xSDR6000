//
//  WaterfallLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import MetalKit
import xLib6000
import SwiftyUserDefaults

public final class WaterfallLayer: CAMetalLayer, CALayerDelegate, WaterfallStreamHandler {





    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Draw in a Metal layer
    ///
    public func render() {


    }



    
    // ----------------------------------------------------------------------------
    // MARK: - WaterfallStreamHandler protocol methods
    //
    
    //  dataFrame Struct Layout: (see xLib6000 WaterfallFrame)
    //
    //  public var firstBinFreq: CGFloat                        // Frequency of first Bin in Hz
    //  public var binBandwidth: CGFloat                        // Bandwidth of a single bin in Hz
    //  public var lineDuration: Int                            // Duration of this line in ms (1 to 100)
    //  public var lineHeight: Int                              // Height of frame in pixels
    //  public var autoBlackLevel: UInt32                       // Auto black level
    //  public var numberOfBins: Int                            // Number of bins
    //  public var bins: [UInt16]                               // Array of bin values
    //
    
    /// Process the UDP Stream Data for the Waterfall (called on the waterfallQ)
    ///
    /// - Parameter dataFrame:  a waterfall dataframe struct
    ///
    public func waterfallStreamHandler(_ dataFrame: WaterfallFrame ) {
        

        
        
        // interact with the UI
        DispatchQueue.main.async { [unowned self] in
            
            // force a redraw of the Waterfall
            self.setNeedsDisplay()
        }
    }
}
