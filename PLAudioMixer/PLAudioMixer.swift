//
//  PLAudioMixer.swift
//  PLAudioMixer
//
//  Created by Patrick Lin on 22/10/2017.
//  Copyright © 2017 Patrick Lin. All rights reserved.
//

import Foundation
import AVFoundation

public protocol PLAudioMixerDelegate: NSObjectProtocol {
    
    func mixer(_ mixer: PLAudioMixer, didRender pcmBuffer: AVAudioPCMBuffer, userInfo: [String: Any]?)
    
}

public class PLAudioMixer: NSObject {
    
    fileprivate var audioEngine: AVAudioEngine = AVAudioEngine()
    
    fileprivate var sources: [PLAudioSource] = [PLAudioSource]()
    
    fileprivate var renderedBuffer: AVAudioPCMBuffer?
    
    public var processingFormat: AVAudioFormat
    
    public var maximumFrameCount: AVAudioFrameCount = 960
    
    public weak var delegate: PLAudioMixerDelegate?
    
    // MARK: Internal Methods
    
    fileprivate func indexOfSource(identifier: String) -> Int? {
        
        let index = self.sources.firstIndex { (source: PLAudioSource) -> Bool in
            
            return source.identifier == identifier
            
        }
        
        return index
        
    }
    
    fileprivate func containsOfSource(identifier: String) -> Bool {
        
        let isExist = (self.indexOfSource(identifier: identifier) != nil) ? true : false
        
        return isExist
        
    }
    
    // MARK: Public Methods
    
    public func attach(identifier: String) -> Bool {
        
        guard self.containsOfSource(identifier: identifier) == false else { return false }
        
        let source = PLAudioSource(identifier: identifier)
        
        self.audioEngine.attach(source.playerNode)
        
        self.sources.append(source)
        
        return true
        
    }
    
    public func detach(identifier: String) -> Bool {
        
        guard let index = self.indexOfSource(identifier: identifier) else { return false }
        
        let source = self.sources[index]
        
        self.audioEngine.detach(source.playerNode)
        
        self.sources.remove(at: index)
        
        return true
        
    }
    
    @discardableResult
    public func start() -> Bool {
        
        do {
            
            self.audioEngine.stop()
            
            for (_, source) in self.sources.enumerated() {
                
                self.audioEngine.connect(source.playerNode, to: self.audioEngine.mainMixerNode, format: self.processingFormat)
                
            }
            
            try self.audioEngine.enableManualRenderingMode(.offline, format: self.processingFormat, maximumFrameCount: self.maximumFrameCount)
            
            try self.audioEngine.start()
            
            for (_, source) in self.sources.enumerated() {

                source.playerNode.play()

            }
            
            self.renderedBuffer = AVAudioPCMBuffer(pcmFormat: self.audioEngine.manualRenderingFormat, frameCapacity: self.audioEngine.manualRenderingMaximumFrameCount)
            
            return true
            
        }
            
        catch {
            
            return false
            
        }
        
    }
    
    public func stop() {
        
        self.audioEngine.stop()
        
        for (_, source) in self.sources.enumerated() {
            
            source.playerNode.stop()
            
        }
        
    }
    
    public func setVolume(identifier: String, volume: Float) {
        
        if let index = self.indexOfSource(identifier: identifier) {
            
            let source = self.sources[index]
            
            source.volume = volume
            
        }
        
    }
    
    public func getVolume(identifier: String, volume: Float) -> Float? {
        
        if let index = self.indexOfSource(identifier: identifier) {
            
            let source = self.sources[index]
            
            return source.volume
            
        }
        
        return nil
        
    }
    
    public func appendBuffer(identifier: String, pcmBuffer: AVAudioPCMBuffer) {
        
        if let index = self.indexOfSource(identifier: identifier) {
            
            let source = self.sources[index]
            
            source.playerNode.volume = source.volume
            
            source.playerNode.scheduleBuffer(pcmBuffer, completionHandler: nil)
            
            source.samples += pcmBuffer.frameLength
        }
    }
    
    @discardableResult
    public func render(userInfo: [String: Any]? = nil) -> PLAudioMixerRenderStatus {
        
        guard let renderedBuffer = self.renderedBuffer else { return .error }
        
        let rendering_sources = self.sources.filter { (source) -> Bool in
            //print("source sample : \(source.identifier) : \(source.samples) limit:\(self.audioEngine.manualRenderingMaximumFrameCount)")
            return source.samples >= self.audioEngine.manualRenderingMaximumFrameCount
            
        }
        if rendering_sources.count > 0 {
            
            let status = try! self.audioEngine.renderOffline(self.audioEngine.manualRenderingMaximumFrameCount, to: renderedBuffer)
            
            switch status {
                
            case .success:
                
                self.delegate?.mixer(self, didRender: renderedBuffer, userInfo: userInfo)
                
                for (_, source) in rendering_sources.enumerated() {
                    
                    source.samples -= self.audioEngine.manualRenderingMaximumFrameCount
                    //print("source sample left: \(source.identifier) : \(source.samples) limit:\(self.audioEngine.manualRenderingMaximumFrameCount)")
                }
                
                return .success
                
            case .insufficientDataFromInputNode:
                
                return .insufficientDataFromInputNode
                
            case .cannotDoInCurrentContext:
                
                return .cannotDoInCurrentContext
                
            case .error:
                
                return .error
                
            default:
                return .error
            }
            
        }
        
        return .error
        
    }
    
    // MARK: Init Methods
    
    public required init?(sampleRate: Double, channels: UInt32) {
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)
        
        self.processingFormat = format!
        
    }
    
}

extension PLAudioMixer {
    
    public enum PLAudioMixerRenderStatus {
        
        case success, insufficientDataFromInputNode, cannotDoInCurrentContext, error
        
    }
    
    fileprivate class PLAudioSource {
        
        var identifier: String
        
        var playerNode: AVAudioPlayerNode
        
        var samples: UInt32 = 0
        
        var volume: Float = 1
        
        // MARK: Init Methods
        
        required init(identifier: String) {
            
            self.identifier = identifier
            
            self.playerNode = AVAudioPlayerNode()
            
        }
        
    }
    
}

extension AudioBufferList {
    
    fileprivate mutating func reorderBytes() {
        
        PLAudioMixerUtlis.reorderBuffer(&self)
        
    }
    
}

extension AVAudioPCMBuffer {
    
    public func toStandardSampleBuffer(timescale:Int32 = 48000,frameCount:Int64 ,duration: CMTime? = nil, pts: CMTime? = nil, dts: CMTime? = nil) -> CMSampleBuffer? {
        
        var sampleBuffer: CMSampleBuffer? = nil
        
        let based_pts = pts ?? CMTime.zero
        
        //let new_pts = CMTimeMakeWithSeconds(CMTimeGetSeconds(based_pts), preferredTimescale: based_pts.timescale)
        
        var timing = CMSampleTimingInfo(duration: CMTimeMake(value: 1, timescale: timescale), presentationTimeStamp: CMTimeMake(value: frameCount, timescale: Int32(timescale)), decodeTimeStamp: CMTime.invalid)
        
        var output_format = self.format
        
        var pcmBuffer = self
        
        if ((self.format.streamDescription.pointee.mFormatFlags & kAudioFormatFlagIsSignedInteger) != kAudioFormatFlagIsSignedInteger) {
            
            var convert_asbd = AudioStreamBasicDescription(mSampleRate: self.format.sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked), mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
            
            let covert_format = AVAudioFormat(streamDescription: &convert_asbd)
            
            let covert_buffer = AVAudioPCMBuffer(pcmFormat: covert_format!, frameCapacity: self.frameCapacity)
            
            covert_buffer!.frameLength = covert_buffer!.frameCapacity
            
            PLAudioMixerUtlis.covert32bitsTo16bits(self.mutableAudioBufferList, outputBufferList: covert_buffer?.mutableAudioBufferList)
            
            output_format = covert_format!
            
            pcmBuffer = covert_buffer!
            
        }
        
        guard CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil, formatDescription: output_format.formatDescription, sampleCount: CMItemCount(self.frameLength), sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        
        let error = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer!, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcmBuffer.audioBufferList)
        if error != noErr {
            print("CMSampleBufferSetDataBufferFromAudioBufferList \(error)")
            return nil
        }
        
        return sampleBuffer
        
    }
    
}

extension CMSampleBuffer {
    
    public func toAudioBufferList(reorder: Bool = false) -> AudioBufferList? {
        
        let audioBufferList = AudioBufferList.allocate(maximumBuffers: 1)
        
        var blockBuffer: CMBlockBuffer?
        
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList.unsafeMutablePointer,
            bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: 1),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard status == noErr else { return nil }
        
        if (reorder == true) {
            
            audioBufferList.unsafeMutablePointer.pointee.reorderBytes()
            
        }
        
        return audioBufferList.unsafePointer.pointee
        
    }
    
    public func toStandardPCMBuffer() -> AVAudioPCMBuffer? {
        
        if let fmt = CMSampleBufferGetFormatDescription(self), let asbd =  CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
            
            assert(asbd.mFormatID == kAudioFormatLinearPCM, "only support pcm format")
            
            let reorder = ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagIsBigEndian) ? true : false
            
            guard var audioBufferList = self.toAudioBufferList(reorder: reorder) else { return nil }
            
            let frameCount = CMSampleBufferGetNumSamples(self)
            
            let format = AVAudioFormat(standardFormatWithSampleRate: asbd.mSampleRate, channels: asbd.mChannelsPerFrame)
            
            let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(frameCount))
            
            buffer!.frameLength = buffer!.frameCapacity
            
            if ((asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) == kAudioFormatFlagIsSignedInteger) {
                
                PLAudioMixerUtlis.covert16bitsTo32bits(&audioBufferList, outputBufferList: buffer?.mutableAudioBufferList)
                
            }
            
            return buffer
            
        }
        
        return nil
        
    }
    
}

