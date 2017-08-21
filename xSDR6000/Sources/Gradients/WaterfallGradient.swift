//
//  WaterfallGradient.swift
//  xSDR6000
//
//  Created by Douglas Adams on 3/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Waterfall Gradient class implementation
// --------------------------------------------------------------------------------

final class WaterfallGradient {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var gradientURLs = [URL]()
    var gradientNames: [String] { return names(gradientURLs) }
    var autoBlackLevel: UInt32 = 0
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    var _gradients = [String : [GLuint]]()              // dictionary of Gradient data
    var _lowThresholds = [String : UInt16]()            // dictionary of low Thresholds
    var _highThresholds = [String : UInt16]()           // dictionary of high Thresholds
    var _gradientDatum = [String : Data?]()             // dictionary of gradient file data
    
    let kGradientSize = 256                             // number of steps in Gradient
    let kRgbaBlack : GLuint = 0xFF000000                // Black in RGBA format
    let kRgbaWhite : GLuint = 0xFFFFFFFF                // White in RGBA format
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    /// Provide access to the Gradient singleton
    ///
    public static var sharedInstance = WaterfallGradient()
    
    fileprivate init() {
        // "private" prevents others from calling init()

        // load the URL's of the available Gradients
        gradientURLs = loadGradientURLs()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Find the URLs of the available Gradients
    ///
    /// - Returns:  an array of URL's
    ///
    func loadGradientURLs() -> [URL] {
        
        // find all of the *.tex resources
        return Bundle.urls(forResourcesWithExtension: "tex", subdirectory: nil, in: Bundle.main.bundleURL) ?? [URL]()
    }
    /// Load Gradient data for a given URL & Waterfall Id
    ///
    /// - Parameters:
    ///   - url:        the URL of a Gradient
    ///   - id:         the id of the Waterfall
    ///
    func loadGradient(_ url: URL, id: String) {
        var gradientData: Data
        
        // get the URL's data (if any)
        do {
            try gradientData = Data(contentsOf: url as URL)
        }
        catch {
            fatalError("Unable to load Gradient data")
        }
        // create an array to hold gradient data
        var gradientArray = [GLuint](repeating: 0, count: kGradientSize)
        
        // copy the data to the array and put it in the dictionary
        let _ = gradientData.copyBytes(to: UnsafeMutableBufferPointer(start: &gradientArray, count: kGradientSize))
        _gradients[id] = gradientArray
    }
    /// Load a Gradient given its Nam
    ///
    /// - Parameter name:   a Waterfall instance
    ///
    func loadGradient(_ waterfall: Waterfall) {
        
        // get the name of the selected Gradient
        let name = gradientNames[waterfall.gradientIndex]
        
        // if name found, try to load the Gradient
        for url in gradientURLs where url.lastPathComponent == name + ".tex" {
            // if data found, get it
            loadGradient(_ : url, id: waterfall.id)
        }
    }
    /// Convert an intensity into a Gradient value
    ///
    /// - Parameters:
    ///   - intensity:      the Intensity
    ///   - id:             the id of the Waterfall
    /// - Returns:          the value from the Gradient
    ///
    func value(_ intensity: UInt16, id: String) -> GLuint {
        var gradientValue: GLuint = 0
        
        if let lowThreshold = _lowThresholds[id], let highThreshold = _highThresholds[id], let gradient = _gradients[id] {
            
            if (intensity <= lowThreshold) {
                
                // below blackLevel
                //            gradientValue = _gradient?[0] ?? kRgbaBlack
                gradientValue = gradient[0] 
                
            } else if (intensity >= highThreshold) {
                
                // above highLevel
                //            gradientValue = _gradient?[kGradientSize - 1] ?? kRgbaWhite
                gradientValue = gradient[kGradientSize - 1]
                
            } else {
                
                let diff = Float(intensity - lowThreshold)
                let range = Float(highThreshold - lowThreshold)
                let gradientIndex = Int((diff / range) * Float(kGradientSize))
                
                // get the color based on an adjusted Intensity (spread over the high-low threshold range)
                //            gradientValue = _gradient?[gradientIndex] ?? kRgbaBlack
                gradientValue = gradient[gradientIndex] 
            }
        }
//        print("i = \(intensity), range = \(_lowThreshold) to \(_highThreshold), value = \(gradientValue)")
        
        return gradientValue
    }
    /// Calculate the High & Low threshold values
    ///
    /// - Parameter waterfall:  a Waterfall instance
    ///
    func calcLevels(_ waterfall: Waterfall) {
        var effectiveBlackLevel = waterfall.blackLevel
        
        if waterfall.autoBlackEnabled { effectiveBlackLevel = Int( (Float(waterfall.autoBlackLevel)  / Float(UInt16.max - UInt16(waterfall.autoBlackLevel))) * 130 ) }
        
//        print("auto = \(autoBlack), autoLevel = \(autoBlackLevel), blackLevel = \(blackLevel), colorGain = \(colorGain), eff = \(effectiveBlackLevel)")
        let id = waterfall.id
        
        // calculate the Manual Threshold values
        _lowThresholds[id] = calcLowThreshold(effectiveBlackLevel)
        _highThresholds[id] = calcHighThreshold(_lowThresholds[id]!, colorGain: waterfall.colorGain)
        
//        print("low = \(_lowThreshold), high = \(_highThreshold)\n")
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Return a list of the Gradient names
    ///
    /// - Parameter urls:   an array of Gradient URL's
    /// - Returns:          an array of Gradient Names
    ///
    fileprivate func names(_ urls: [URL]) -> [String] {
        var names = [String]()
        
        for url in gradientURLs {
            
            // get the file name
            let fileName = url.lastPathComponent
            
            // separate the name from the extension
            let components = fileName.components(separatedBy: ".")
                
            // get the name
            names.append(components[0])
        }
        return names
    }
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
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Delegate methods
    
    
}
