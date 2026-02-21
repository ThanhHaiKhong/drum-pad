import AudioEngineClient
@preconcurrency import AudioKit
import Foundation
import AVFoundation

typealias NodeStatus = AudioKit.NodeStatus

final class AudioEngineDelegate: @unchecked Sendable {
    private struct PadEvent {
        let time: TimeInterval
        let sampleURL: URL
        let velocity: Float
    }

    private let logger: @Sendable (String) -> Void

    private var engine: AudioEngine
    private var padPlayers: [AudioEngineClient.DrumPad.ID: AudioPlayer] = [:]
    private var pads: [AudioEngineClient.DrumPad] = []
    private var currentPresetID: String?
    
    // MARK: - Choke Group Management
    private let chokeGroupManager: ChokeGroupManager
    private let positionUpdateManager = PositionUpdateManager()
    
    private var currentPresetTempo: Int = 0
    private var currentPreset: AudioEngineClient.Preset?

    private var recordingStartTime: Date?
    private var recordingFilePath: String?
    private var lastRecordedFilePath: String?
    private var isRecordingOnlyPadSounds: Bool = false
    private var recordedEvents: [PadEvent] = []
    private var recordingStartTimeOffset: TimeInterval = 0

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("🎵 [AUDIO_ENGINE_DELEGATE]: \(message)")
            #endif
        }
    ) {
        self.logger = logger
        self.engine = AudioEngine()
        let mixer = Mixer()
        engine.output = mixer
        self.chokeGroupManager = ChokeGroupManager()

        do {
            try engine.start()
            logger("Audio engine started successfully")
        } catch {
            logger("Audio engine failed to start: \(error)")
        }
    }

    deinit {
        for (_, player) in padPlayers {
            if player.status == .playing {
                player.stop()
            }
        }
        padPlayers.removeAll()
    }

    // MARK: - Public Methods

    func loadPreset(
        _ presetId: String
    ) async throws {
        logger("Loading preset: \(presetId)")

        if let presetURL = findPresetFile(named: presetId) {
            // Stop all current playback
            for (_, player) in padPlayers {
                if player.status == .playing {
                    player.stop()
                }
            }
            
            // Clear choke group tracking
            await chokeGroupManager.clearAll()
            
            let newPads = try await loadPresetFromURL(presetURL, presetId: presetId)
            self.currentPresetID = presetId
            self.pads = newPads

            logger("Successfully loaded preset: \(presetId) with \(newPads.count) pads")
        } else {
            logger("Preset file not found in bundle, creating a minimal default preset with actual file paths")
        }
    }

    func playPad(
        _ padID: AudioEngineClient.DrumPad.ID
    ) async throws {
        logger("▶️ Playing pad with ID: \(padID)")

        guard let pad = pads.first(where: { $0.id == padID }) else {
            throw AudioEngineClient.Error.padNotFound(padId: padID)
        }

        let sample = pad.sample
        let samplePath = sample.path

        guard let sampleURL = URL(string: samplePath) else {
            throw AudioEngineClient.Error.sampleNotFound(path: samplePath)
        }

        // MARK: - Choke Group Logic
        // Get pads to choke BEFORE we register this pad
        let padsToChoke = await chokeGroupManager.getPadsToChoke(
            inGroup: pad.chokeGroup,
            excluding: padID
        )
        
        // Stop other players in the same choke group
        for otherPadID in padsToChoke {
            if let otherPlayer = padPlayers[otherPadID], otherPlayer.status == .playing {
                logger("🔇 Choking pad \(otherPadID) (choke group \(pad.chokeGroup))")
                otherPlayer.stop()
            }
        }

        var player = padPlayers[padID]

        if player == nil {
            let newPlayer = AudioPlayer()
            try newPlayer.load(url: sampleURL)

            if let mixer = engine.output as? Mixer {
                let newMixer = Mixer(mixer, newPlayer)
                engine.output = newMixer
            } else {
                engine.output = newPlayer
            }
            player = newPlayer
            padPlayers[padID] = player
        }

        guard let player = player else {
            throw AudioEngineClient.Error.sampleNotFound(path: samplePath)
        }

        player.seek(time: 0.0)
        if player.status == .playing {
            player.stop()
        }

        // MARK: - Register this pad in choke group
        await chokeGroupManager.registerPlaying(padID: padID, chokeGroup: pad.chokeGroup)

        if isRecordingOnlyPadSounds, let sampleURL = URL(string: sample.path) {
            let event = PadEvent(
                time: CACurrentMediaTime() - recordingStartTimeOffset,
                sampleURL: sampleURL,
                velocity: 1.0
            )
            recordedEvents.append(event)
            logger("Added pad event to recording: \(padID)")
        }

        player.start()
        logger("▶️ Pad \(padID) started (choke group \(pad.chokeGroup))")
    }

    func drumPads() async -> [AudioEngineClient.DrumPad] {
        return pads
    }

    func currentPresetID() async -> String? {
        return currentPresetID
    }

    func positionUpdates(for padID: AudioEngineClient.DrumPad.ID) -> AsyncStream<AudioEngineClient.PositionUpdate> {
        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                guard let `self` = self else { return }

                await self.positionUpdateManager.addContinuation(for: padID, continuation: continuation)

                continuation.onTermination = { [weak self] _ in
                    Task { [weak self] in
                        guard let `self` = self else { return }
                        await self.positionUpdateManager.removeContinuation(for: padID)
                    }
                }

                await self.emitPositionUpdates(for: padID, continuation: continuation)
            }
        }
    }

    private func emitPositionUpdates(
        for padID: AudioEngineClient.DrumPad.ID,
        continuation: AsyncStream<AudioEngineClient.PositionUpdate>.Continuation
    ) async {
        var lastEmittedTime: Double? = nil
        let debounceThreshold: TimeInterval = 0.05
        var hasCompleted = false

        defer {
            logger("Position updates ended for pad \(padID)")
        }

        while !Task.isCancelled {
            guard await positionUpdateManager.hasContinuation(for: padID) else {
                break
            }

            // Access player directly (AudioPlayer is thread-safe)
            guard let player = padPlayers[padID] else {
                try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
                continue
            }

            let duration = player.duration
            let currentTime = player.currentTime
            let isPlaying = player.status == NodeStatus.Playback.playing
            let isCompleted = !isPlaying || currentTime >= duration

            // Handle completion state
            if isCompleted && !hasCompleted {
                // Yield final position (100%)
                let finalPosition = AudioEngineClient.PositionUpdate(
                    padId: padID,
                    currentTime: duration,
                    duration: duration
                )

                logger("🏁 currentTime: \(duration), duration: \(duration) - Playback completed")
                continuation.yield(finalPosition)

                // Yield reset position (0%) to reset UI
                let resetPosition = AudioEngineClient.PositionUpdate(
                    padId: padID,
                    currentTime: 0,
                    duration: duration
                )

                logger("🔄 currentTime: 0, duration: \(duration) - Position reset")
                continuation.yield(resetPosition)

                // MARK: - Unregister from choke group when playback completes
                if let pad = pads.first(where: { $0.id == padID }) {
                    await chokeGroupManager.unregister(padID: padID, chokeGroup: pad.chokeGroup)
                    logger("🏁 Pad \(padID) unregistered from choke group \(pad.chokeGroup)")
                }
                
                hasCompleted = true
                break  // Exit loop after completion
            }

            // Emit position updates during playback
            if isPlaying && currentTime >= 0 && duration > 0 {
                let shouldEmit: Bool
                if let lastTime = lastEmittedTime {
                    shouldEmit = abs(currentTime - lastTime) >= debounceThreshold
                } else {
                    shouldEmit = true  // Always emit first update
                }

                if shouldEmit {
                    let positionUpdate = AudioEngineClient.PositionUpdate(
                        padId: padID,
                        currentTime: currentTime,
                        duration: duration
                    )

                    logger("currentTime: \(currentTime), duration: \(duration)")
                    continuation.yield(positionUpdate)
                    lastEmittedTime = currentTime
                }
            }

            // Adaptive sleep interval - poll faster near end of playback
            let sleepInterval: TimeInterval
            if isPlaying && currentTime >= duration * 0.95 {
                sleepInterval = 0.01  // 10ms near end
            } else if isPlaying {
                sleepInterval = 0.02  // 20ms during normal playback
            } else {
                sleepInterval = 0.1   // 100ms when idle
            }

            try? await Task.sleep(nanoseconds: UInt64(sleepInterval * 1_000_000_000))
        }
    }

    func sampleDuration(at path: String) async throws -> Double {
        logger("Getting duration for sample at path: \(path)")

        if path.isEmpty {
            logger("Empty path detected, returning default duration")
            return 1.0
        }

        guard let sampleURL = URL(string: path) else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        guard let audioFile = try? AVAudioFile(forReading: sampleURL) else {
            logger("Could not load audio file for duration calculation: \(path)")
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        logger("Duration for \(path) is \(duration) seconds")

        return duration
    }

    func isRecording() async -> Bool {
        return recordingStartTime != nil
    }

    func startRecording() async throws {
        logger("Starting pad-only recording with AVAudioEngine")

        guard !(await isRecording()) else {
            logger("Recording already in progress")
            throw AudioEngineClient.Error.recordingInProgress
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "pad_recording_\(timestamp).wav"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(fileName).path

        recordingFilePath = filePath
        recordingStartTime = Date()
        recordingStartTimeOffset = CACurrentMediaTime()
        isRecordingOnlyPadSounds = true
        recordedEvents = []

        logger("Pad-only recording started successfully at path: \(filePath)")
    }

    func stopRecording() async throws -> String? {
        logger("Stopping pad-only recording with AVAudioEngine")

        guard recordingStartTime != nil else {
            logger("No active recording to stop")
            return nil
        }

        guard let filePath = recordingFilePath else {
            logger("Recording file path not available")
            return nil
        }

        try await performManualRendering(to: URL(fileURLWithPath: filePath))

        lastRecordedFilePath = filePath

        let returnedPath = recordingFilePath
        self.recordingFilePath = nil
        self.recordingStartTime = nil
        self.isRecordingOnlyPadSounds = false
        self.recordedEvents.removeAll()

        logger("Pad-only recording stopped successfully, saved to: \(returnedPath ?? "unknown")")
        return returnedPath
    }

    func playRecordedAudio() async throws {
        guard let recordedFilePath = lastRecordedFilePath else {
            logger("No recorded audio file to play")
            throw AudioEngineClient.Error.sampleNotFound(path: "No recorded file available")
        }

        logger("Playing recorded audio from path: \(recordedFilePath)")
    }

    // MARK: - Private Helper Methods

    private func performManualRendering(to outputURL: URL) async throws {
        logger("Performing manual rendering to: \(outputURL.path)")

        guard !recordedEvents.isEmpty else {
            logger("No events recorded, creating a minimal silent file")
            try createSilentFile(at: outputURL)
            return
        }

        var totalDuration = recordedEvents.last?.time ?? 0.0

        for event in recordedEvents {
            guard let audioFile = try? AVAudioFile(forReading: event.sampleURL) else {
                logger("Could not load audio file: \(event.sampleURL.path)")
                continue
            }
            let sampleDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            let eventEndTime = event.time + sampleDuration
            if eventEndTime > totalDuration {
                totalDuration = eventEndTime
            }
        }

        if totalDuration < 0.1 {
            totalDuration = 0.1
        }

        let sampleRate: Double = 44100.0
        let channels: AVAudioChannelCount = 2
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)

        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!

        let mixedBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!

        if let channelData = mixedBuffer.floatChannelData {
            for i in 0 ..< Int(channels) {
                memset(channelData[i], 0, Int(frameCount) * MemoryLayout<Float>.size)
            }
        }
        mixedBuffer.frameLength = frameCount

        for event in recordedEvents {
            guard let audioFileToMix = try? AVAudioFile(forReading: event.sampleURL) else {
                logger("Could not load audio file: \(event.sampleURL.path)")
                continue
            }

            let sampleBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFileToMix.processingFormat,
                frameCapacity: AVAudioFrameCount(audioFileToMix.length)
            )!

            try audioFileToMix.read(into: sampleBuffer)

            mixSampleIntoBuffer(sampleBuffer, at: event.time, into: mixedBuffer, sampleRate: sampleRate)
        }

        let audioFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat.settings)
        try audioFile.write(from: mixedBuffer)

        logger("Manual rendering completed with actual audio data")
    }

    private func createSilentFile(at url: URL) throws {
        let sampleRate: Double = 44100.0
        let channels: AVAudioChannelCount = 2
        let duration: Double = 1.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let audioFile = try AVAudioFile(forWriting: url, settings: audioFormat.settings)
        let silentBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!

        if let channelData = silentBuffer.floatChannelData {
            for i in 0 ..< Int(channels) {
                memset(channelData[i], 0, Int(frameCount) * MemoryLayout<Float>.size)
            }
        }
        silentBuffer.frameLength = frameCount

        try audioFile.write(from: silentBuffer)
    }

    private func mixSampleIntoBuffer(
        _ sampleBuffer: AVAudioPCMBuffer,
        at startTime: TimeInterval,
        into mixedBuffer: AVAudioPCMBuffer,
        sampleRate: Double
    ) {
        guard let sampleData = sampleBuffer.floatChannelData,
              let mixedData = mixedBuffer.floatChannelData else {
            logger("Could not get float channel data for mixing")
            return
        }

        let channels = Int(mixedBuffer.format.channelCount)
        let startFrame = AVAudioFramePosition(startTime * sampleRate)

        let sampleFrames = sampleBuffer.frameLength
        let endFrame = min(startFrame + AVAudioFramePosition(sampleFrames), AVAudioFramePosition(mixedBuffer.frameLength))

        for channel in 0..<channels {
            let sourceChannel = sampleData[channel]
            let destChannel = mixedData[channel]

            for frame in 0..<(endFrame - startFrame) {
                let sourceIndex = Int(frame)
                let destIndex = Int(startFrame + frame)

                destChannel[destIndex] += sourceChannel[sourceIndex]
            }
        }
    }

    // MARK: - File Handling Methods
    
    func findPresetFile(
        named presetId: String
    ) -> URL? {
        logger("Searching for preset: \(presetId)")

        var presetURL: URL?

        presetURL = Bundle.module.url(
            forResource: "drumpad-presets-\(presetId)",
            withExtension: "json",
            subdirectory: "Presets"
        )

        if presetURL == nil {
            presetURL = Bundle.module.url(
                forResource: "drumpad-presets-\(presetId)",
                withExtension: "json"
            )
        }

        if presetURL == nil {
            presetURL = Bundle.main.url(
                forResource: "drumpad-presets-\(presetId)",
                withExtension: "json",
                subdirectory: "Presets"
            )
        }

        if presetURL == nil {
            presetURL = Bundle.main.url(
                forResource: "drumpad-presets-\(presetId)",
                withExtension: "json"
            )
        }

        if let foundURL = presetURL {
            logger("Found preset file at: \(foundURL.path)")
        } else {
            logger("Preset file not found for: \(presetId)")
        }

        return presetURL
    }

    func findSampleFile(
        named filename: String
    ) -> URL? {
        logger("Searching for sample: \(filename)")

        var sampleURL = Bundle.module.url(
            forResource: filename.replacingOccurrences(of: ".wav", with: ""),
            withExtension: "wav",
            subdirectory: "Samples"
        )

        if sampleURL == nil {
            sampleURL = Bundle.module.url(
                forResource: filename,
                withExtension: nil,
                subdirectory: "Samples"
            )
        }

        if sampleURL == nil {
            sampleURL = Bundle.main.url(
                forResource: filename.replacingOccurrences(of: ".wav", with: ""),
                withExtension: "wav",
                subdirectory: "Samples"
            )
        }

        if sampleURL == nil {
            sampleURL = Bundle.main.url(
                forResource: filename,
                withExtension: nil,
                subdirectory: "Samples"
            )
        }

        if sampleURL == nil {
            sampleURL = Bundle.main.url(
                forResource: filename.replacingOccurrences(of: ".wav", with: ""),
                withExtension: "wav"
            )
        }

        if sampleURL == nil {
            sampleURL = Bundle.main.url(
                forResource: filename,
                withExtension: nil
            )
        }

        if let foundURL = sampleURL {
            logger("Found sample file at: \(foundURL.path)")
        } else {
            logger("Sample file not found: \(filename)")
        }

        return sampleURL
    }

    func copyResourceToDocumentsIfNeeded(
        resourceName: String,
        ofType: String?
    ) async -> URL? {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

            let targetURL = documentsDirectory.appendingPathComponent(resourceName)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                logger("Resource already exists in documents: \(resourceName)")
                return targetURL
            }

            var sourceURL: URL?

            sourceURL = Bundle.module.url(forResource: resourceName, withExtension: ofType)

            if sourceURL == nil {
                sourceURL = Bundle.main.url(forResource: resourceName, withExtension: ofType)
            }

            if sourceURL == nil {
                if ofType == nil, resourceName.contains(".") {
                    let nameWithoutExt = resourceName.components(separatedBy: ".").dropLast().joined(separator: ".")
                    let ext = resourceName.split(separator: ".").last!

                    sourceURL = Bundle.module.url(forResource: nameWithoutExt, withExtension: String(ext))

                    if sourceURL == nil {
                        sourceURL = Bundle.main.url(forResource: nameWithoutExt, withExtension: String(ext))
                    }
                }
            }

            guard let sourceURL = sourceURL else {
                logger("Could not find source resource: \(resourceName)")
                return nil
            }

            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            logger("Copied resource to documents: \(resourceName)")

            return targetURL
        } catch {
            logger("Failed to copy resource to documents: \(resourceName), error: \(error)")
            return nil
        }
    }

    func loadPresetFromURL(
        _ presetURL: URL,
        presetId: String
    ) async throws -> [AudioEngineClient.DrumPad] {
        do {
            let jsonData = try Data(contentsOf: presetURL)
            let decoder = JSONDecoder()

            // Decode full Preset model
            let preset = try decoder.decode(AudioEngineClient.Preset.self, from: jsonData)
            
            // Store preset metadata
            self.currentPresetTempo = preset.tempo
            self.currentPreset = preset
            
            logger("Loaded preset '\(preset.name)' at \(preset.tempo) BPM with \(preset.pads.count) pads")
            
            var newPads: [AudioEngineClient.DrumPad] = []
            
            for pad in preset.pads {
                let sampleURL = findSampleFile(named: pad.sample.filename)
                
                var finalSampleURL: URL?
                if let sampleURL = sampleURL {
                    finalSampleURL = sampleURL
                } else {
                    finalSampleURL = await copyResourceToDocumentsIfNeeded(
                        resourceName: pad.sample.filename,
                        ofType: nil
                    )
                }
                
                guard let finalSampleURL = finalSampleURL else {
                    logger("Sample file not found: \(pad.sample.filename), skipping...")
                    continue
                }

                // Create new pad with actual file path
                let newPad = AudioEngineClient.DrumPad(
                    id: pad.id,
                    sample: AudioEngineClient.DrumPad.Sample(
                        id: pad.sample.id,
                        filename: pad.sample.filename,
                        name: pad.sample.name,
                        path: finalSampleURL.absoluteString
                    ),
                    color: pad.color,
                    chokeGroup: pad.chokeGroup
                )
                newPads.append(newPad)
            }
            
            logger("Successfully processed preset: \(presetId) with \(newPads.count) pads")
            
            return newPads.sorted { $0.id < $1.id }
            
        } catch let decodingError as DecodingError {
            logger("Failed to decode preset \(presetId): \(decodingError)")
            throw AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: decodingError)
        } catch {
            logger("Failed to process preset \(presetId): \(error)")
            throw AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: error)
        }
    }

    func createDefaultPreset(presetId: String) -> (
        samples: [Int: AudioEngineClient.DrumPad.Sample],
        pads: [Int: AudioEngineClient.DrumPad]
    ) {
        logger("Creating default preset with actual file paths for: \(presetId)")

        var samples: [Int: AudioEngineClient.DrumPad.Sample] = [:]
        var pads: [Int: AudioEngineClient.DrumPad] = [:]

        for i in 1...24 {
            let filename = String(format: "%02d.wav", i)

            var sampleURL: URL?

            sampleURL = Bundle.module.url(
                forResource: String(format: "%02d", i),
                withExtension: "wav",
                subdirectory: "Samples"
            )

            if sampleURL == nil {
                sampleURL = Bundle.module.url(
                    forResource: String(format: "%02d", i),
                    withExtension: "wav"
                )
            }

            if sampleURL == nil {
                sampleURL = Bundle.main.url(
                    forResource: String(format: "%02d", i),
                    withExtension: "wav",
                    subdirectory: "Samples"
                )
            }

            if sampleURL == nil {
                sampleURL = Bundle.main.url(
                    forResource: String(format: "%02d", i),
                    withExtension: "wav"
                )
            }

            if sampleURL == nil {
                sampleURL = Bundle.module.url(
                    forResource: String(format: "%02d.wav", i),
                    withExtension: nil
                )
            }

            if sampleURL == nil {
                sampleURL = Bundle.main.url(
                    forResource: String(format: "%02d.wav", i),
                    withExtension: nil
                )
            }

            let samplePath = sampleURL?.absoluteString ?? ""

            let sample = AudioEngineClient.DrumPad.Sample(
                id: i,
                filename: filename,
                name: "Sample \(i)",
                path: samplePath
            )

            samples[i] = sample
            pads[i] = AudioEngineClient.DrumPad(
                id: i,
                sample: sample,
                color: ["red", "blue", "green", "yellow", "purple"].randomElement()!,
                chokeGroup: i % 4
            )
        }

        logger("Created default preset with \(samples.count) samples, \(samples.values.filter { !$0.path.isEmpty }.count) with actual file paths")

        return (samples: samples, pads: pads)
    }

    // MARK: - Preset Metadata Accessors

    func currentTempo() async -> Int {
        return currentPresetTempo
    }

    func preset() async -> AudioEngineClient.Preset? {
        return currentPreset
    }
}

extension UInt32 {
    var bytes: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

extension UInt16 {
    var bytes: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}
