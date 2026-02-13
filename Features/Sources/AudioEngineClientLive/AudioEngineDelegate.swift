import AudioEngineClient
import AudioKit
import Foundation
import AVFoundation

// Extensions to convert integers to little endian bytes
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

// Event structure for recording
struct PadEvent {
    let time: TimeInterval
    let sampleURL: URL
    let velocity: Float
}

final class AudioEngineDelegate: @unchecked Sendable {
    private let logger: @Sendable (String) -> Void

    private var engine: AudioEngine
    private var players: [String: AudioPlayer] = [:]
    // Track which pad is associated with each player
    private var padIdsByPlayerId: [String: Int] = [:]

    private var samples: [Int: AudioEngineClient.Sample] = [:]
    private var pads: [Int: AudioEngineClient.DrumPad] = [:]
    private var currentPreset: String?

    // Track currently playing pads by choke group
    private var playingPadsByChokeGroup: [Int: Set<Int>] = [:]
    // Track tasks that remove pads from choke groups after playback
    private var chokeGroupRemovalTasks: [Int: Task<(), any Error>] = [:]

    // Recording properties
    private var recordingStartTime: Date?
    private var recordingFilePath: String?
    private var lastRecordedFilePath: String?
    private var isRecordingOnlyPadSounds: Bool = false
    private var recordedEvents: [PadEvent] = []
    private var recordingStartTimeOffset: TimeInterval = 0

    private var audioPlayerNodes: [URL: AVAudioPlayerNode] = [:]
    private var audioFiles: [URL: AVAudioFile] = [:]

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

        do {
            try engine.start()
            logger("Audio engine started successfully")
        } catch {
            logger("Audio engine failed to start: \(error)")
        }
    }

    // MARK: - Public Methods

    func loadPreset(presetId: String) async throws {
        logger("Loading preset: \(presetId)")

        if let presetURL = findPresetFile(named: presetId) {
            let (newSamples, newPads) = try await loadPresetFromURL(presetURL, presetId: presetId)

            self.samples = newSamples
            self.pads = newPads
            self.currentPreset = presetId

            logger("Successfully loaded preset: \(presetId) with \(newSamples.count) samples")
        } else {
            logger("Preset file not found in bundle, creating a minimal default preset with actual file paths")
            let (defaultSamples, defaultPads) = createDefaultPreset(presetId: presetId)

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

        // Handle choke group behavior - stop any currently playing pads in the same choke group
        if pad.chokeGroup != 0 { // Only apply choking if not in group 0 (which means no choking)
            await stopPadsInChokeGroup(pad.chokeGroup)
        }
        
        // Track this pad as currently playing in its choke group
        if pad.chokeGroup != 0 {
            if playingPadsByChokeGroup[pad.chokeGroup] == nil {
                playingPadsByChokeGroup[pad.chokeGroup] = Set<Int>()
            }
            playingPadsByChokeGroup[pad.chokeGroup]?.insert(padId)
        }

        if isRecordingOnlyPadSounds, let sampleURL = URL(string: sample.path) {
            let event = PadEvent(
                time: CACurrentMediaTime() - recordingStartTimeOffset,
                sampleURL: sampleURL,
                velocity: 1.0
            )
            recordedEvents.append(event)
            logger("Added pad event to recording: \(padId)")

            try await playSampleThroughRecordingEngine(at: sample.path, atTime: event.time)
        } else {
            // Track the relationship between pad and player
            padIdsByPlayerId[sample.path] = padId
            try await playSample(at: sample.path)
            
            // Schedule removal of this pad from its choke group after the sample duration
            await scheduleChokeGroupRemoval(for: padId, samplePath: sample.path, chokeGroup: pad.chokeGroup)
        }
    }

    func stopAll() async {
        logger("Stopping all audio playback")

        for player in players.values {
            player.stop()
        }
        players.removeAll()
        padIdsByPlayerId.removeAll()
        
        // Cancel all scheduled choke group removal tasks
        for task in chokeGroupRemovalTasks.values {
            task.cancel()
        }
        chokeGroupRemovalTasks.removeAll()
        
        // Clear all choke group tracking
        playingPadsByChokeGroup.removeAll()
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

        try await performManualRendering(to: URL(fileURLWithPath: filePath))

        lastRecordedFilePath = filePath

        let returnedPath = recordingFilePath
        self.recordingFilePath = nil
        self.recordingStartTime = nil
        self.isRecordingOnlyPadSounds = false
        self.recordedEvents.removeAll()
        self.audioPlayerNodes.removeAll()
        self.audioFiles.removeAll()
        self.playingPadsByChokeGroup.removeAll() // Clear choke group tracking
        self.padIdsByPlayerId.removeAll() // Clear pad-player tracking
        
        // Cancel all scheduled choke group removal tasks
        for task in chokeGroupRemovalTasks.values {
            task.cancel()
        }
        self.chokeGroupRemovalTasks.removeAll()

        logger("Pad-only recording stopped successfully, saved to: \(returnedPath ?? "unknown")")
        return returnedPath
    }

    func playRecordedAudio() async throws {
        guard let recordedFilePath = lastRecordedFilePath else {
            logger("No recorded audio file to play")
            throw AudioEngineClient.Error.sampleNotFound(path: "No recorded file available")
        }

        logger("Playing recorded audio from path: \(recordedFilePath)")
        try await playSample(at: recordedFilePath)
    }

    // MARK: - Private Helper Methods

    private func setupAVAudioEngineForRecording(outputPath: String) {
        logger("Initializing recording state to: \(outputPath)")
    }

    private func stopAVAudioEngineRecording() {
        logger("Finalizing recording state")
    }

    // Stop all pads in a specific choke group
    private func stopPadsInChokeGroup(_ chokeGroup: Int) async {
        guard let padsInGroup = playingPadsByChokeGroup[chokeGroup] else { return }
        
        for padId in padsInGroup {
            // Stop the sample associated with this pad
            if let pad = pads[padId], let sample = samples[pad.sampleId] {
                let playerId = sample.path
                if let player = players[playerId] {
                    player.stop()
                    
                    // Remove the pad-player tracking
                    padIdsByPlayerId.removeValue(forKey: playerId)
                }
                
                // Cancel any scheduled removal task for this pad
                if let removalTask = chokeGroupRemovalTasks[padId] {
                    removalTask.cancel()
                    chokeGroupRemovalTasks.removeValue(forKey: padId)
                }
            }
        }
        
        // Clear the tracking for this choke group
        playingPadsByChokeGroup[chokeGroup]?.removeAll()
    }
    
    // Schedule removal of a pad from its choke group after playback
    private func scheduleChokeGroupRemoval(for padId: Int, samplePath: String, chokeGroup: Int) async {
        // Cancel any existing task for this pad
        if let existingTask = chokeGroupRemovalTasks[padId] {
            existingTask.cancel()
        }
        
        // Get the sample duration to determine when to remove the pad from the choke group
        let duration: Double
        do {
            duration = try await sampleDuration(at: samplePath)
        } catch {
            // Default to 1 second if we can't get the duration
            duration = 1.0
        }
        
        // Create a new task to remove the pad from its choke group after the duration
        let task = Task {
            // Wait for the duration of the sample
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            // Only proceed if the task hasn't been cancelled
            try Task.checkCancellation()
            
            // Remove the pad from its choke group
            await MainActor.run {
                self.playingPadsByChokeGroup[chokeGroup]?.remove(padId)
                self.padIdsByPlayerId.removeValue(forKey: samplePath)
                self.chokeGroupRemovalTasks.removeValue(forKey: padId)
            }
        }
        
        // Store the task for potential cancellation later
        chokeGroupRemovalTasks[padId] = task 
    }

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

        try await playSample(at: path)
    }

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

            let sampleBuffer = AVAudioPCMBuffer(pcmFormat: audioFileToMix.processingFormat, frameCapacity: AVAudioFrameCount(audioFileToMix.length))!

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

    private func mixSampleIntoBuffer(_ sampleBuffer: AVAudioPCMBuffer, at startTime: TimeInterval, into mixedBuffer: AVAudioPCMBuffer, sampleRate: Double) {
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
    
    func findPresetFile(named presetId: String) -> URL? {
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

    func findSampleFile(named filename: String) -> URL? {
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

    func copyResourceToDocumentsIfNeeded(resourceName: String, ofType: String?) async -> URL? {
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

    func loadPresetFromURL(_ presetURL: URL, presetId: String) async throws -> (
        samples: [Int: AudioEngineClient.Sample],
        pads: [Int: AudioEngineClient.DrumPad]
    ) {
        do {
            let jsonData = try Data(contentsOf: presetURL)

            let decoder = JSONDecoder()

            struct RawPresetData: Codable {
                let id: String
                let name: String
                let files: [String: RawPresetFile]
            }

            struct RawPresetFile: Codable {
                let filename: String
                let color: String
                let choke: Int?
            }

            let rawPresetData = try decoder.decode(RawPresetData.self, from: jsonData)

            var presetFiles: [String: AudioEngineClient.PresetFile] = [:]
            for (key, rawFile) in rawPresetData.files {
                presetFiles[key] = AudioEngineClient.PresetFile(
                    id: key,
                    filename: rawFile.filename,
                    color: rawFile.color,
                    choke: rawFile.choke
                )
            }

            let presetData = AudioEngineClient.PresetData(
                id: rawPresetData.id,
                name: rawPresetData.name,
                files: presetFiles
            )

            var newSamples: [Int: AudioEngineClient.Sample] = [:]
            var newPads: [Int: AudioEngineClient.DrumPad] = [:]

            for (key, file) in presetData.files {
                if let intKey = Int(key) {
                    let sampleURL = findSampleFile(named: file.filename)

                    var finalSampleURL: URL?
                    if let sampleURL = sampleURL {
                        finalSampleURL = sampleURL
                    } else {
                        finalSampleURL = await copyResourceToDocumentsIfNeeded(resourceName: file.filename, ofType: nil)
                    }

                    guard let finalSampleURL = finalSampleURL else {
                        logger("Sample file not found: \(file.filename), skipping...")
                        continue
                    }

                    let sample = AudioEngineClient.Sample(
                        id: intKey,
                        filename: file.filename,
                        name: file.filename.replacingOccurrences(of: ".wav", with: ""),
                        path: finalSampleURL.absoluteString,
                        color: file.color,
                        chokeGroup: file.choke ?? 0
                    )

                    newSamples[intKey] = sample
                    newPads[intKey] = AudioEngineClient.DrumPad(
                        id: intKey,
                        sampleId: sample.id,
                        color: sample.color,
                        chokeGroup: sample.chokeGroup
                    )
                }
            }

            logger("Successfully processed preset: \(presetId) with \(newSamples.count) samples")

            return (samples: newSamples, pads: newPads)
        } catch let decodingError as DecodingError {
            logger("Failed to decode preset \(presetId): \(decodingError)")
            throw AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: decodingError)
        } catch {
            logger("Failed to process preset \(presetId): \(error)")
            throw AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: error)
        }
    }

    func createDefaultPreset(presetId: String) -> (
        samples: [Int: AudioEngineClient.Sample],
        pads: [Int: AudioEngineClient.DrumPad]
    ) {
        logger("Creating default preset with actual file paths for: \(presetId)")

        var samples: [Int: AudioEngineClient.Sample] = [:]
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

            let sample = AudioEngineClient.Sample(
                id: i,
                filename: filename,
                name: "Sample \(i)",
                path: samplePath,
                color: ["red", "blue", "green", "yellow", "purple"].randomElement()!,
                chokeGroup: i % 4
            )

            samples[i] = sample
            pads[i] = AudioEngineClient.DrumPad(
                id: i,
                sampleId: i,
                color: sample.color,
                chokeGroup: sample.chokeGroup
            )
        }

        logger("Created default preset with \(samples.count) samples, \(samples.values.filter { !$0.path.isEmpty }.count) with actual file paths")

        return (samples: samples, pads: pads)
    }
}
