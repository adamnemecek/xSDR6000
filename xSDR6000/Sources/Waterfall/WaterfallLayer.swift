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

    // OpenGL
    fileprivate var _tools = OpenGLTools()                              // OpenGL support class
    fileprivate var _vaoHandle: GLuint = 0                              // Vertex Array Object handle
    fileprivate var _verticesVboHandle: GLuint = 0                      // Vertex Buffer Object handle (vertices)
    fileprivate var _texCoordsVboHandle: GLuint = 0                     // Vertex Buffer Object handle (Texture coordinates)
    fileprivate var _tboHandles = [GLuint](repeating: 0, count: 2)      // Texture Buffer Object handles
    fileprivate var _texValuesLocation: GLint = 0                       // texValues uniform location
    fileprivate var _gradientValuesLocation: GLint = 0                  // gradient uniform location
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
    
    fileprivate var _gradient: Gradient!

    fileprivate var _first = true

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
                
                // calculate texture duration in seconds (time per line * number of lines)
                texDuration = ( CGFloat(lineDuration) * CGFloat(kTextureHeight) ) / 1000
                
                // update the current line in the Texture
                glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, _currentLineNumber, kTextureWidth, 1, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), _currentLine)
                
                // increment the line number (mod Texture Height)
                _currentLineNumber = (_currentLineNumber + 1) % kTextureHeight
                
                // calculate waterfall duration in seconds (time per line * number of lines)
                waterfallDuration = ( CGFloat(lineDuration) * frame.height ) / 1_000

                // calculate and set the variable portion of the Texture coordinates
                _yOffset = GLfloat(_currentLineNumber) / GLfloat(kTextureHeight - 1)
                _stepValue = 1.0 / GLfloat(kTextureHeight - 1)
                _heightPercent = GLfloat(waterfallDuration) / GLfloat(texDuration)
                
                // texture t coordinates
                vertices[3] = _yOffset + 1 - _stepValue                            // v1, t
                vertices[7] = _yOffset + 1 - _heightPercent                        // v2, t
                vertices[11] = _yOffset + 1 - _stepValue                           // v3, t
                vertices[15] = _yOffset + 1 - _heightPercent                       // v4, t
                
                // texture s coordinates
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

        // create & bind TBO's for the 2D & 1D textures
        glGenTextures(2, &_tboHandles)
        glBindTexture(GLenum(GL_TEXTURE_2D), _tboHandles[0])
//        glBindTexture(GLenum(GL_TEXTURE_1D), _tboHandles[1])
        
        // setup the 2D texture
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT)
        
        // load the 2D texture sampler (with all black)
        let tex = [GLuint](repeating: _blackRGBA, count: Int(kTextureWidth * kTextureHeight))
        UnsafePointer<GLuint>(tex).withMemoryRebound(to: UInt8.self, capacity: Int(kTextureWidth * kTextureHeight)) { values in
            
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, kTextureWidth, kTextureHeight, 0, GLenum(GL_RGBA),
                         GLenum(GL_UNSIGNED_BYTE), values)
        }
        
//        // setup the 1D texture
//        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
//        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
//        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT)
//        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT)
//
        // create a Gradient
        _gradient = Gradient(_waterfall?.gradientIndex ?? 0)
        
//        // load the 1D gradient sampler
//        UnsafePointer<GLuint>(_gradient.array).withMemoryRebound(to: UInt8.self, capacity: 256) { values in
//            
//            glTexImage1D(GLenum(GL_TEXTURE_1D), 0, GL_RGBA, 256, 0, GLenum(GL_RGBA),
//                         GLenum(GL_UNSIGNED_BYTE), values)
//        }

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
        
        // setup & enable the vertex attribute array for the 2D Texture
        glVertexAttribPointer(_texCoordsLocation, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, UnsafePointer<GLfloat>(bitPattern: 8))
        glEnableVertexAttribArray(_texCoordsLocation)
        
        // locate & identify the Texture sampler
        _texValuesLocation = glGetUniformLocation(_shaders[0].program!, "texValues")
        glUniform1i(_texValuesLocation, GL_TEXTURE0)
        
        // locate & identify the Gradient sampler
        _gradientValuesLocation = glGetUniformLocation(_shaders[0].program!, "gradient")
        glUniform1i(_gradientValuesLocation, GL_TEXTURE1)

        // put the program into effect
        glUseProgram(_shaders[0].program!)
        
        glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height))
        
        // initialize the "line" to all black
        _currentLine = [GLuint](repeating: _blackRGBA, count: Int(kTextureWidth))

        // enable Waterfall stream processing
        _waterfall!.delegate = self

        // add notification subscriptions
        addNotifications()
        
        // setup observations of Waterfall properties
        observations(_waterfall!, paths: _waterfallKeyPaths)
        
        // prepare is complete
        _prepared = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    fileprivate let _waterfallKeyPaths =              // Waterfall keypaths to observe
        [
            #keyPath(Waterfall.autoBlackEnabled),
            #keyPath(Waterfall.blackLevel),
            #keyPath(Waterfall.colorGain),
            #keyPath(Waterfall.gradientIndex)
    ]
    /// Add / Remove property observations
    ///
    /// - Parameters:
    ///   - object: the object of the observations
    ///   - paths: an array of KeyPaths
    ///   - add: add / remove (defaults to add)
    ///
    fileprivate func observations<T: NSObject>(_ object: T, paths: [String], remove: Bool = false) {
        
        // for each KeyPath Add / Remove observations
        for keyPath in paths {
            
            if remove { object.removeObserver(self, forKeyPath: keyPath, context: nil) }
            else { object.addObserver(self, forKeyPath: keyPath, options: [.initial, .new], context: nil) }
        }
    }
    /// Observe properties
    ///
    /// - Parameters:
    ///   - keyPath: the registered KeyPath
    ///   - object: object containing the KeyPath
    ///   - change: dictionary of values
    ///   - context: context (if any)
    ///
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case #keyPath(Waterfall.autoBlackEnabled), #keyPath(Waterfall.blackLevel), #keyPath(Waterfall.colorGain):
            // recalc the levels
            _gradient.calcLevels(autoBlackEnabled: _waterfall!.autoBlackEnabled, autoBlackLevel: _autoBlackLevel, blackLevel: _waterfall!.blackLevel, colorGain: _waterfall!.colorGain)
            
        case #keyPath(Waterfall.gradientIndex):
            // reload the Gradient
            _gradient.loadMap(_waterfall!.gradientIndex)
            
        default:
            _log.msg("Invalid observation - \(keyPath!)", level: .error, function: #function, file: #file, line: #line)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    fileprivate func addNotifications() {
        
        NC.makeObserver(self, with: #selector(waterfallWillBeRemoved(_:)), of: .waterfallWillBeRemoved, object: nil)
    }
    /// Process .waterfallWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Waterfall object?
        if let waterfall = note.object as? Waterfall {
            
            // is it this waterfall
            if waterfall == _waterfall! {
                
                // YES, remove Waterfall property observers
                observations(waterfall, paths: _waterfallKeyPaths, remove: true)
            }
        }
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
    func waterfallStreamHandler(_ dataFrame: WaterfallFrame ) {
        
        // waterfall will be initialized after Panadapter, it may not be ready yet
        if let waterfall = _waterfall {
                        
            // save LineDuration from the dataframe
            lineDuration = dataFrame.lineDuration
            _autoBlackLevel = dataFrame.autoBlackLevel

            // calculate the first & last bin numbers to be displayed
            startBinNumber = Int( (CGFloat(_start) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
            endBinNumber = Int( (CGFloat(_end) - dataFrame.firstBinFreq) / dataFrame.binBandwidth )
            
            // it's a hack but this gets the levels initialized
            if _first {
                _first = false
                // recalc the levels
                _gradient.calcLevels(autoBlackEnabled: waterfall.autoBlackEnabled, autoBlackLevel: dataFrame.autoBlackLevel, blackLevel: waterfall.blackLevel, colorGain: waterfall.colorGain)
            }
            
            // populate the current waterfall "line"
            let binsPtr = UnsafeMutablePointer<UInt16>(mutating: dataFrame.bins)
            for binNumber in 0..<dataFrame.numberOfBins {
                
                _currentLine[binNumber] = _gradient.value(binsPtr.advanced(by: binNumber).pointee)
//                _currentLine[binNumber] = GLuint(binsPtr.advanced(by: binNumber).pointee)
                
//                let intensity = _currentLine[binNumber]
//                let scaled = (Float(intensity)/Float(65536)) * Float(256)
//
//                Swift.print("\(intensity), \(scaled)")
            }
            // interact with the UI
            DispatchQueue.main.async { [unowned self] in                
                
                // force a redraw of the Waterfall
                self.setNeedsDisplay()
            }
        }
    }

}
