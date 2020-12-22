//
//  main.swift
//  modeselector
//
//  Created by William Alexander on 12/20/20.
//

import AppKit
import ArgumentParser
import CoreGraphics
import Foundation

typealias CoreGraphicsError = CGError

extension CoreGraphicsError: Error {
    init(_ code: CGError) {
        self = code
    }
    
    var description: String {
        switch self {
        case .cannotComplete:
            return "The requested operation is inappropriate for the parameters passed in, or the current system state."
        case .failure:
            return "A general failure occurred."
        case .illegalArgument:
            return "One or more of the parameters passed to a function are invalid. Check for NULL pointers."
        case .invalidConnection:
            return "The parameter representing a connection to the window server is invalid."
        case .invalidContext:
            return "The CPSProcessSerNum or context identifier parameter is not valid."
        case .invalidOperation:
            return "The requested operation is not valid for the parameters passed in, or the current system state."
        case .noneAvailable:
            return "The requested operation could not be completed as the indicated resources were not found."
        case .notImplemented:
            return "Return value from obsolete function stubs present for binary compatibility, but not typically called."
        case .rangeCheck:
            return "A parameter passed in has a value that is inappropriate, or which does not map to a useful operation or value."
        case .success:
            return "The requested operation was completed successfully."
        case .typeCheck:
            return "A data type or token was encountered that did not match the expected type or token."
        default:
            return ""
        }
    }
}
    
extension CGError {
    func mapError() -> CoreGraphicsError? {
        if case .success = self {
            return nil
        }
        return CoreGraphicsError(self)
    }
}

enum ModeSelectorError: Error, CustomStringConvertible {
    case noScreen
    case noDisplay
    case invalidDisplay
    case noMatchingModes
    case coreGraphicsError(CoreGraphicsError)

    public var description: String {
        switch self {
        case .noScreen:
            return "no screen found containing the window with the keyboard focus"
        case .noDisplay:
            return "no display found for screen"
        case .invalidDisplay:
            return "display is invalid"
        case .noMatchingModes:
            return "no modes matching rate found"
        case .coreGraphicsError(let error):
            return "Core Graphics: \(error)"
        }
    }
}

struct ModeSelector: ParsableCommand {
    @Option(name: .shortAndLong, help: "The desired width in pixels.")
    var width: UInt?
    
    @Option(name: .shortAndLong, help: "The desired height in pixels.")
    var height: UInt?
    
    @Option(name: .customLong("px-width"), help: "The desired width in actual pixels.")
    var pixelWidth: UInt?
    
    @Option(name: .customLong("px-height"), help: "The desired height in actual pixels.")
    var pixelHeight: UInt?
     
    @Option(name: [.short, .customLong("rate")], help: "The desired refresh rate in Hz.")
    var refreshRate: Double?
    
    @Option(name: [.short, .customLong("mode")], help: "The desired display mode index to set.")
    var modeIndex: Int32?

    mutating func run() throws {
        guard let screen = NSScreen.main else { throw ModeSelectorError.noScreen }
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        
        guard let display = screen.deviceDescription[key] as? CGDirectDisplayID else {
          throw ModeSelectorError.noDisplay
        }
        
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true]
        
        guard let allModes = CGDisplayCopyAllDisplayModes(display, options as CFDictionary) as? [CGDisplayMode] else {
            throw ModeSelectorError.invalidDisplay
        }
            
        let modes = allModes.enumerated().filter { (index, _) in
            guard let modeIndex = modeIndex else { return true }
            return index == modeIndex
        }.filter { (_, mode) in
            guard let width = width else { return true }
            return mode.width == width
        }.filter { (_, mode) in
            guard let height = height else { return true }
            return mode.height == height
        }.filter { (_, mode) in
            guard let pixelWidth = pixelWidth else { return true }
            return mode.pixelWidth == pixelWidth
        }.filter { (_, mode) in
            guard let pixelHeight = pixelHeight else { return true }
            return mode.pixelHeight == pixelHeight
        }.filter { (_, mode) in
            guard let refreshRate = refreshRate else { return true }
            return mode.refreshRate > Double(refreshRate) - 1
        }.sorted {
            if $0.element.pixelWidth * $0.element.pixelHeight < $1.element.pixelWidth * $1.element.pixelHeight { return true }
            if $0.element.refreshRate < $1.element.refreshRate { return true }
            if $0.element.width * $0.element.height < $1.element.width * $1.element.height { return true }
            return $0.offset < $1.offset
        }.reversed()
    
        guard modes.count <= 1 else {
            for (index, mode) in modes {
                print(index, mode)
            }
            return
        }
    
        guard let mode = modes.first?.element else {
            throw ModeSelectorError.noMatchingModes
        }
        
        var config: CGDisplayConfigRef?

        if let error = CGBeginDisplayConfiguration(&config).mapError() {
            throw ModeSelectorError.coreGraphicsError(error)
        }
        
        if let error = CGConfigureDisplayWithDisplayMode(config, display, mode, nil).mapError() {
            CGCancelDisplayConfiguration(config)
            throw ModeSelectorError.coreGraphicsError(error)
        }
        
        if let error = CGCompleteDisplayConfiguration(config, .permanently).mapError() {
            throw ModeSelectorError.coreGraphicsError(error)
        }
    }
}

ModeSelector.main()
