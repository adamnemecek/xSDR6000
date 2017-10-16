//
//  ApExtensions.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/22/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults
import simd

typealias NC = NotificationCenter

// ------------------------------------------------------------------------------
// MARK: - Extensions
// ------------------------------------------------------------------------------

extension UserDefaults {
    
    subscript(key: DefaultsKey<NSColor>) -> NSColor {
        get { return unarchive(key)! }
        set { archive(key, newValue) }
    }

    public subscript(key: DefaultsKey<CGFloat>) -> CGFloat {
        get { return CGFloat(numberForKey(key._key)?.doubleValue ?? 0.0) }
        set { set(key, Double(newValue)) }
    }
}

extension DefaultsKeys {

    // Radio level info
    static let apiFirmwareSupport = DefaultsKey<String>("apiFirmwareSupport")
    static let apiVersion = DefaultsKey<String>("apiVersion")
    static let defaultRadioParameters = DefaultsKey<[String]>("defaultRadioParameters") // obsolete
    static let defaultsDictionary = DefaultsKey<[String: Any]>("defaultsDictionary")
    static let guiFirmwareSupport = DefaultsKey<String>("guiFirmwareSupport")
    static let guiVersion = DefaultsKey<String>("guiVersion")
    static let logNumber = DefaultsKey<Int>("logNumber")
    static let openGLVersion = DefaultsKey<String>("openGLVersion")
    static let radioFirmwareVersion = DefaultsKey<String>("radioFirmwareVersion")
    static let radioModel = DefaultsKey<String>("radioModel")
    static let remoteRxEnabled = DefaultsKey<Bool>("remoteRxEnabled")
    static let remoteTxEnabled = DefaultsKey<Bool>("remoteTxEnabled")
    static let rxEqSelected = DefaultsKey<Bool>("rxEqSelected")
    static let saveLogOnExit = DefaultsKey<Bool>("saveLogOnExit")
    static let showMarkers = DefaultsKey<Bool>("showMarkers")
    static let sideOpen = DefaultsKey<Bool>("sideOpen")
    static let spectrumIsFilled = DefaultsKey<Bool>("spectrumIsFilled")
    static let toolbar = DefaultsKey<NSColor>("toolbar")

    // Colors common to all Panafalls
    static let bandEdge = DefaultsKey<NSColor>("bandEdge")
    static let bandMarker = DefaultsKey<NSColor>("bandMarker")
    static let buttonsBackground = DefaultsKey<NSColor>("buttonsBackground")
    static let cwxOpen = DefaultsKey<Bool>("cwxOpen")
    static let dbLegend = DefaultsKey<NSColor>("dbLegend")
    static let dbLegendBackground = DefaultsKey<NSColor>("dbLegendBackground")
    static let filterLegend = DefaultsKey<NSColor>("filterLegend")
    static let filterLegendBackground = DefaultsKey<NSColor>("filterLegendBackground")
    static let frequencyLegend = DefaultsKey<NSColor>("frequencyLegend")
    static let frequencyLegendBackground = DefaultsKey<NSColor>("frequencyLegendBackground")
    static let gridLines = DefaultsKey<NSColor>("gridLines")
    static let segmentEdge = DefaultsKey<NSColor>("segmentEdge")
    static let sliceActive = DefaultsKey<NSColor>("sliceActive")
    static let sliceFilter = DefaultsKey<NSColor>("sliceFilter")
    static let sliceInactive = DefaultsKey<NSColor>("sliceInactive")
    static let spectrum = DefaultsKey<NSColor>("spectrum")
    static let spectrumBackground = DefaultsKey<NSColor>("spectrumBackground")
    static let spectrumFill = DefaultsKey<NSColor>("spectrumFill")
    static let text = DefaultsKey<NSColor>("text")
    static let tnfActive = DefaultsKey<NSColor>("tnfActive")
    static let tnfInactive = DefaultsKey<NSColor>("tnfInactive")
    static let tnfNormal = DefaultsKey<NSColor>("tnfNormal")
    static let tnfDeep = DefaultsKey<NSColor>("tnfDeep")
    static let tnfVeryDeep = DefaultsKey<NSColor>("tnfVeryDeep")

    // Settings common to all Panafalls
    static let bandMarkerOpacity = DefaultsKey<CGFloat>("bandMarkerOpacity")
    static let dbLegendSpacing = DefaultsKey<String>("dbLegendSpacing")
    static let dbLegendSpacings = DefaultsKey<[String]>("dbLegendSpacings")
    static let gridLinesDashed = DefaultsKey<Bool>("gridLinesDashed")
    static let gridLineWidth = DefaultsKey<String>("gridLineWidth")
    static let gridLinesWidths = DefaultsKey<[String]>("gridLinesWidths")
    static let sliceFilterOpacity = DefaultsKey<CGFloat>("sliceFilterOpacity")
    static let timeLegendSpacing = DefaultsKey<String>("timeLegendSpacing")
    static let timeLegendSpacings = DefaultsKey<[String]>("timeLegendSpacings")
}

extension CGFloat {
    
    /// Force a value to be between two values
    ///
    /// - Parameters:
    ///   - min: minimum value
    ///   - max: maximum value
    /// - Returns: the adjusted value
    ///
    func bracket(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        var value = self

        if self < min { value = min }
        if self > max { value = max }
        return value
    }
}

extension NSBezierPath {

    /// Draw a Horizontal line
    ///
    /// - Parameters:
    ///   - y: y-position of the line
    ///   - x1: starting x-position
    ///   - x2: ending x-position
    ///
    func hLine(at y:CGFloat, fromX x1:CGFloat, toX x2:CGFloat) {

        move( to: NSMakePoint( x1, y ) )
        line( to: NSMakePoint( x2, y ) )
    }
    /// Draw a Vertical line
    ///
    /// - Parameters:
    ///   - x:  x-position of the line
    ///   - y1: starting y-position
    ///   - y2: ending y-position
    ///
    func vLine(at x:CGFloat, fromY y1:CGFloat, toY y2:CGFloat) {

        move( to: NSMakePoint( x, y1) )
        line( to: NSMakePoint( x, y2 ) )
    }
    /// Fill a Rectangle
    ///
    /// - Parameters:
    ///   - rect:   the rect
    ///   - color:  the fill color
    ///   - alpha:  the aplha value
    ///
    func fillRect( _ rect:NSRect, withColor color:NSColor, andAlpha alpha:CGFloat = 1) {

        // fill the rectangle with the requested color and alpha
        color.withAlphaComponent(alpha).set()
        appendRect( rect )
        fill()
    }
    /// Draw a triangle
    ///
    ///
    /// - Parameters:
    ///   - center:         x-posiion of the triangle's center
    ///   - topWidth:       width of the triangle
    ///   - triangleHeight: height of the triangle
    ///   - topPosition:    y-position of the top of the triangle
    ///
    func drawTriangle(at center:CGFloat, topWidth:CGFloat, triangleHeight:CGFloat, topPosition:CGFloat) {

        move(to: NSPoint(x: center - (topWidth/2), y: topPosition))
        line(to: NSPoint(x: center + (topWidth/2), y: topPosition))
        line(to: NSPoint(x: center, y: topPosition - triangleHeight))
        line(to: NSPoint(x: center - (topWidth/2), y: topPosition))
        fill()
    }
    /// Draw an Oval inside a Rectangle
    ///
    /// - Parameters:
    ///   - rect:   the rect
    ///   - color:  the color
    ///   - alpha:  the alpha value
    ///
    func drawCircle(in rect: NSRect, color:NSColor, andAlpha alpha:CGFloat = 1) {

        appendOval(in: rect)
        color.withAlphaComponent(alpha).set()
        fill()
    }
    /// Draw a Circle
    ///
    /// - Parameters:
    ///   - point:  the center of the circle
    ///   - radius: the radius of the circle
    ///
    func drawCircle(at point: NSPoint, radius: CGFloat) {

        let rect = NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        appendOval(in: rect)
    }
    /// Draw an X
    ///
    /// - Parameters:
    ///   - point:      the center of the X
    ///   - halfWidth:  the half width of the X
    ///
    func drawX(at point:NSPoint, halfWidth: CGFloat) {

        move(to: NSPoint(x: point.x - halfWidth, y: point.y + halfWidth))
        line(to: NSPoint(x: point.x + halfWidth, y: point.y - halfWidth))
        move(to: NSPoint(x: point.x + halfWidth, y: point.y + halfWidth))
        line(to: NSPoint(x: point.x - halfWidth, y: point.y - halfWidth))
    }
    /// Crosshatch an area
    ///
    /// - Parameters:
    ///   - rect:       the rect
    ///   - color:      a color
    ///   - depth:      an integer ( 1 to n)
    ///   - linewidth:  width of the crosshatch lines
    ///   - multiplier: lines per depth
    ///
    func crosshatch(_ rect: NSRect, color: NSColor, depth: Int, twoWay: Bool = false, linewidth: CGFloat = 1, multiplier: Int = 10) {
        
        // calculate the number of lines to draw
        let numberOfLines = depth * multiplier
        
        // calculate the line increment
        let incr: CGFloat = rect.size.height / CGFloat(numberOfLines)
        
        // set color and line width
        color.set()
        lineWidth = linewidth
        
        // draw the crosshatch
        for i in 0..<numberOfLines {
            move( to: NSMakePoint( rect.origin.x, CGFloat(i) * incr))
            line(to: NSMakePoint(rect.origin.x + rect.size.width, CGFloat(i+1) * incr))
        }
        if twoWay {
            // draw the opposite crosshatch
            for i in 0..<numberOfLines {
                move( to: NSMakePoint( rect.origin.x + rect.size.width, CGFloat(i) * incr))
                line(to: NSMakePoint(rect.origin.x, CGFloat(i+1) * incr))
            }
        }
    }
    /// Stroke and then Remove all points
    ///
    func strokeRemove() {
        stroke()
        removeAllPoints()
    }
}

extension NSGradient {
    
    // return a "basic" Gradient
    static var basic: NSGradient {
        get {
            let colors = [
                NSColor(red: 0, green: 0, blue: 0, alpha: 1).bgr8,           // black
                NSColor(red: 0, green: 0, blue: 1, alpha: 1).bgr8,           // blue
                NSColor(red: 0, green: 1, blue: 1, alpha: 1).bgr8,           // cyan
                NSColor(red: 0, green: 1, blue: 0, alpha: 1).bgr8,           // green
                NSColor(red: 1, green: 1, blue: 0, alpha: 1).bgr8,           // yellow
                NSColor(red: 1, green: 0, blue: 0, alpha: 1).bgr8,           // red
                NSColor(red: 1, green: 1, blue: 1, alpha: 1).bgr8            // white
            ]
            let locations: Array<CGFloat> = [ 0.0, 0.15, 0.25, 0.35, 0.55, 0.90, 1.0 ]
            return NSGradient(colors: colors, atLocations: locations, colorSpace: .sRGB)!
        }
    }
    
    // return a "dark" Gradient
    static var dark: NSGradient {
        get {
            let colors = [
                NSColor(red: 0, green: 0, blue: 0, alpha: 1).bgr8,           // black
                NSColor(red: 0, green: 0, blue: 1, alpha: 1).bgr8,           // blue
                NSColor(red: 0, green: 1, blue: 0, alpha: 1).bgr8,           // green
                NSColor(red: 1, green: 0, blue: 0, alpha: 1).bgr8,           // red
                NSColor(red: 1, green: 0.71, blue: 0.76, alpha: 1).bgr8      // light pink
            ]
            let locations: Array<CGFloat> = [ 0.0, 0.65, 0.90, 0.95, 1.0 ]
            return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
        }
    }
    
    // return a "deuteranopia" Gradient
    static var deuteranopia: NSGradient {
        get {
            let colors = [
                NSColor(red: 0, green: 0, blue: 0, alpha: 1).bgr8,           // black
                NSColor(red: 0.03, green: 0.23, blue: 0.42, alpha: 1).bgr8,  // dark blue
                NSColor(red: 0.52, green: 0.63, blue: 0.84, alpha: 1).bgr8,  // light blue
                NSColor(red: 0.65, green: 0.59, blue: 0.45, alpha: 1).bgr8,  // dark yellow
                NSColor(red: 1, green: 1, blue: 0, alpha: 1).bgr8,           // yellow
                NSColor(red: 1, green: 1, blue: 0, alpha: 1).bgr8,           // yellow
                NSColor(red: 1, green: 1, blue: 1, alpha: 1).bgr8            // white
            ]
            let locations: Array<CGFloat> = [ 0.0, 0.15, 0.50, 0.65, 0.75, 0.95, 1.0 ]
            return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
        }
    }
    
    // return a "grayscale" Gradient
    static var grayscale: NSGradient {
        get {
            let colors = [
                NSColor(red: 0, green: 0, blue: 0, alpha: 1).bgr8,           // black
                NSColor(red: 1, green: 1, blue: 1, alpha: 1).bgr8            // white
            ]
            let locations: Array<CGFloat> = [ 0.0, 1.0 ]
            return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
        }
    }
    
    // return a "purple" Gradient
    static var purple: NSGradient {
        get {
            let colors = [
                NSColor(red: 0, green: 0, blue: 0, alpha: 1).bgr8,           // black
                NSColor(red: 0, green: 0, blue: 1, alpha: 1).bgr8,           // blue
                NSColor(red: 0, green: 1, blue: 0, alpha: 1).bgr8,           // green
                NSColor(red: 1, green: 1, blue: 0, alpha: 1).bgr8,           // yellow
                NSColor(red: 1, green: 0, blue: 0, alpha: 1).bgr8,           // red
                NSColor(red: 0.5, green: 0, blue: 0.5, alpha: 1).bgr8,       // purple
                NSColor(red: 1, green: 1, blue: 1, alpha: 1).bgr8            // white
            ]
            let locations: Array<CGFloat> = [ 0.0, 0.15, 0.30, 0.45, 0.60, 0.75, 1.0 ]
            return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
        }
    }
    
    // return a "tritanopia" Gradient
    static var tritanopia: NSGradient {
        get {
            let colors = [
                NSColor(red: 0, green: 0, blue: 0, alpha: 1).bgr8,           // black
                NSColor(red: 0, green: 0.27, blue: 0.32, alpha: 1).bgr8,     // dark teal
                NSColor(red: 0.42, green: 0.73, blue: 0.84, alpha: 1).bgr8,  // light blue
                NSColor(red: 0.29, green: 0.03, blue: 0.09, alpha: 1).bgr8,  // dark red
                NSColor(red: 1, green: 0, blue: 0, alpha: 1).bgr8,           // red
                NSColor(red: 0.84, green: 0.47, blue: 0.52, alpha: 1).bgr8,  // light red
                NSColor(red: 1, green: 1, blue: 1, alpha: 1).bgr8            // white
            ]
            let locations: Array<CGFloat> = [ 0.0, 0.15, 0.25, 0.45, 0.90, 0.95, 1.0 ]
            return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
        }
    }
}

extension NSColor {
    
    // return a float4 version of an NSColor
    var float4Color: float4 { return float4( Float(self.redComponent),
                                             Float(self.greenComponent),
                                             Float(self.blueComponent),
                                             Float(self.alphaComponent))
    }
    // return a bgr8 version of an rgba color
    var bgr8: NSColor { return NSColor(red: self.blueComponent, green: self.greenComponent, blue: self.redComponent, alpha: self.alphaComponent) }
    
}

