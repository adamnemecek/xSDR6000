//
//  OpenGLTools.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/14/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import OpenGL.GL3

// --------------------------------------------------------------------------------
// MARK: - Shader Struct implementation
// --------------------------------------------------------------------------------

struct ShaderStruct {
    
    var name: String                // file name (not including extension)
    var type: ShaderType            // type of Shader
    var handle: GLuint?             // Shader OpenGL handle
    var program: GLuint?            // Program OpenGL handle
    var error: String?              // Most recent Error explanation
    
    init(name: String, type: ShaderType) {
        self.name = name
        self.type = type
    }
    
    enum ShaderType : String {
        case Fragment = "fsh"       // extension for a Fragment Shader
        case Vertex = "vsh"         // extension for a Vertex Shader
    }
}

// --------------------------------------------------------------------------------
// MARK: - OpenGL Tools class implementation
// --------------------------------------------------------------------------------

final class OpenGLTools {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Compile and Link Shaders, attach them to a ProgramId
    ///
    /// - Parameter shaders: an array of Shader Structs
    /// - Returns: success flag
    ///
    func loadShaders( _ shaders: inout [ShaderStruct]) -> Bool {
        
        // create a Program Handle
        let program = glCreateProgram()
        
        // get the source for each Shader
        for i in 0..<shaders.count {
            
            // load the source from a file
            let (source, error) = shaderFromFile(shaders[i])
            if error == nil {
                
                // set the Program handle
                shaders[i].program = program
                
                // compile the Shader
                if !compile(&shaders[i], source: source) {
                    
                    // there was a compile error, copy the error into the 0th entry
                    shaders[0].error = shaders[i].error
                    
                    // return with error status
                    return false
                }
            
            } else {
                
                // there was a load error, copy the error into the 0th entry
                shaders[0].error = shaders[i].error
                
                // return with error status
                return false
            }
        }
        // no errors so far, Link and return the status of linking
        return link(&shaders)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Read a Shader source from the main bundle
    ///
    /// - Parameter shader: a Shader struct
    /// - Returns: tuple of Source & error code
    ///
    fileprivate func shaderFromFile( _ shader: ShaderStruct) -> (source: String?, error: String?) {
        var source: String?
        var error: String?
        
        // get the Path to the specified Shader source file
        if let path = Bundle.main.path(forResource: shader.name, ofType: shader.type.rawValue) {
            
            // try to read the file
            do {
                source = try String(contentsOfFile: path, encoding: String.Encoding.ascii)
            } catch let e as NSError {
                // there was an error, get the description
                error = e.localizedDescription
            }
        }
        // return the results
        return (source, error)
    }
    /// Compile Shader source code
    ///
    /// - Parameters:
    ///   - shader: a Shader Struct
    ///   - source: source code
    /// - Returns: success flag
    ///
    fileprivate func compile( _ shader: inout ShaderStruct, source: String?) -> Bool {
        var error: GLint = 0
        var shaderType: GLenum
        
        switch shader.type {
        case .Fragment:
            shaderType = GLenum(GL_FRAGMENT_SHADER)
        case .Vertex:
            shaderType = GLenum(GL_VERTEX_SHADER)
        }
        
        // create a Shader of the specified type
        shader.handle = glCreateShader(shaderType)
        
        // get a C-string of the source
        if let sourceCode = source?.cString(using: String.Encoding.utf8) {
            
            // construct a pointer of the required type
            var sourcePtr: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(sourceCode)
            
            // assign the shader source
            glShaderSource(shader.handle!, 1, &sourcePtr, nil)
            
            // compile the shader source
            glCompileShader(shader.handle!)
            
            // check for errors
            glGetShaderiv(shader.handle!, GLbitfield(GL_COMPILE_STATUS), &error)
            if error <= 0 {
                var logLength: GLint = 0
                
                glGetShaderiv(shader.handle!, GLenum(GL_INFO_LOG_LENGTH), &logLength)
                
                if logLength > 0 {
                    
                    let cLog = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
                    
                    glGetShaderInfoLog(shader.handle!, GLsizei(logLength), &logLength, cLog)
                    
                    let log = String(cString: cLog)
                    
                    shader.error = log.trimmingCharacters(in: CharacterSet(charactersIn: "\n") as CharacterSet)
                    
                    free(cLog)
                }
            }
            
        }
        // return error status
        return (shader.error == nil)
    }
    ///  Link Shaders to a Program Id
    ///
    /// - Parameter shaders: an arry of Shader Structs
    /// - Returns: success flag
    ///
    fileprivate func link( _ shaders: inout [ShaderStruct]) -> Bool {
        
        // attach each Shader to the Program handle
        for shader in shaders {
            
            glAttachShader(shaders[0].program!, shader.handle!)
        }
        
        // link ('shaders[0].program' is used since all program values are equal)
        glLinkProgram(shaders[0].program!)
        
        // check for errors
        var error: GLint = 0
        glGetProgramiv(shaders[0].program!, UInt32(GL_LINK_STATUS), &error)
        if error <= 0 {
            var logLength: GLint = 0
            
            glGetProgramiv(shaders[0].program!, UInt32(GL_INFO_LOG_LENGTH), &logLength)
            
            if logLength > 0 {
                
                let cLog = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLength))
                
                glGetProgramInfoLog(shaders[0].program!, GLsizei(logLength), &logLength, cLog)
                
                let log = String(cString: cLog)

                shaders[0].error = log.trimmingCharacters(in: CharacterSet(charactersIn: "\n") as CharacterSet)
                free(cLog)
            }
        }
        // delete the Shaders (they still exist linked into the Program)
        for shader in shaders {
            
            glDeleteShader(shader.handle!)
            glDetachShader(shaders[0].program!, shader.handle!)
        }
        // return error status (link errors, if any, are in shaders[0].error)
        return (shaders[0].error == nil)
    }
    
}
