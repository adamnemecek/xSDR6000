//
//  Gradient.swift
//  xSDR6000
//
//  Created by Douglas Adams on 8/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

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
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var colorMap: NSGradient!
    
    static let names = [
        GradientType.basic.rawValue,
        GradientType.dark.rawValue,
        GradientType.deuteranopia.rawValue,
        GradientType.grayscale.rawValue,
        GradientType.purple.rawValue,
        GradientType.tritanopia.rawValue
    ]
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _lowThreshold: UInt16 = 0              // low Threshold
    private var _highThreshold: UInt16 = 0             // high Threshold
    private var _intensityRange: Float = 0.0
    
    private let kDefault = GradientType.basic

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(_ index: Int) {
        loadMap(index)
    }
    /// Load the Gradient at the specified Index
    ///
    /// - Parameter index:   Gradient index
    ///
    func loadMap(_ index: Int) {
        // is the Gradient index valid?
        if index > 0 && index < Gradient.names.count {
            
            // YES, load it (by index)
            loadMap( GradientType(rawValue: Gradient.names[index])! )
            
        } else {
            
            // NO, load it (by name)
            loadMap(kDefault)
        }
    }
    /// Load the specified Gradient Type
    ///
    /// - Parameter type:   Gradient type
    ///
    func loadMap(_ type: GradientType) {
        
        switch type {
        case .basic:
            colorMap = NSGradient.basic
            
        case .dark:
            colorMap = NSGradient.dark
            
        case .deuteranopia:
            colorMap = NSGradient.deuteranopia
            
        case .grayscale:
            colorMap = NSGradient.grayscale
            
        case .purple:
            colorMap = NSGradient.purple
            
        case .tritanopia:
            colorMap = NSGradient.tritanopia
        }
    }
    /// Convert an intensity into a Gradient value
    ///
    /// - Parameters:
    ///   - intensity:      the Intensity
    /// - Returns:          a GL_RGBA color from the Gradient
    ///
    func value(_ intensity: UInt16) -> GLuint {
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
        
        let color = colorMap.interpolatedColor(atLocation: index)
        
        let red = UInt8(color.redComponent * 255.0)
        let green = UInt8(color.greenComponent * 255.0)
        let blue = UInt8(color.blueComponent * 255.0)
        let alpha = UInt8(color.alphaComponent * 255.0)
        
        let alphax = GLuint(alpha) << 24
        let bluex = GLuint(blue) << 16
        let greenx = GLuint(green) << 8
        let redx = GLuint(red)
        
        // return the GLuint (in GL_RGBA format)
        return alphax + bluex + greenx + redx
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

        // calculate the "effective" blackLevel
        let effectiveBlackLevel = (autoBlackEnabled ? Int( Float(autoBlackLevel)  / Float(UInt16.max) * 100 ) : blackLevel)
        
        // calculate the Threshold values
        _lowThreshold = calcLowThreshold(effectiveBlackLevel)
        _highThreshold = calcHighThreshold(_lowThreshold, colorGain: colorGain)

        _intensityRange = Float(_highThreshold - _lowThreshold)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
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
