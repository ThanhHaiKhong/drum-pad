import AudioEngineClient
import AudioKit
import Foundation

final class AudioEngineDelegate: @unchecked Sendable {
    private let logger: @Sendable (String) -> Void

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("🎵 [AUDIO_ENGINE_DELEGATE]: \(message)")
            #endif
        }
    ) {
        self.logger = logger
    }

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
