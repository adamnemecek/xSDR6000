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

