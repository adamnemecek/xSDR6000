//
//  PanadapterLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/7/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Panadapter Layer class implementation
// --------------------------------------------------------------------------------

final class PanadapterLayer: CAOpenGLLayer, CALayerDelegate, PanadapterStreamHandler {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var liveResize = false                                  // View resize in progress
    var isFilled = false                                    // Fill the spectrum display
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    // OpenGL
    fileprivate var _prepared = false                           // whether prepare() has completed
    fileprivate var _tools = OpenGLTools()                      // OpenGL support class
    fileprivate var _vaoHandle: GLuint = 0                      // Vertex Array Object handle
    fileprivate var _vboHandle = [GLuint](repeating: 0, count: 2)  // Vertex Buffer Object handle (Y)
    fileprivate var _uniformLineColor: GLint = 0                // Uniform location for Line Color
    fileprivate var _uniformDelta: GLint = 0                    // Uniform location for delta x
    fileprivate var _uniformHeight: GLint = 0                   // Uniform location for frame height
    fileprivate var _delta: GLfloat = 0                         // delta x
    fileprivate var _previousNumberOfBins: Int = 0              // number of bins on last draw

    fileprivate var _shaders =                                   // array of Shader structs
        [
            ShaderStruct(name: "Panadapter", type: .Vertex),
            ShaderStruct(name: "Panadapter", type: .Fragment)
        ]

    fileprivate var _lineColor = [GLfloat]()                     // Spectrum color

    // Stream handler
    fileprivate var _dataFrame: PanadapterFrame?                 // Stream Handler data
    
    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)
    fileprivate let kModule = "PanadapterLayer"                  // Module Name reported in log messages
    fileprivate let _yCoordinateLocation: GLuint = 0
    fileprivate let _xCoordinateLocation: GLuint = 1
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// Create the Pixel Format
    ///
    /// - Parameter mask: display mask
    /// - Returns: a CGLPixelFormatObj
    ///
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
    /// Draw the layer
    ///
    /// - Parameters:
    ///   - ctx: CGL Context
    ///   - pf: pixelFormat
    ///   - t: layer time
    ///   - ts: display time
    ///
    override func draw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj, forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) {
        var bufferPtr: UnsafeMutablePointer<GLfloat>
        
        // perform Prepare on the first  access to the context
        if !_prepared { prepare() }
        
        // select the context
        CGLSetCurrentContext(ctx)
        
        // FIXME: Only do colors when they change
        
        // set a "Clear" color
        let background = Defaults[.spectrumBackground]
        glClearColor(GLfloat( background.redComponent ),
                     GLfloat( background.greenComponent ),
                     GLfloat( background.blueComponent ),
                     GLfloat( background.alphaComponent ))
        
        // set a "Line" color
        let spectrum = Defaults[.spectrum]
        _lineColor =
            [
                GLfloat( spectrum.redComponent ),
                GLfloat( spectrum.greenComponent ),
                GLfloat( spectrum.blueComponent ),
                GLfloat( spectrum.alphaComponent )
            ]
        // clear the view
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        // exit if called before data is available
        guard let dataFrame = _dataFrame else {
            
            // call super to trigger a flush
            super.draw(inCGLContext: ctx, pixelFormat: pf, forLayerTime: t, displayTime: ts)

            return
        }
        
        // select the Program
        glUseProgram(_shaders[0].program!)
        
        if !liveResize {
            
            // has the number of bins changed? (will be true on first call)
            if dataFrame.numberOfBins != _previousNumberOfBins {
                
                // re-calculate the spacings between values
                _delta = 2.0 / GLfloat(dataFrame.numberOfBins - 1)
                
                // select & resize the yCoordinate buffer
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[0])
                glBufferData(GLenum(GL_ARRAY_BUFFER), dataFrame.numberOfBins * MemoryLayout<GLfloat>.size, nil, GLenum(GL_STREAM_DRAW))

//                // select & resize the xCoordinate buffer
//                glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[1])
//                glBufferData(GLenum(GL_ARRAY_BUFFER), dataFrame.numberOfBins * MemoryLayout<GLfloat>.size * 2, nil, GLenum(GL_STREAM_DRAW))
//
//                // select the X-buffer & get a pointer to it
//                glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[1])
//                bufferPtr = glMapBuffer(GLenum(GL_ARRAY_BUFFER), GLenum(GL_WRITE_ONLY)).assumingMemoryBound(to: GLfloat.self)
//                
//                // populate the x Coordinates
//                for i in 0..<dataFrame.numberOfBins {
//                    
//                    bufferPtr.advanced(by: i * 2).pointee = -1 + (GLfloat(i) * _delta)
//                    bufferPtr.advanced(by: (i * 2) + 1).pointee = -1 + (GLfloat(i) * _delta)
//                }
            }
            
            // select the Y-buffer & get a pointer to it
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[0])
            bufferPtr = glMapBuffer(GLenum(GL_ARRAY_BUFFER), GLenum(GL_WRITE_ONLY)).assumingMemoryBound(to: GLfloat.self)
            
            // populate the y Coordinates
            for i in 0..<dataFrame.numberOfBins {
                
//                bufferPtr.advanced(by: i * 2).pointee = GLfloat(-1)
//                bufferPtr.advanced(by: i * 2).pointee = GLfloat(1) - (GLfloat(2) * GLfloat(dataFrame.bins[i]) / GLfloat(frame.height))
                
//                 incoming values range from 0 to height with 0 being the max and height being the min (i.e. it's upside down)
//                 normalize to range between -1 to +1 for OpenGL
//                bufferPtr.advanced(by: i).pointee = GLfloat(1) - (GLfloat(2) * GLfloat(dataFrame.bins[i]) / GLfloat(frame.height))

                // incoming values range from 0 to height with 0 being the max and height being the min (i.e. it's upside down)
                // the Vertex Shader will normalize to range between -1 to +1 for OpenGL
                bufferPtr.advanced(by: i).pointee = GLfloat(dataFrame.bins[i])
            }
            
            // release the buffer
            glUnmapBuffer(GLenum(GL_ARRAY_BUFFER))
        }
        
        // set the uniforms
        // FIXME: Should only be done when needed
        glUniform4fv(_uniformLineColor , 1, _lineColor)
        glUniform1f(_uniformDelta , _delta)
        glUniform1f(_uniformHeight , GLfloat(frame.height))
        
        // draw the Panadapter trace
        glDrawArrays(GLenum(GL_LINE_STRIP), GLint(0), GLsizei(dataFrame.numberOfBins) )
//        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), GLint(0), GLsizei(dataFrame.numberOfBins * 2) )
        
        _previousNumberOfBins = dataFrame.numberOfBins
        
        // call super to trigger a flush
        super.draw(inCGLContext: ctx, pixelFormat: pf, forLayerTime: t, displayTime: ts)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Prepare OpenGL
    ///
    fileprivate func prepare() {
        
        // Compile the Shaders, create a ProgramID, link the Shaders to the Program
        if !_tools.loadShaders(&_shaders) {
            fatalError("Panadapter OpenGL Shader - \(_shaders[0].error!)")
        }
        
        // set a "Line" color
        let spectrum = Defaults[.spectrum]
        _lineColor =
            [
                GLfloat( spectrum.redComponent ),
                GLfloat( spectrum.greenComponent ),
                GLfloat( spectrum.blueComponent ),
                GLfloat( spectrum.alphaComponent )
            ]

        // create & bind VBOs for xCoordinate & yCoordinate values
        glGenBuffers(1, &_vboHandle)
        
        // setup the yCoordinate buffer but don't transfer any data yet
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), Int(frame.width) * MemoryLayout<GLfloat>.size, nil, GLenum(GL_STREAM_DRAW))

//        // setup the xCoordinate buffer but don't transfer any data yet
//        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[1])
//        glBufferData(GLenum(GL_ARRAY_BUFFER), Int(frame.width) * MemoryLayout<GLfloat>.size * 2, nil, GLenum(GL_STREAM_DRAW))

        // create & bind a VAO
        glGenVertexArrays(1, &_vaoHandle)
        glBindVertexArray(_vaoHandle)
        
        // enable and map the vertex attribute array for the yCoordinate Buffer
        glEnableVertexAttribArray(_yCoordinateLocation)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[0])
        glVertexAttribPointer(_yCoordinateLocation, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size), UnsafePointer<GLuint>(bitPattern: 0))
        
//        // enable and map the vertex attribute array for the xCoordinate Buffer
//        glEnableVertexAttribArray(_xCoordinateLocation)
//        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _vboHandle[1])
//        glVertexAttribPointer(_xCoordinateLocation, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size), UnsafePointer<GLuint>(bitPattern: 0))
        
        // activate the Shader program
        glUseProgram(_shaders[0].program!)
        
        // get the uniform locations
        _uniformLineColor = glGetUniformLocation(_shaders[0].program!, "lineColor")
        _uniformDelta = glGetUniformLocation(_shaders[0].program!, "delta")
        _uniformHeight = glGetUniformLocation(_shaders[0].program!, "height")

        // FIXME: This should only be done once?
        
        // get the OpenGL version and make it available to the Preferences Settings page
        var mMajor = [GLint](repeating: 0, count:1)
        var mMinor = [GLint](repeating: 0, count:1)
        glGetIntegerv(GLenum(GL_MAJOR_VERSION), &mMajor)
        glGetIntegerv(GLenum(GL_MINOR_VERSION), &mMinor)
        Defaults[.openGLVersion] = "\(mMajor[0]).\(mMinor[0])"
        
        _prepared = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
        
    // ----------------------------------------------------------------------------
    // MARK: - PanadapterStreamHandler protocol methods
    //
    //  DataFrame Layout: (see xLib6000 PanadapterFrame)
    //
    //  public var startingBinIndex: Int                    // Index of first bin
    //  public var numberOfBins: Int                        // Number of bins
    //  public var binSize: Int                             // Bin size in bytes
    //  public var frameIndex: Int                          // Frame index
    //  public var bins: [UInt16]                           // Array of bin values
    //
    
    //
    // Process the UDP Stream Data for the Panadapter
    //
    func panadapterStreamHandler(_ dataFrame: PanadapterFrame) {
        
        // interact with the UI
        DispatchQueue.main.async { [unowned self] in
        
            self._dataFrame = dataFrame
            
            // force a draw
            self.setNeedsDisplay()
        }
    }
}
