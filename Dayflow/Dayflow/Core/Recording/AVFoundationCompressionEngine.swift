//
//  AVFoundationCompressionEngine.swift
//  Dayflow
//
//  AVFoundation-based H.265/H.264 video compression implementation.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation
import AVFoundation
import CoreMedia

/// AVFoundation-based compression engine with H.265/H.264 support
final class AVFoundationCompressionEngine: CompressionEngine {
    // MARK: - Properties

    var compressionSettings: CompressionSettings
    private(set) var currentChunkSize: Int64 = 0
    private(set) var currentFrameCount: Int = 0

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStartTime: CMTime?
    private var lastFrameTime: CMTime?

    // Performance metrics
    private var compressionTimes: [TimeInterval] = []
    private var startTime: Date?

    // MARK: - Initialization

    init(settings: CompressionSettings = .default(width: 1920, height: 1080)) {
        self.compressionSettings = settings
    }

    // MARK: - CompressionEngine Protocol

    var isReadyForData: Bool {
        guard let writer = writer, let input = input else { return false }
        return writer.status == .writing && input.isReadyForMoreMediaData
    }

    func initialize(settings: CompressionSettings, outputURL: URL) async throws {
        self.compressionSettings = settings
        self.outputURL = outputURL

        // Verify codec availability
        if !settings.codec.isHardwareEncodingAvailable() {
            print("⚠️ Hardware encoding not available for \(settings.codec.rawValue), performance may be degraded")
        }

        // Check disk space
        guard checkDiskSpace(for: outputURL) else {
            throw CompressionError.insufficientDiskSpace
        }

        // Create AVAssetWriter
        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            // Create input with compression settings
            let input = createAssetWriterInput(settings: settings)

            // Configure writer
            guard writer.canAdd(input) else {
                throw CompressionError.failedToAddInput
            }
            writer.add(input)

            // Start writing
            guard writer.startWriting() else {
                let error = writer.error ?? CompressionError.failedToStartWriting
                print("❌ AVAssetWriter.startWriting() failed: \(error)")
                throw CompressionError.failedToStartWriting
            }

            self.writer = writer
            self.input = input
            self.sessionStartTime = nil
            self.lastFrameTime = nil
            self.currentChunkSize = 0
            self.currentFrameCount = 0
            self.compressionTimes = []
            self.startTime = Date()

            print("✅ Compression engine initialized: \(settings.codec.rawValue), \(settings.width)x\(settings.height), \(settings.targetBitrate) bps")
        } catch {
            print("❌ Failed to initialize compression engine: \(error)")
            throw CompressionError.failedToCreateWriter
        }
    }

    func compress(frame: CVPixelBuffer, timestamp: CMTime) async throws {
        let compressionStart = Date()

        guard let writer = writer, let input = input else {
            throw CompressionError.writerNotInitialized
        }

        // Validate timestamp
        guard timestamp.isValid else {
            throw CompressionError.frameTimestampInvalid
        }

        // Start session with first frame
        if sessionStartTime == nil {
            writer.startSession(atSourceTime: timestamp)
            sessionStartTime = timestamp
        }

        // Wait for input to be ready (with timeout)
        let maxWaitTime: TimeInterval = 1.0  // 1 second timeout
        let startWait = Date()
        while !input.isReadyForMoreMediaData {
            if Date().timeIntervalSince(startWait) > maxWaitTime {
                print("⚠️ Compression input not ready after \(maxWaitTime)s, frame may be dropped")
                throw CompressionError.writerNotReady
            }
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }

        // Check writer status
        guard writer.status == .writing else {
            print("❌ Writer status is not writing: \(writer.status.rawValue)")
            throw CompressionError.writerNotReady
        }

        // Create sample buffer from pixel buffer
        let sampleBuffer = try createSampleBuffer(from: frame, timestamp: timestamp)

        // Append frame
        if input.append(sampleBuffer) {
            currentFrameCount += 1
            lastFrameTime = timestamp

            // Estimate compressed size (approximate)
            let frameSize = estimateFrameSize()
            currentChunkSize += frameSize

            // Track compression performance
            let compressionTime = Date().timeIntervalSince(compressionStart)
            compressionTimes.append(compressionTime)

            // Log performance metrics every 100 frames
            if currentFrameCount % 100 == 0 {
                let avgTime = compressionTimes.suffix(100).reduce(0, +) / Double(min(100, compressionTimes.count))
                print("📊 Compression metrics: \(currentFrameCount) frames, avg time: \(Int(avgTime * 1000))ms/frame, size: \(currentChunkSize / Int64(currentFrameCount)) bytes/frame")
            }
        } else {
            print("❌ Failed to append frame at timestamp: \(timestamp.seconds)")
            throw CompressionError.failedToAppendFrame
        }
    }

    func finalizeChunk() async throws -> CompressedChunk {
        guard let writer = writer, let outputURL = outputURL, let startTime = startTime else {
            throw CompressionError.writerNotInitialized
        }

        // Mark input as finished
        input?.markAsFinished()

        // Finish writing
        await writer.finishWriting()

        // Check for errors
        if writer.status == .failed {
            if let error = writer.error {
                print("❌ Writer failed during finalization: \(error)")
            }
            throw CompressionError.failedToFinishWriting
        }

        // Get file size
        let fileSize = getFileSize(at: outputURL)

        // Calculate duration
        let duration = lastFrameTime?.seconds ?? 0.0

        // Calculate compression ratio (estimate)
        // Original size: width * height * 4 bytes (RGBA) * frameCount
        let originalSize = Int64(compressionSettings.width * compressionSettings.height * 4 * currentFrameCount)
        let compressionRatio = originalSize > 0 ? Double(originalSize) / Double(fileSize) : 1.0

        // Calculate average compression time
        let avgCompressionTime = compressionTimes.isEmpty ? 0.0 : compressionTimes.reduce(0, +) / Double(compressionTimes.count)

        print("✅ Chunk finalized: \(currentFrameCount) frames, \(fileSize / 1024) KB, ratio: \(String(format: "%.1f", compressionRatio)):1, avg time: \(Int(avgCompressionTime * 1000))ms/frame")

        // Create chunk metadata
        let chunk = CompressedChunk(
            fileURL: outputURL,
            size: fileSize,
            duration: duration,
            compressionRatio: compressionRatio,
            frameCount: currentFrameCount,
            createdAt: startTime,
            settings: compressionSettings
        )

        // Reset for next chunk
        reset()

        return chunk
    }

    func estimateChunkSize(frameCount: Int) -> Int64 {
        // Estimate based on target bitrate and frame count
        // At 1 FPS: targetBitrate (bits per second) / 8 (bytes) * frameCount (seconds)
        let estimatedBits = Int64(compressionSettings.targetBitrate) * Int64(frameCount)
        return estimatedBits / 8
    }

    func reset() {
        writer = nil
        input = nil
        outputURL = nil
        sessionStartTime = nil
        lastFrameTime = nil
        currentChunkSize = 0
        currentFrameCount = 0
        compressionTimes = []
        startTime = nil
    }

    // MARK: - Private Helper Methods

    private func createAssetWriterInput(settings: CompressionSettings) -> AVAssetWriterInput {
        var outputSettings: [String: Any] = [
            AVVideoCodecKey: settings.codec.avCodecType,
            AVVideoWidthKey: settings.width,
            AVVideoHeightKey: settings.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.targetBitrate,
                AVVideoMaxKeyFrameIntervalKey: settings.keyFrameInterval,
                AVVideoAllowFrameReorderingKey: false,  // Simpler encoding, lower CPU
            ]
        ]

        // Add codec-specific settings
        if settings.codec == .h264 {
            if var compressionProps = outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any] {
                compressionProps[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
                compressionProps[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
                outputSettings[AVVideoCompressionPropertiesKey] = compressionProps
            }
        } else if settings.codec == .hevc {
            // H.265 specific settings for better compression
            if var compressionProps = outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any] {
                compressionProps[AVVideoExpectedSourceFrameRateKey] = 1  // 1 FPS
                outputSettings[AVVideoCompressionPropertiesKey] = compressionProps
            }
        }

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true
        input.transform = CGAffineTransform.identity

        return input
    }

    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, timestamp: CMTime) throws -> CMSampleBuffer {
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 1),  // 1 second duration at 1 FPS
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMFormatDescription?

        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDesc = formatDescription else {
            throw CompressionError.failedToAppendFrame
        }

        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        guard createStatus == noErr, let buffer = sampleBuffer else {
            throw CompressionError.failedToAppendFrame
        }

        return buffer
    }

    private func estimateFrameSize() -> Int64 {
        // Estimate based on target bitrate
        // At 1 FPS: targetBitrate / 8 = bytes per frame
        return Int64(compressionSettings.targetBitrate / 8)
    }

    private func checkDiskSpace(for url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                // Require at least 500MB free space
                let minimumRequired: Int64 = 500 * 1024 * 1024
                return capacity >= minimumRequired
            }
        } catch {
            print("⚠️ Could not check disk space: \(error)")
        }
        return true  // Assume OK if can't check
    }

    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? NSNumber)?.int64Value ?? 0
        } catch {
            print("⚠️ Could not get file size: \(error)")
            return 0
        }
    }
}
