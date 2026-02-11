import AudioEngineClient
import AudioKit
import Foundation
import AVFoundation

// Extension to convert integers to little endian bytes
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

// Structure to hold pad event information
struct PadEvent {
    let time: TimeInterval
    let sampleURL: URL
    let velocity: Float
}

actor AudioEngineActor {
    private var engine: AudioEngine
    private var players: [String: AudioPlayer] = [:]
    private var samples: [Int: AudioEngineClient.Sample] = [:]
    private var pads: [Int: AudioEngineClient.DrumPad] = [:]
    private var currentPreset: String?

    // Recording properties for pad-only recording
    private var recordingStartTime: Date?
    private var recordingFilePath: String?
    private var lastRecordedFilePath: String?
    private var isRecordingOnlyPadSounds: Bool = false
    private var recordedEvents: [PadEvent] = []  // Store events for manual rendering
    private var recordingStartTimeOffset: TimeInterval = 0
    
    // Properties for recording
    private var audioPlayerNodes: [URL: AVAudioPlayerNode] = [:] // Cache player nodes for samples
    private var audioFiles: [URL: AVAudioFile] = [:] // Cache audio files

    private let logger: @Sendable (String) -> Void
    private let delegate: AudioEngineDelegate

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("🎵 [AUDIO_ENGINE_LIVE_ACTOR]: \(message)")
            #endif
        }
    ) {
        self.engine = AudioEngine()
        self.logger = logger
        self.delegate = AudioEngineDelegate(logger: logger)

        let mixer = Mixer()
        engine.output = mixer

        do {
            try engine.start()
            logger("Audio engine started successfully")
        } catch {
            logger("Audio engine failed to start: \(error)")
        }
    }

    func loadPreset(presetId: String) async throws {
        logger("Loading preset: \(presetId)")

        if let presetURL = delegate.findPresetFile(named: presetId) {
            let (newSamples, newPads) = try await delegate.loadPresetFromURL(presetURL, presetId: presetId)

            self.samples = newSamples
            self.pads = newPads
            self.currentPreset = presetId

            logger("Successfully loaded preset: \(presetId) with \(newSamples.count) samples")
        } else {
            logger("Preset file not found in bundle, creating a minimal default preset with actual file paths")
            let (defaultSamples, defaultPads) = delegate.createDefaultPreset(presetId: presetId)

            self.samples = defaultSamples
            self.pads = defaultPads
            self.currentPreset = presetId

            logger("Created default preset with \(defaultSamples.count) samples, \(defaultSamples.values.filter { !$0.path.isEmpty }.count) with actual file paths")
        }
    }

    func playSample(at path: String) async throws {
        logger("Playing sample at path: \(path)")

        if path.isEmpty {
            logger("Empty path detected - simulating audio playback for fallback sample")
            try await Task.sleep(nanoseconds: UInt64(100 * 1_000_000))
            return
        }

        guard let sampleURL = URL(string: path) else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        let playerId = path
        var player = players[playerId]

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
            players[playerId] = player
        }

        guard let player = player else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        player.seek(time: 0.0)

        if player.status == .playing {
            player.stop()
        }

        player.play()
    }

    func playPad(padId: Int) async throws {
        logger("Playing pad with ID: \(padId)")

        guard let pad = pads[padId],
                  let sample = samples[pad.sampleId] else {
            throw AudioEngineClient.Error.padNotFound(padId: padId)
        }

        logger("Playing original sample for pad: \(padId)")

        // If we're recording pad sounds only, add this event to the recorded events
        if isRecordingOnlyPadSounds, let sampleURL = URL(string: sample.path) {
            let event = PadEvent(
                time: CACurrentMediaTime() - recordingStartTimeOffset,
                sampleURL: sampleURL,
                velocity: 1.0  // Default velocity
            )
            recordedEvents.append(event)
            logger("Added pad event to recording: \(padId)")
            
            // Actually trigger the sound to be played through the recording-enabled engine
            try await playSampleThroughRecordingEngine(at: sample.path, atTime: event.time)
        } else {
            try await playSample(at: sample.path)
        }
    }

    func stopAll() async {
        logger("Stopping all audio playback")

        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }

    func loadedSamples() async -> [Int: AudioEngineClient.Sample] {
        return samples
    }

    func drumPads() async -> [Int: AudioEngineClient.DrumPad] {
        return pads
    }

    func isPresetLoaded() async -> Bool {
        return currentPreset != nil
    }

    func currentPresetId() async -> String? {
        return currentPreset
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

        // Initialize the recording process
        recordingFilePath = filePath
        recordingStartTime = Date()
        recordingStartTimeOffset = CACurrentMediaTime()
        isRecordingOnlyPadSounds = true
        recordedEvents = []  // Clear any previous events

        // Setup AVAudioEngine for recording
        setupAVAudioEngineForRecording(outputPath: filePath)

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

        // Perform manual rendering to create the final recording with all the captured events
        try await performManualRendering(to: URL(fileURLWithPath: filePath))

        lastRecordedFilePath = filePath

        let returnedPath = recordingFilePath
        self.recordingFilePath = nil
        self.recordingStartTime = nil
        self.isRecordingOnlyPadSounds = false  // Reset the pad-only recording flag
        self.recordedEvents.removeAll()  // Clear the recorded events
        self.audioPlayerNodes.removeAll() // Clear player nodes cache
        self.audioFiles.removeAll() // Clear audio files cache

        logger("Pad-only recording stopped successfully, saved to: \(returnedPath ?? "unknown")")
        return returnedPath
    }
    
    // Setup for recording - just initialize the recording state
    private func setupAVAudioEngineForRecording(outputPath: String) {
        logger("Initializing recording state to: \(outputPath)")
        // We just need to initialize the recording state
        // Actual rendering will happen when stopRecording is called
    }
    
    // Finalize recording state
    private func stopAVAudioEngineRecording() {
        logger("Finalizing recording state")
        // At this point, all events have been recorded in recordedEvents
        // The actual rendering happens in performManualRendering
    }
    
    // Add a new method to play samples through the recording engine
    private func playSampleThroughRecordingEngine(at path: String, atTime time: TimeInterval) async throws {
        logger("Playing sample through recording engine at path: \(path)")
        
        if path.isEmpty {
            logger("Empty path detected - simulating audio playback for fallback sample")
            try await Task.sleep(nanoseconds: UInt64(100 * 1_000_000))
            return
        }
        
        guard URL(string: path) != nil else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }
        
        // Just play the sample normally - the event is already captured in playPad
        try await playSample(at: path)
    }
    
    // Perform manual rendering to create the final recording file
    private func performManualRendering(to outputURL: URL) async throws {
        logger("Performing manual rendering to: \(outputURL.path)")
        
        // If no events were recorded, create a minimal silent file
        guard !recordedEvents.isEmpty else {
            logger("No events recorded, creating a minimal silent file")
            try createSilentFile(at: outputURL)
            return
        }
        
        // Calculate the total duration based on the last recorded event plus the longest sample duration
        var totalDuration = recordedEvents.last?.time ?? 0.0
        
        // Find the maximum duration among all samples to ensure we account for the full length
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
        
        // Ensure minimum duration to prevent buffer creation issues
        if totalDuration < 0.1 {
            totalDuration = 0.1
        }
        
        // Create a buffer to hold the mixed audio
        let sampleRate: Double = 44100.0
        let channels: AVAudioChannelCount = 2 // Stereo
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        
        // Create audio format
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        
        // Create a buffer to mix all audio
        let mixedBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        
        // Initialize the buffer with zeros
        if let channelData = mixedBuffer.floatChannelData {
            for i in 0 ..< Int(channels) {
                memset(channelData[i], 0, Int(frameCount) * MemoryLayout<Float>.size)
            }
        }
        mixedBuffer.frameLength = frameCount
        
        // Process each recorded event
        for event in recordedEvents {
            // Load the audio file for this event
            guard let audioFileToMix = try? AVAudioFile(forReading: event.sampleURL) else {
                logger("Could not load audio file: \(event.sampleURL.path)")
                continue
            }
            
            // Create a buffer to hold this sample's audio data
            let sampleBuffer = AVAudioPCMBuffer(pcmFormat: audioFileToMix.processingFormat, frameCapacity: AVAudioFrameCount(audioFileToMix.length))!
            
            // Read the sample data
            try audioFileToMix.read(into: sampleBuffer)
            
            // Mix this sample into the main buffer at the appropriate time
            mixSampleIntoBuffer(sampleBuffer, at: event.time, into: mixedBuffer, sampleRate: sampleRate)
        }
        
        // Create audio file for writing with the calculated settings
        let audioFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat.settings)
        
        // Write the mixed buffer to the output file
        try audioFile.write(from: mixedBuffer)
        
        logger("Manual rendering completed with actual audio data")
    }
    
    // Helper function to create a silent file when no events are recorded
    private func createSilentFile(at url: URL) throws {
        let sampleRate: Double = 44100.0
        let channels: AVAudioChannelCount = 2
        let duration: Double = 1.0 // 1 second of silence
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let audioFile = try AVAudioFile(forWriting: url, settings: audioFormat.settings)
        
        let silentBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        
        // Initialize with zeros
        if let channelData = silentBuffer.floatChannelData {
            for i in 0 ..< Int(channels) {
                memset(channelData[i], 0, Int(frameCount) * MemoryLayout<Float>.size)
            }
        }
        silentBuffer.frameLength = frameCount
        
        try audioFile.write(from: silentBuffer)
    }
    
    // Helper function to mix a sample into the main buffer at a specific time
    private func mixSampleIntoBuffer(_ sampleBuffer: AVAudioPCMBuffer, at startTime: TimeInterval, into mixedBuffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let sampleData = sampleBuffer.floatChannelData,
              let mixedData = mixedBuffer.floatChannelData else {
            logger("Could not get float channel data for mixing")
            return
        }
        
        let channels = Int(mixedBuffer.format.channelCount)
        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        
        // Make sure we don't exceed the bounds of the mixed buffer
        let sampleFrames = sampleBuffer.frameLength
        let endFrame = min(startFrame + AVAudioFramePosition(sampleFrames), AVAudioFramePosition(mixedBuffer.frameLength))
        
        for channel in 0..<channels {
            let sourceChannel = sampleData[channel]
            let destChannel = mixedData[channel]
            
            // Copy sample frames to the appropriate position in the mixed buffer
            for frame in 0..<(endFrame - startFrame) {
                let sourceIndex = Int(frame)
                let destIndex = Int(startFrame + frame)
                
                // Simple addition for mixing (without clipping protection)
                destChannel[destIndex] += sourceChannel[sourceIndex]
            }
        }
    }
    
    
    func playRecordedAudio() async throws {
        guard let recordedFilePath = lastRecordedFilePath else {
            logger("No recorded audio file to play")
            throw AudioEngineClient.Error.sampleNotFound(path: "No recorded file available")
        }

        logger("Playing recorded audio from path: \(recordedFilePath)")
        try await playSample(at: recordedFilePath)
    }
}
