//
//  Gradient.swift
//  xSDR6000
//
//  Created by Douglas Adams on 8/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa

// --------------------------------------------------------------------------------
// MARK: - Gradient class implementation
// --------------------------------------------------------------------------------

final class Gradient {
    
    enum GradientType: String {
        case basic
        case dark
        case deuteranopia
        case grayscale
        case purple
        case tritanopia
    }
    static let names = [
        GradientType.basic.rawValue,
        GradientType.dark.rawValue,
        GradientType.deuteranopia.rawValue,
        GradientType.grayscale.rawValue,
        GradientType.purple.rawValue,
        GradientType.tritanopia.rawValue
    ]

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var gradient                                : NSGradient!
        
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _lowThreshold                   : UInt16 = 0            // low Threshold
    private var _highThreshold                  : UInt16 = 0            // high Threshold
    private var _intensityRange                 : Float = 0.0           // high - low threshold
    
    private let kDefault                        = GradientType.basic    // default Gradient
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(_ index: Int) {
        loadGradient(index)
    }
    /// Load the Gradient at the specified Index
    ///
    /// - Parameter index:   Gradient index
    ///
    func loadGradient(_ index: Int) {
        
        // is the Gradient index valid?
        if (0..<Gradient.names.count).contains(index) {
            
            // YES, load the indexed Gradient
            loadGradient( GradientType(rawValue: Gradient.names[index])! )
            
        } else {
            
            // NO, load the default
            loadGradient(kDefault)
        }
    }
    /// Load the specified Gradient
    ///
    /// - Parameter type:   Gradient type
    ///
    func loadGradient(_ type: GradientType) {
        
        switch type {
        case .basic:
            gradient = NSGradient.basic
            
        case .dark:
            gradient = NSGradient.dark
            
        case .deuteranopia:
            gradient = NSGradient.deuteranopia
            
        case .grayscale:
            gradient = NSGradient.grayscale
            
        case .purple:
            gradient = NSGradient.purple
            
        case .tritanopia:
            gradient = NSGradient.tritanopia
        }
    }
    /// Convert an intensity into a color value
    ///
    /// - Parameters:
    ///   - intensity:      the Intensity
    /// - Returns:          a bgra8Norm color from the Gradient
    ///
    func value(_ intensity: UInt16) -> UInt32 {
        //
        // Note:    The Gradients created by the extensions on NSGradient (basic, dark, etc.)
        //          are formatted internally in rgba format however when they are accessed
        //          in the value(:) method they return a bgra8Unorm since this is the native
        //          format of the Metal framebuffer where they are used (in WaterfallLayer).
        //        
        var index: CGFloat = 0.0
        
        if (intensity <= _lowThreshold) {
            
            // below blackLevel
            index = 0
            
        } else if (intensity >= _highThreshold) {
            
            // above highLevel
            index = 1.0
            
        } else {
        
            index = (CGFloat(intensity - _lowThreshold) / CGFloat(_intensityRange))
        }
        // return the interpolated color in a UInt32 (in bgra format)
        return gradient.interpolatedColor(atLocation: index).bgra8Unorm
    }
    /// Calculate the High & Low threshold values
    ///
    /// - Parameters:
    ///   - autoBlackEnabled:   true = enabled
    ///   - autoBlackLevel:     autoBlackLevel from Radio
    ///   - blackLevel:         manual blackLevel
    ///   - colorGain:          colorGain setting
    ///
    func calcLevels(autoBlackEnabled: Bool, autoBlackLevel: UInt32, blackLevel: Int, colorGain: Int) {
        
        // autoBlack enabled?
        if autoBlackEnabled {
            // YES, use the Radio's auto blackLevel
            _lowThreshold = UInt16(autoBlackLevel)
        
        } else {
            // NO, calculate a level based on the BlackLevel setting
            _lowThreshold = calcLowThreshold(blackLevel)
        }
        // calculate the High threshold values
        _highThreshold = calcHighThreshold(_lowThreshold, colorGain: colorGain)

        // save the range
        _intensityRange = Float(_highThreshold - _lowThreshold)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    // Note:    These calculations are patterned after the calculations provided by Flex Radio
    
    /// Calculate the Low end of the Gradient Color dynamic range
    ///
    /// - Parameter blackLevel:     the BlackLevel (0 - 100)
    /// - Returns:                  the Low Threshold
    ///
    fileprivate func calcLowThreshold(_ blackLevel: Int) -> UInt16 {
        
        // map the 0-100 Black Level to an inverted 1.0 - 0.0
        let invertedNormalizedBlackLevel = 1 - Double(blackLevel)/100.0
        
        // remap the value to give extra dynamic range on the low end of the slider
        //      NOTE: this leaves the values from 75-100 with no change
        let stretchedNormalizedBlackLevel = pow(invertedNormalizedBlackLevel, 8)
        
        return UInt16(stretchedNormalizedBlackLevel * Double(UInt16.max - 10_000))
    }
    /// Calculate the High end of the Gradient Color dynamic range
    ///
    /// - Parameter blackLevel:     the Low Threshold
    /// - Returns:                  the High Threshold
    ///
    fileprivate func calcHighThreshold(_ lowThreshold: UInt16, colorGain: Int) -> UInt16 {
        
        // adjust high boundary from low + margin to max X^3 pattern
        // move from 0-100 space into [1, cuberoot(2^16) space]
        let temp1 = ( 100 - Double(colorGain))/100.0 * pow(Double(UInt16.max - lowThreshold), 1.0/3.0)
        
        // now scale the value using the new value
        let temp2 = lowThreshold + UInt16(pow(temp1, 3))
        
        // make sure that highThreshold > lowThreshold
        return (temp2 < lowThreshold + 100) ? lowThreshold + 100 : temp2
    }
}
