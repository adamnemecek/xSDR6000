//
//  WaterfallLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/27/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import OpenGL.GL3
import SwiftyUserDefaults

// ------------------------------------------------------------------------------
// MARK: - Waterfall View Layer
//
//          draw the Waterfall using an OpenGL texture
//
// ------------------------------------------------------------------------------

final class WaterfallLayer: CAOpenGLLayer, CALayerDelegate, WaterfallStreamHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var params: Params!                                             // Radio reference & PanadapterId
    var liveResize = false                                          // Live resize in progress
    var waterfallDuration: CGFloat = 0.0                            // Height of Waterfall in seconds
    var texDuration: CGFloat = 0                                    // Height of the Texture in seconds
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio: Radio { return params.radio }       // values derived from Params
    fileprivate var _panadapter: Panadapter? { return params.panadapter }
    fileprivate var _waterfall: Waterfall? { return _radio.waterfalls[_panadapter!.waterfallId] }

    fileprivate var _center: Int {return _panadapter!.center }
    fileprivate var _bandwidth: Int { return _panadapter!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int { return _center + (_bandwidth/2) }

    fileprivate var _currentLine = [GLuint]()                           // current line in waterfall
    fileprivate var _waterfallTime: [Date?]!

    // OpenGL
    fileprivate var _tools = OpenGLTools()                              // OpenGL support class
    fileprivate var _vaoHandle: GLuint = 0                              // Vertex Array Object handle
    fileprivate var _verticesVboHandle: GLuint = 0                      // Vertex Buffer Object handle (vertices)
    fileprivate var _texCoordsVboHandle: GLuint = 0                     // Vertex Buffer Object handle (Texture coordinates)
    fileprivate var _tboHandle: GLuint = 0                              // Texture Buffer Object handle
    fileprivate var _texValuesLocation: GLint = 0                       // texValues uniform location

    fileprivate var _shaders =                                          // array of Shader structs
        [
            ShaderStruct(name: "Waterfall", type: .Vertex),
            ShaderStruct(name: "Waterfall", type: .Fragment)
        ]
    
    //  Vertices    v3      v1     -1,1     |     1,1         Texture     v3      v1      0,1 |      1,1
    //  (-1 to +1)                          |                 (0 to 1)                        |
    //              v4      v2          ----|----                         v4      v2      0,0 |_____ 0,1
    //                                      |
    //                             -1,-1    |     1,-1
    //
    fileprivate var vertices: [GLfloat] =                               // vertices & tex coords
        //    x     y     s      t
        [
             1.0,  1.0,  1.0,  1.0,                                     // v1
             1.0, -1.0,  1.0,  0.0,                                     // v2
            -1.0,  1.0,  0.0,  1.0,                                     // v3
            -1.0, -1.0,  0.0,  0.0                                      // v4
        ]
    
    fileprivate var _texture = [UInt8]()                                // waterfall texture
    fileprivate var _currentLineNumber: GLint = 0                       // line number (mod kTextureHeight)
    fileprivate var _yOffset: GLfloat = 0                               // current line's y position in texture
    fileprivate var _stepValue: GLfloat = 0                             // space between lines
    fileprivate var _heightPercent: GLfloat = 0                         // percent of texture height being displayed
    fileprivate var _prepared = false                                   // whether prepareOpenGL has completed
    fileprivate let _waterfallGradient = WaterfallGradient.sharedInstance              // Gradient class
    fileprivate var _updateGradient = false                             // set when Gradient needs to be updated
    fileprivate var _updateLevels = false                               // set when Levels need to be updated
    
    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)

    fileprivate let kTextureWidth: GLint = 4096                         // must be >= max number of Bins
    fileprivate let kTextureHeight: GLint = 2048                        // must be >= max number of lines
    fileprivate let _blackRGBA: GLuint = 0xFF000000                     // Black color in RGBA format
    fileprivate let _verticesLocation: GLuint = 0                       // fixed - in location (vertices)
    fileprivate let _texCoordsLocation: GLuint = 1                      // fixed - in location ( Texture coordinates)
    
    fileprivate let _waterfallQ =                                      // Waterfall property synchronization
        DispatchQueue(label: "xSDR6000" + ".waterfallQ", attributes: [.concurrent])
    
    fileprivate var _startBinNumber = 0
    fileprivate var _endBinNumber = 0
    fileprivate var _autoBlackLevel: UInt32 = 0                         // calculated Black level from Radio
    fileprivate var _lineDuration = 100                                 // line duration in milliseconds

    fileprivate var startBinNumber: Int {
        get { return _waterfallQ.sync { _startBinNumber } }
        set { _waterfallQ.sync(flags: .barrier) { _startBinNumber = newValue } } }

    fileprivate var endBinNumber: Int {
        get { return _waterfallQ.sync { _endBinNumber } }
        set { _waterfallQ.sync(flags: .barrier) { _endBinNumber = newValue } } }

    fileprivate var autoBlackLevel: UInt32 {
        get { return _waterfallQ.sync { _autoBlackLevel } }
        set { _waterfallQ.sync(flags: .barrier) { _autoBlackLevel = newValue } } }
    
    fileprivate var lineDuration: Int {
        get { return _waterfallQ.sync { _lineDuration } }
        set { _waterfallQ.sync(flags: .barrier) { _lineDuration = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        
        let attribs: [CGLPixelFormatAttribute] = // Pixel format attributes
            [
                kCGLPFADisplayMask, _CGLPixelFormatAttribute(rawValue: mask),
                kCGLPFAColorSize, _CGLPixelFormatAttribute(rawValue: 24),
                kCGLPFAAlphaSize, _CGLPixelFormatAttribute(rawValue: 8),
                kCGLPFAAccelerated,
                kCGLPFADoubleBuffer,
                _CGLPixelFormatAttribute(rawValue: UInt32(NSOpenGLPFAOpenGLProfile)), _CGLPixelFormatAttribute(rawValue: UInt32(NSOpenGLProfileVersion3_2Core)),
                _CGLPixelFormatAttribute(rawValue: 0)
        ]
        
        var pixelFormatObj: CGLPixelFormatObj? = nil
        var numberOfPixelFormats: GLint = 0
        
        CGLChoosePixelFormat(attribs, &pixelFormatObj, &numberOfPixelFormats)
        
        return pixelFormatObj!
    }
    
    override func draw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj, forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) {
        
        // as soon as Waterfall is populated, do prepare
        if !_prepared && _waterfall != nil { prepare() }
        
        // select the context
        CGLSetCurrentContext(ctx)
        
        if lineDuration != 0 {
            
            if !liveResize {
                
                // calculate texture duration in seconds
                texDuration = ( CGFloat(lineDuration) * CGFloat(kTextureHeight) ) / 1000
                
                // update the current line in the Texture
                glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, _currentLineNumber, kTextureWidth, 1, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), _currentLine)
                
                // set the date/time for the _currentLine
                _waterfallTime[Int(_currentLineNumber)] = Date()
                
                // increment the line number
                _currentLineNumber = (_currentLineNumber + 1) % kTextureHeight
                
                waterfallDuration = frame.height * CGFloat(lineDuration) / 1_000

                // calculate and set the variable portion of the Texture coordinates
                _yOffset = GLfloat(_currentLineNumber) / GLfloat(kTextureHeight - 1)
                _stepValue = 1.0 / GLfloat(kTextureHeight - 1)
                _heightPercent = GLfloat(waterfallDuration) / GLfloat(texDuration)
                
                vertices[3] = _yOffset + 1 - _stepValue                             // v1, t
                vertices[7] = _yOffset + (1 - _heightPercent)                       // v2, t
                vertices[11] = _yOffset + 1 - _stepValue                            // v3, t
                vertices[15] = _yOffset + (1 - _heightPercent)                      // v4, t
                
                vertices[2] = GLfloat(endBinNumber) / GLfloat(kTextureWidth)       // v1, s
                vertices[6] = GLfloat(endBinNumber) / GLfloat(kTextureWidth)       // v2, s
                vertices[10] = GLfloat(startBinNumber) / GLfloat(kTextureWidth)    // v3, s
                vertices[14] = GLfloat(startBinNumber) / GLfloat(kTextureWidth)    // v4, s
                
                // bind the vertices
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), _verticesVboHandle)
                glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(vertices.count * MemoryLayout<GLfloat>.size), vertices, GLenum(GL_DYNAMIC_DRAW))
            }
        }
        // clear
        glClear(GLenum(GL_COLOR_BUFFER_BIT))
        
        // draw
        if lineDuration != 0 { glDrawArrays(GLenum(GL_TRIANGLE_STRIP), GLint(0), GLsizei(4)) }
        
        // call super to trigger a flush
        super.draw(inCGLContext: ctx, pixelFormat: pf, forLayerTime: t, displayTime: ts)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Prepare OpenGL
    ///
    fileprivate func prepare() {
        
        // populate an empty date/time array
        _waterfallTime = [Date?](repeating: nil, count: Int(kTextureHeight) )
        
        // create a ProgramID, Compile & Link the Shaders
        if !_tools.loadShaders(&_shaders) {
            // FIXME: do something if there is an error
            _log.msg("OpenGL Shader - \(_shaders[0].error!)", level: .error, function: #function, file: #file, line: #line)
        }
        // set a "Clear" color
        let background = Defaults[.spectrumBackground]
        glClearColor(GLfloat( background.redComponent ),
                     GLfloat( background.greenComponent ),
                     GLfloat( background.blueComponent ),
                     GLfloat( background.alphaComponent ))

        // create & bind a TBO
        glGenTextures(1, &_tboHandle)
        glBindTexture(GLenum(GL_TEXTURE_2D), _tboHandle)
        
        // setup the texture
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT)
        
        let tex = [GLuint](repeating: _blackRGBA, count: Int(kTextureWidth * kTextureHeight))

        UnsafePointer<GLuint>(tex).withMemoryRebound(to: UInt8.self, capacity: Int(kTextureWidth * kTextureHeight)) { _texture in
            
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, kTextureWidth, kTextureHeight, 0, GLenum(GL_RGBA),
                         GLenum(GL_UNSIGNED_BYTE), _texture)
        }
        
        // setup a VBO for the vertices & tex coordinates
        glGenBuffers(1, &_verticesVboHandle)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _verticesVboHandle)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(vertices.count * MemoryLayout<GLfloat>.size), vertices, GLenum(GL_DYNAMIC_DRAW))
        
        // create & bind a VAO
        glGenVertexArrays(1, &_vaoHandle)
        glBindVertexArray(_vaoHandle)
        
        // setup & enable the vertex attribute array for the Vertices
        glVertexAttribPointer(_verticesLocation, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, UnsafePointer<GLfloat>(bitPattern: 0))
        glEnableVertexAttribArray(_verticesLocation)
        
        // setup & enable the vertex attribute array for the Texture
        glVertexAttribPointer(_texCoordsLocation, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, UnsafePointer<GLfloat>(bitPattern: 8))
        glEnableVertexAttribArray(_texCoordsLocation)
        
        // locate & populate the Texture sampler
        _texValuesLocation = glGetUniformLocation(_shaders[0].program!, "texValues")
        glUniform1i(_texValuesLocation, GL_TEXTURE0)
        
        // put the program into effect
        glUseProgram(_shaders[0].program!)
        
        glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height))
        
        // initialize the "line" to all black
        _currentLine = [GLuint](repeating: _blackRGBA, count: Int(kTextureWidth))
        
        // enable Waterfall stream processing
        _waterfall!.delegate = self

        // prepare is complete
        _prepared = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
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
    /// - Parameter dataFrame: a waterfall dataframe struct
    ///
    func waterfallStreamHandler(_ dataFrame: WaterfallFrame ) {
        
        // waterfall will be initialized after Panadapter, it may not be ready yet
        if let waterfall = _waterfall {
                        
            // save AutoBlack & LineDuration from the dataframe
            _waterfallGradient.autoBlackLevel = dataFrame.autoBlackLevel
            lineDuration = dataFrame.lineDuration

            // calculate the first & last bin numbers to be displayed
            startBinNumber = Int( (CGFloat(_start) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
            endBinNumber = Int( (CGFloat(_end) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
            
            // load the new Gradient & recalc the levels
            _waterfallGradient.loadGradient(waterfall)
            _waterfallGradient.calcLevels(waterfall)

            // populate the current waterfall "line"
            let binsPtr = UnsafeMutablePointer<UInt16>(mutating: dataFrame.bins)
            for binNumber in 0..<dataFrame.numberOfBins {
                
                self._currentLine[binNumber] = GLuint(self._waterfallGradient.value(binsPtr.advanced(by: binNumber).pointee, id: waterfall.id))
//                self._currentLine[binNumber] = GLuint(0)
            }
            // interact with the UI
            DispatchQueue.main.async { [unowned self] in                
                
                // force a redraw of the Waterfall
                self.setNeedsDisplay()
            }
        }
    }

}
