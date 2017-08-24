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

typealias GradientArray = [GLuint]

final class Gradient {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var gradients = [String: URL]()                     // dictionary of Gradients [name : URL]
    var autoBlackLevel: UInt32 = 0

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _gradient: GradientArray?
    private var _lowThreshold : UInt16 = 0              // low Threshold
    private var _highThreshold : UInt16 = 0             // high Threshold
    
    private let kGradientSize = 256                     // number of steps in Gradient
    private let kRgbaBlack : GLuint = 0xFF000000        // Black in RGBA format
    private let kRgbaWhite : GLuint = 0xFFFFFFFF        // White in RGBA format

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init?(_ name: String) {

        // find all of the *.tex resources
        let gradientURLs = Bundle.urls(forResourcesWithExtension: "tex", subdirectory: nil, in: Bundle.main.bundleURL) ?? [URL]()
        
        // build the gradients dictionary
        for url in gradientURLs {
            
            // separate the name from the extension
            let gradientName = url.lastPathComponent.components(separatedBy: ".")[0]
            
            // get the name
            gradients[gradientName] = url
        }
        
        if gradients[name] == nil { return nil }
        
        loadGradient(name)
        
    }
    
    func loadGradient(_ name: String) {
        
        // find the URL (if any)
        guard let gradientURL = gradients[name] else {
            _gradient = nil
            return
        }
        // get the URL's data (if any)
        if let gradientData = try? Data(contentsOf: gradientURL) {
            _gradient = [GLuint](repeating: 0, count: kGradientSize)
            
            // copy the data and return it
            let _ = gradientData.copyBytes(to: UnsafeMutableBufferPointer(start: &_gradient, count: kGradientSize))
        }
        _gradient = nil
    }
    /// Convert an intensity into a Gradient value
    ///
    /// - Parameters:
    ///   - intensity:      the Intensity
    /// - Returns:          the value from the Gradient
    ///
    func value(_ intensity: UInt16) -> GLuint {
        var gradientValue: GLuint = 0
        
        if (intensity <= _lowThreshold) {
            
            // below blackLevel
            gradientValue = _gradient?[0] ?? 0
            
        } else if (intensity >= _highThreshold) {
            
            // above highLevel
            gradientValue = _gradient?[kGradientSize - 1] ?? 0
            
        } else {
            
            let diff = Float(intensity - _lowThreshold)
            let range = Float(_highThreshold - _lowThreshold)
            let gradientIndex = Int((diff / range) * Float(kGradientSize))
            
            // get the color based on an adjusted Intensity (spread over the high-low threshold range)
            gradientValue = _gradient?[gradientIndex] ?? 0
        }
        return gradientValue
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
        var effectiveBlackLevel = Int(autoBlackLevel)
        if autoBlackEnabled { effectiveBlackLevel = Int( (Float(autoBlackLevel)  / Float(UInt16.max - UInt16(autoBlackLevel))) * 130 ) }
        
        // calculate the Threshold values
        _lowThreshold = calcLowThreshold(effectiveBlackLevel)
        _highThreshold = calcHighThreshold(_lowThreshold, colorGain: colorGain)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Calculate the Low end of the Gradient Color dynamic range
    ///
    /// - Parameter blackLevel:     the BlackLevel
    /// - Returns:                  the Low Threshold
    ///
    fileprivate func calcLowThreshold(_ blackLevel: Int) -> UInt16 {
        
        // map the 0-100 Black Level to an inverted 1.0 - 0.0
        let invertedNormalizedBlackLevel = 1 - Double(blackLevel)/100
        
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
        let temp1 = (1 - Double(colorGain)/100) * pow(Double(UInt16.max - lowThreshold), 1.0/3.0)
        
        // now scale the value using the new value
        let temp2 = lowThreshold + UInt16(pow(temp1, 3))
        
        // make sure that highThreshold > lowThreshold
        return (temp2 < lowThreshold + 100) ? lowThreshold + 100 : temp2
    }
}
